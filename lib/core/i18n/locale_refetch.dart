import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_locale_controller.dart';

/// Re-fetches backend-localised data when the user switches language.
///
/// Dynamic content (categories, banners, products, cart lines) arrives
/// already translated by the backend (`Accept-Language` header), so a
/// language switch instantly makes every loaded list stale in the previous
/// language. Long-lived blocs that hold such data mix this in and reload
/// **silently** — by the time the user backs out of Settings, the screens
/// behind it are already re-translated, with no pull-to-refresh and no
/// spinner flash.
///
/// Wiring: pass the root [AppLocaleController] into [watchLocale] from the
/// constructor. Null is a no-op, so existing tests construct blocs
/// unchanged. [onLocaleChanged] fires only when the language code actually
/// changes and must trigger a refresh that keeps the current (old-language)
/// state on screen until the translated payload lands.
mixin LocaleRefetch<S> on BlocBase<S> {
  AppLocaleController? _localeController;
  String? _localeCode;

  void watchLocale(AppLocaleController? controller) {
    if (controller == null) return;
    assert(_localeController == null, 'watchLocale() called twice');
    _localeController = controller;
    _localeCode = controller.value.languageCode;
    controller.addListener(_onLocaleTick);
  }

  void _onLocaleTick() {
    final next = _localeController?.value.languageCode;
    if (next == null || next == _localeCode) return;
    _localeCode = next;
    onLocaleChanged();
  }

  /// Silently re-fetch every backend-localised payload this bloc owns.
  void onLocaleChanged();

  @override
  Future<void> close() {
    _localeController?.removeListener(_onLocaleTick);
    return super.close();
  }
}
