import 'package:share_plus/share_plus.dart';

import '../../core/i18n/i18n.dart';
import '../../core/logging/app_logger.dart';

/// Public, shareable web URL for a shop. Mirrors [productShareUrl] and the
/// `woody.uz/...` deep-link shape — keep this `woody.uz/shop/:id` path in sync
/// with the web landing (`woody_frontend`) and the native deep-link configs
/// (`apple-app-site-association` / `assetlinks.json`).
String shopShareUrl(String shopId) => 'https://woody.uz/shop/$shopId';

/// Opens the OS share sheet for a shop. The payload is the public web URL —
/// a tap from a device with Woody installed deep-links into the shop; without
/// it, the web landing handles the link.
///
/// Never throws — a share-sheet failure is a no-op, not a crash.
Future<void> shareShop({required String id, required String name}) async {
  final url = shopShareUrl(id);
  final text = tr('shop.share_text', namedArgs: {'name': name, 'url': url});
  try {
    await SharePlus.instance.share(ShareParams(text: text, subject: name));
  } catch (e, st) {
    appLog.handle(e, st, 'Shop share failed');
  }
}
