import 'dart:io';

import 'package:webview_flutter/webview_flutter.dart';

import 'glb_cache_manager.dart';
import 'ios_quick_look.dart';

/// How an AR launch attempt resolved.
enum ArActivationOutcome {
  /// Native Quick Look (iOS) or Scene Viewer hand-off (Android) started.
  launched,

  /// model-viewer JS was invoked; unsupported may still arrive on the channel.
  delegated,

  /// iOS without a usdz, or launch prerequisites missing.
  unsupported,
}

/// Platform-correct AR launch for the buyer/seller `<model-viewer>` screens.
///
/// Android keeps the model-viewer `canActivateAR` → `activateAR()` path (Scene
/// Viewer). iOS bypasses the WKWebView false-negative and opens Quick Look
/// natively when a `.usdz` is available.
abstract class ArActivation {
  ArActivation._();

  static Future<ArActivationOutcome> activate({
    required WebViewController? web,
    required String arChannel,
    String? usdzUrl,
    GlbCacheService? cache,
  }) async {
    if (Platform.isIOS) {
      final usdz = usdzUrl?.trim();
      if (usdz == null || usdz.isEmpty) {
        return ArActivationOutcome.unsupported;
      }
      final launched = await IosQuickLookLauncher.launch(usdz, cache: cache);
      return launched
          ? ArActivationOutcome.launched
          : ArActivationOutcome.unsupported;
    }

    if (web == null) return ArActivationOutcome.unsupported;

    await web.runJavaScript(
      "(function(){var mv=document.querySelector('model-viewer');"
      'if(!mv){return;}'
      'if(mv.canActivateAR){mv.activateAR();}'
      "else{$arChannel.postMessage('unsupported');}})();",
    );
    return ArActivationOutcome.delegated;
  }
}
