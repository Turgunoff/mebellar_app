import 'package:share_plus/share_plus.dart';

import '../../core/i18n/i18n.dart';
import '../../core/logging/talker.dart';
import '../models/product_model.dart';

/// Public, shareable web URL for a product. Mirrors the route the web landing
/// (`woody_frontend`) serves and the native deep-link path both platforms
/// intercept (`apple-app-site-association` / `assetlinks.json`). Keep this
/// `woody.uz/product/:id` shape in sync with those configs — see the
/// workspace `CLAUDE.md`.
String productShareUrl(String productId) => 'https://woody.uz/product/$productId';

/// Opens the OS share sheet for [product].
///
/// The shared payload is the public web URL. A tap from a device with Woody
/// installed deep-links straight into this product (Universal Link / App
/// Link); a tap from a device without it lands on the web landing, whose
/// "download" CTA seeds the clipboard so the freshly-installed app can resume
/// right here (the deferred deep link, see [DeferredDeepLinkService]).
///
/// Never throws — a share-sheet failure is a no-op, not a crash.
Future<void> shareProduct(ProductModel product) async {
  final url = productShareUrl(product.id);
  final text = '${tr('product.share_text')}\n\n${product.name}\n$url';
  try {
    await SharePlus.instance.share(
      ShareParams(text: text, subject: product.name),
    );
  } catch (e, st) {
    talker.handle(e, st, 'Product share failed');
  }
}
