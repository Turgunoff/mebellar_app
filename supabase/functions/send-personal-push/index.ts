// send-personal-push
//
// Fans an FCM push out to every device registered in `device_tokens` for a
// given Supabase user id. Authenticates to FCM HTTP v1 via OAuth2 using the
// Firebase service-account JSON stored in the `FCM_SERVICE_ACCOUNT_JSON`
// secret.
//
// Caller authorization: requires the Supabase service_role key in the
// Authorization header (Edge Functions enforce JWT verification by default).
// When called from the client SDK, the user's own JWT will fail — this is
// intentional for a v1 to prevent users from spamming each other. Server-
// side invocations (DB triggers, cron jobs, admin tooling) should use the
// service_role key.
//
// Request body:
//   {
//     "user_id": "uuid",       // who to ping
//     "title":   "string",      // visible in tray
//     "body":    "string",      // visible in tray
//     "data":    { ... }        // optional, surfaced in onMessage payload
//   }
//
// Response:
//   { sent: <int>, failed: <int>, removed: <int>, errors: [...] }
//
// Stale tokens (HTTP 404 / UNREGISTERED) are deleted from `device_tokens`
// so we don't keep retrying them forever.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface PushRequest {
  user_id: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
  token_uri: string;
}

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";

// Cached OAuth2 access token. Tokens last 1 hour; we refresh 5 minutes early
// so a token that's about to expire isn't returned by the cache.
let cachedToken: { token: string; expiresAt: number } | null = null;

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  let raw: unknown;
  try {
    raw = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  // Accept two payload shapes:
  //   1. Direct invocation (curl / admin tools): { user_id, title, body, data? }
  //   2. Database Webhook on `notifications` table: unpack `record`
  // Only INSERTs trigger a push — UPDATE/DELETE webhooks are dropped so
  // marking a notification read doesn't re-send it.
  const payload = unpackPayload(raw);
  if (payload === null) {
    return jsonResponse(
      { error: "Payload must include user_id and title (direct or webhook record)" },
      400,
    );
  }
  const { user_id, title, body, data } = payload;

  const serviceAccountJson = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
  if (!serviceAccountJson) {
    return jsonResponse(
      { error: "FCM_SERVICE_ACCOUNT_JSON secret is not configured" },
      500,
    );
  }

  let serviceAccount: ServiceAccount;
  try {
    serviceAccount = JSON.parse(serviceAccountJson);
  } catch (e) {
    return jsonResponse(
      { error: `Service account JSON is invalid: ${(e as Error).message}` },
      500,
    );
  }

  // Use service-role to read device_tokens regardless of RLS — this function
  // is authenticated at the gateway by Supabase, so we can act with elevated
  // privileges inside.
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseServiceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, supabaseServiceRole);

  const { data: tokens, error: tokensError } = await supabase
    .from("device_tokens")
    .select("token")
    .eq("user_id", user_id);

  if (tokensError) {
    return jsonResponse(
      { error: `Failed to load device_tokens: ${tokensError.message}` },
      500,
    );
  }

  if (!tokens || tokens.length === 0) {
    return jsonResponse({ sent: 0, failed: 0, removed: 0, errors: [] });
  }

  let accessToken: string;
  try {
    accessToken = await getAccessToken(serviceAccount);
  } catch (e) {
    return jsonResponse(
      { error: `OAuth2 failed: ${(e as Error).message}` },
      500,
    );
  }

  const fcmEndpoint =
    `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;

  let sent = 0;
  let failed = 0;
  let removed = 0;
  const errors: string[] = [];
  const staleTokens: string[] = [];

  // Fan out one HTTP request per token. The HTTP v1 API does not support
  // multicast in a single request — for very large user fanouts we'd batch
  // via the legacy /batch endpoint, but a typical user has 1-3 devices so
  // sequential sends are fine.
  for (const { token } of tokens) {
    const message = {
      message: {
        token,
        notification: { title, body: body ?? "" },
        ...(data ? { data: stringifyValues(data) } : {}),
      },
    };
    const res = await fetch(fcmEndpoint, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(message),
    });

    if (res.ok) {
      sent += 1;
      continue;
    }

    failed += 1;
    const errBody = await res.text();
    const isStale = res.status === 404 ||
      errBody.includes("UNREGISTERED") ||
      errBody.includes("INVALID_ARGUMENT");
    errors.push(`HTTP ${res.status}: ${errBody.slice(0, 200)}`);
    if (isStale) staleTokens.push(token);
  }

  if (staleTokens.length > 0) {
    const { error: deleteError } = await supabase
      .from("device_tokens")
      .delete()
      .in("token", staleTokens);
    if (!deleteError) removed = staleTokens.length;
  }

  return jsonResponse({ sent, failed, removed, errors });
});

function jsonResponse(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function unpackPayload(raw: unknown): PushRequest | null {
  if (!raw || typeof raw !== "object") return null;
  const obj = raw as Record<string, unknown>;

  // Webhook shape: { type, table, record: {...} }. Only INSERT triggers a
  // push; UPDATE (e.g. marking is_read) and DELETE are silently dropped.
  if (typeof obj.type === "string" && obj.record && typeof obj.record === "object") {
    if (obj.type !== "INSERT") return null;
    const record = obj.record as Record<string, unknown>;
    const userId = record.user_id;
    const title = record.title;
    if (typeof userId !== "string" || typeof title !== "string") return null;
    // Pass the row's `data` JSONB through to FCM as the message data
    // payload — the Flutter side reads `data.route` on tap to deep-link
    // into a specific screen.
    const dataField = record.data;
    return {
      user_id: userId,
      title,
      body: typeof record.body === "string" ? record.body : "",
      data: (dataField && typeof dataField === "object")
        ? (dataField as Record<string, string>)
        : undefined,
    };
  }

  // Direct shape: { user_id, title, body, data? }
  if (typeof obj.user_id === "string" && typeof obj.title === "string") {
    return {
      user_id: obj.user_id,
      title: obj.title,
      body: typeof obj.body === "string" ? obj.body : "",
      data: obj.data as Record<string, string> | undefined,
    };
  }

  return null;
}

function stringifyValues(obj: Record<string, unknown>): Record<string, string> {
  return Object.fromEntries(
    Object.entries(obj).map(([k, v]) => [k, String(v)]),
  );
}

/**
 * Returns a cached OAuth2 access token, minting a new one if expired.
 * Mints by signing a JWT with the service-account private key (RS256) and
 * exchanging it at the Google token endpoint. The Web Crypto API is used
 * directly so we don't need to pull in a dependency.
 */
async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt > now + 60) {
    return cachedToken.token;
  }

  const header = { alg: "RS256", typ: "JWT" };
  const claims = {
    iss: sa.client_email,
    scope: FCM_SCOPE,
    aud: sa.token_uri,
    iat: now,
    exp: now + 3600,
  };

  const encoder = new TextEncoder();
  const headerB64 = base64UrlEncode(encoder.encode(JSON.stringify(header)));
  const claimsB64 = base64UrlEncode(encoder.encode(JSON.stringify(claims)));
  const unsigned = `${headerB64}.${claimsB64}`;

  const key = await importPrivateKey(sa.private_key);
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    encoder.encode(unsigned),
  );
  const jwt = `${unsigned}.${base64UrlEncode(new Uint8Array(signature))}`;

  const res = await fetch(sa.token_uri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!res.ok) {
    throw new Error(`Token exchange failed: ${res.status} ${await res.text()}`);
  }

  const json = await res.json() as { access_token: string; expires_in: number };
  cachedToken = {
    token: json.access_token,
    expiresAt: now + json.expires_in,
  };
  return json.access_token;
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const cleaned = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const der = Uint8Array.from(atob(cleaned), (c) => c.charCodeAt(0));
  return await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary)
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}
