import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logging/talker.dart';

/// Magic-string prefix the web download CTA writes to the clipboard before
/// it bounces the visitor to the store.
///
/// MUST stay byte-for-byte identical to the web side
/// (`MAGIC_PREFIX` in `woody_frontend/components/blocks/download-app-cta.tsx`).
/// This is a cross-repo invariant — see the workspace `CLAUDE.md`. Format:
/// `woody_product_<id>` (e.g. `woody_product_123`).
const String kDeferredProductPrefix = 'woody_product_';

/// Holds a deep link resolved at cold boot (here: from the clipboard) so the
/// customer [GoRouter] can consume it *after* the first-launch tutorial gate
/// clears, instead of having the navigation swallowed by the gate's redirect.
///
/// It's a tiny process-global on purpose: the value is produced once in
/// `main()` (before `runApp`) and read once by the router, so there's nothing
/// to inject or dispose.
class DeferredDeepLink {
  DeferredDeepLink._();

  /// The pending in-app location (e.g. `/product-detail/123`), or null. Set
  /// once in `main()` (before `runApp`) and read by `buildCustomerRouter()`
  /// as its `initialLocation`. Reading does NOT clear it — use [take] to
  /// consume.
  static String? pendingLocation;

  /// Reads and clears the pending location (single-shot). Called once the
  /// tutorial gate is cleared so the same link can't fire twice.
  static String? take() {
    final value = pendingLocation;
    pendingLocation = null;
    return value;
  }
}

/// The "clipboard" half of our zero-cost deferred-deep-link scheme — a free
/// stand-in for the deprecated Firebase Dynamic Links and the paid Branch.io.
///
/// A user without the app taps a shared `woody.uz/product/:id` link, lands on
/// the web landing, hits "download", and the web copies `woody_product_<id>`
/// to the clipboard before sending them to the store. On the very first launch
/// after install, this service reads that string back and resolves it to the
/// in-app product route.
class DeferredDeepLinkService {
  DeferredDeepLinkService();

  /// Bumped (`_v1` → `_v2`) only if we ever need every install to re-check.
  static const String _firstLaunchKey = 'deferred_deeplink_checked_v1';

  /// Runs the clipboard trick **exactly once per install** and returns the
  /// resolved in-app location (`/product-detail/<id>`), or null if there's
  /// nothing to resume. Never throws — every failure path degrades to null so
  /// boot is never blocked or crashed by it.
  Future<String?> resolveInitialDeepLink() async {
    final prefs = await SharedPreferences.getInstance();

    // First-session gate. The clipboard trick is an install-attribution
    // mechanism: after the very first launch we must never peek at the
    // clipboard again — both for privacy (no silent paste banner on every
    // cold start) and so we don't hijack a string the user copied for some
    // unrelated reason later on.
    if (prefs.getBool(_firstLaunchKey) ?? false) return null;
    // Burn the flag up-front: even if anything below throws, the next launch
    // must not retry. (Belt-and-suspenders with the clipboard wipe below.)
    await prefs.setBool(_firstLaunchKey, true);

    String? clipboardText;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain)
          .timeout(const Duration(seconds: 2), onTimeout: () => null);
      clipboardText = data?.text?.trim();
    } catch (e, st) {
      // Clipboard access can be denied / unavailable (restricted device, OS
      // privacy setting). Skip silently — this is a best-effort enhancement.
      talker.handle(e, st, 'Deferred deep link: clipboard read failed');
      return null;
    }

    if (clipboardText == null ||
        !clipboardText.startsWith(kDeferredProductPrefix)) {
      return null;
    }

    final rawId = clipboardText.substring(kDeferredProductPrefix.length).trim();
    final id = _sanitizeProductId(rawId);
    if (id == null) return null;

    // CRITICAL — wipe the clipboard the instant we've consumed our token.
    // Without this, a later cold start (e.g. the user clears app data, which
    // resets the first-launch flag) would read the same magic string and
    // re-route in a loop. Clearing also stops our token leaking into the
    // user's next paste.
    try {
      await Clipboard.setData(const ClipboardData(text: ''));
    } catch (_) {
      // Best-effort — the first-launch flag already guards against loops.
    }

    talker.info('Deferred deep link resolved → product $id');
    return '/product-detail/$id';
  }

  /// Accept only a short, URL-safe token. Our product ids are numeric, but we
  /// stay permissive enough for slug ids while rejecting an oversized or
  /// junk clipboard payload that happened to start with our prefix.
  String? _sanitizeProductId(String raw) {
    if (raw.isEmpty || raw.length > 64) return null;
    return RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(raw) ? raw : null;
  }
}
