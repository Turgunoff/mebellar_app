import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../../../core/i18n/i18n.dart';
import '../../../shared/widgets/ar/product_3d_preview_view.dart';

/// Bundled demo models used by the home-screen "instant AR" showcase. The `.glb`
/// drives the in-page WebGL view + Android Scene Viewer; the `.usdz` drives iOS
/// AR Quick Look.
const String _demoGlbAsset = 'assets/models/3d_model_demo.glb';
const String _demoUsdzAsset = 'assets/models/3d_model_demo.usdz';

/// Opens the unified [Product3DPreviewScreen] on the bundled demo model so a
/// first-time user can feel the AR "wow" without first finding a product.
///
/// model_viewer_plus reads the `.glb` straight from the asset bundle (its proxy
/// serves an `assets/...` `src` via `rootBundle`), so the `.glb` needs no copy.
/// The `.usdz`, however, is handed verbatim to iOS AR Quick Look, which can't
/// resolve a bundle-relative path — so on iOS we first materialise it into the
/// temp directory and pass a real `file://` URL.
Future<void> openArDemo(BuildContext context) async {
  String? usdzSource;
  if (Platform.isIOS) {
    usdzSource = await _copyAssetToTemp(_demoUsdzAsset, '3d_model_demo.usdz');
  }
  if (!context.mounted) return;

  final part = Product3DPart(
    id: 'ar_demo',
    name: tr('home.ar_demo_title'),
    glbUrl: _demoGlbAsset,
    usdzUrl: usdzSource,
  );

  await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      settings: const RouteSettings(name: '/ar-demo'),
      fullscreenDialog: true,
      builder: (_) => Product3DPreviewScreen(
        parts: [part],
        productName: tr('home.ar_demo_title'),
        isLocalAsset: true,
      ),
    ),
  );
}

/// Copies a bundled asset to the OS temp dir once and returns a `file://` URL.
/// Best-effort: returns null on any failure so the caller degrades to the
/// in-page 3D view rather than crashing.
Future<String?> _copyAssetToTemp(String asset, String filename) async {
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    if (!await file.exists() || await file.length() == 0) {
      final data = await rootBundle.load(asset);
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }
    return Uri.file(file.path).toString();
  } catch (_) {
    return null;
  }
}
