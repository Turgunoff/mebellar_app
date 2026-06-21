import 'package:flutter/widgets.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

/// Registers a no-op [WebViewPlatform] for the flutter_test harness.
///
/// `model_viewer_plus` (buyer-side AR viewer) wraps a `webview_flutter`
/// platform view. Its [State.initState] builds a real `WebViewController`, and
/// `PlatformWebViewController`/`PlatformWebViewWidget` assert at construction
/// that `WebViewPlatform.instance` is set — there is no platform plugin in a
/// unit test, so the build throws. This fake satisfies the assertion and lets
/// `ModelViewer` mount so a widget test can read its config (scale, arScale).
/// It never renders an actual web view.
void installFakeWebViewPlatform() {
  WebViewPlatform.instance ??= _FakeWebViewPlatform();
}

class _FakeWebViewPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => _FakeWebViewController(params);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _FakeNavigationDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _FakeWebViewWidget(params);
}

class _FakeWebViewController extends PlatformWebViewController {
  _FakeWebViewController(super.params) : super.implementation();

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}

  // The buyer AR viewer registers JS channels (screenshot capture + AR-state
  // feedback); model_viewer_plus wires them through here at controller init.
  @override
  Future<void> addJavaScriptChannel(
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {}

  @override
  Future<void> loadRequest(LoadRequestParams params) async {}

  // The onboarding arc slider drives the live model's camera-orbit by running
  // JS on the controller; no-op it so a drag in a widget test doesn't throw.
  @override
  Future<void> runJavaScript(String javaScript) async {}
}

class _FakeNavigationDelegate extends PlatformNavigationDelegate {
  _FakeNavigationDelegate(super.params) : super.implementation();

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async {}
}

class _FakeWebViewWidget extends PlatformWebViewWidget {
  _FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
