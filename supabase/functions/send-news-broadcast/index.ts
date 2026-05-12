// send-news-broadcast
//
// Sends an FCM push to the `news` topic — every device that subscribed
// receives the notification, regardless of whether the user is signed in.
// Auth bypass is acceptable here because nothing user-specific leaves the
// function (no token lookup, no per-user routing).
//
// Invoked by:
//   * Database Webhook on `public.news` INSERT
//   * Direct admin curl (with service_role key) for ad-hoc broadcasts
//
// Request body shapes:
//   1. Direct: { title, body, data? }
//   2. Webhook: { type, table, schema, record: { title, body, data?, ... } }
//
// Topic name is hard-coded (`news`) and matches the constant the Flutter
// PushService subscribes to on first launch.

const FCM_TOPIC = "news";
const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";

interface BroadcastRequest {
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

let cachedToken: { token: string; expiresAt: number } | null = null;
let mintInFlight: Promise<string> | null = null;

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

  const payload = unpackPayload(raw);
  if (payload === null) {
    return jsonResponse(
      { error: "Payload must include title (direct or webhook record)" },
      400,
    );
  }

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

  const message = {
    message: {
      topic: FCM_TOPIC,
      notification: { title: payload.title, body: payload.body ?? "" },
      android: { notification: { tag: crypto.randomUUID() } },
      ...(payload.data ? { data: stringifyValues(payload.data) } : {}),
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

  if (!res.ok) {
    return jsonResponse(
      {
        error: `FCM send failed: ${res.status}`,
        detail: (await res.text()).slice(0, 300),
      },
      502,
    );
  }

  return jsonResponse({ topic: FCM_TOPIC, ok: true });
});

function jsonResponse(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function unpackPayload(raw: unknown): BroadcastRequest | null {
  if (!raw || typeof raw !== "object") return null;
  const obj = raw as Record<string, unknown>;

  // Webhook shape: only INSERT triggers a broadcast — UPDATE/DELETE pings
  // would re-broadcast the same news every time admin tweaks copy.
  if (typeof obj.type === "string" && obj.record && typeof obj.record === "object") {
    if (obj.type !== "INSERT") return null;
    const record = obj.record as Record<string, unknown>;
    const title = record.title;
    if (typeof title !== "string") return null;
    // Skip inactive items — admin sometimes drafts news with is_active=false.
    if (record.is_active === false) return null;
    const dataField = record.data;
    return {
      title,
      body: typeof record.body === "string" ? record.body : "",
      data: (dataField && typeof dataField === "object")
        ? (dataField as Record<string, string>)
        : undefined,
    };
  }

  if (typeof obj.title === "string") {
    return {
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

async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt > now + 60) {
    return cachedToken.token;
  }
  if (mintInFlight) return mintInFlight;
  mintInFlight = _mintAccessToken(sa).finally(() => {
    mintInFlight = null;
  });
  return mintInFlight;
}

async function _mintAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
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
