import 'package:flutter/material.dart';

import '../../../config/remote_config.dart';
import '../../../core/i18n/i18n.dart';
import '../../../shared/widgets/ar/product_3d_preview_view.dart';

/// Opens the unified [Product3DPreviewScreen] on the R2-hosted demo model so
/// a first-time user can feel the AR "wow" without first finding a product.
///
/// Sourced entirely from [RemoteConfig] (`demoGlbUrl`/`demoUsdzUrl`, backend
/// `app_settings.demo_models`) — tech-debt roadmap T-04. Streamed + cached
/// through the same [GlbCacheService](../../../shared/ar/glb_cache_manager.dart)
/// path every real product uses (progress is the existing load overlay); iOS
/// AR Quick Look downloads + caches the `.usdz` the same way via
/// `IosQuickLookLauncher`. No bundled fallback — the ~33 MB demo files no
/// longer ship in the app bundle, so a blank/unfetched URL is a load failure
/// (the existing retry overlay), not a silent asset swap.
Future<void> openArDemo(BuildContext context) async {
  final glbUrl = RemoteConfig.instance.demoGlbUrl.trim();
  final usdzUrl = RemoteConfig.instance.demoUsdzUrl.trim();
  if (!context.mounted) return;

  final part = Product3DPart(
    id: 'ar_demo',
    name: tr('home.ar_demo_title'),
    glbUrl: glbUrl,
    usdzUrl: usdzUrl.isNotEmpty ? usdzUrl : null,
  );

  await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      settings: const RouteSettings(name: '/ar-demo'),
      fullscreenDialog: true,
      builder: (_) => Product3DPreviewScreen(
        parts: [part],
        productName: tr('home.ar_demo_title'),
      ),
    ),
  );
}
