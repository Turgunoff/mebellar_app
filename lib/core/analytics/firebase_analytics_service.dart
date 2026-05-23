import 'package:firebase_analytics/firebase_analytics.dart';

import '../logging/talker.dart';
import 'analytics_service.dart';

/// Firebase implementation of [AnalyticsService]. Maps the type-safe
/// methods onto Firebase's predefined event names where they exist —
/// view_item, add_to_cart, purchase etc. — so the dashboard's built-in
/// e-commerce reports and Google Ads conversions light up without any
/// extra configuration. Custom names are used only where there is no
/// matching predefined event (chat, seller_*, language_changed, …).
class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService({FirebaseAnalytics? analytics})
      : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  /// Common defaults applied to every parameter map. Pulled out so adding
  /// e.g. an A/B-test cohort tag in the future is a one-line change.
  Map<String, Object> _defaults() => const <String, Object>{};

  /// Centralised swallow-and-log so an analytics failure never bubbles up
  /// into the UI. Talker → Crashlytics already covers visibility.
  Future<void> _safeLog(
    String name, [
    Map<String, Object>? params,
  ]) async {
    try {
      await _analytics.logEvent(
        name: name,
        parameters: {..._defaults(), ...?params},
      );
    } catch (e, st) {
      talker.handle(e, st, 'analytics: $name failed');
    }
  }

  // ── lifecycle ──────────────────────────────────────────────────────────

  @override
  Future<void> setUserId(String? userId) async {
    try {
      await _analytics.setUserId(id: userId);
    } catch (e, st) {
      talker.handle(e, st, 'analytics: setUserId failed');
    }
  }

  @override
  Future<void> setAnalyticsEnabled(bool enabled) async {
    try {
      await _analytics.setAnalyticsCollectionEnabled(enabled);
    } catch (e, st) {
      talker.handle(e, st, 'analytics: setAnalyticsEnabled failed');
    }
  }

  @override
  Future<void> setCurrentScreen(String screenName) async {
    try {
      // `logScreenView` writes the screen breadcrumb that Crashlytics will
      // attach to any subsequent crash — invaluable for repros.
      await _analytics.logScreenView(screenName: screenName);
    } catch (e, st) {
      talker.handle(e, st, 'analytics: setCurrentScreen failed');
    }
  }

  // ── auth ──────────────────────────────────────────────────────────────

  @override
  Future<void> signedUp({required String method}) async {
    try {
      await _analytics.logSignUp(signUpMethod: method);
    } catch (e, st) {
      talker.handle(e, st, 'analytics: signedUp failed');
    }
  }

  @override
  Future<void> loggedIn({required String method}) async {
    try {
      await _analytics.logLogin(loginMethod: method);
    } catch (e, st) {
      talker.handle(e, st, 'analytics: loggedIn failed');
    }
  }

  @override
  Future<void> loggedOut() => _safeLog('logout');

  // ── catalog ───────────────────────────────────────────────────────────

  @override
  Future<void> categoryViewed({
    required String categoryId,
    String? subcategoryId,
  }) {
    return _safeLog('view_item_list', {
      'item_category': categoryId,
      // ignore: use_null_aware_elements
      if (subcategoryId != null) 'item_category2': subcategoryId,
    });
  }

  @override
  Future<void> productViewed({
    required String productId,
    String? categoryId,
    required double price,
    String currency = 'UZS',
  }) async {
    try {
      await _analytics.logViewItem(
        currency: currency,
        value: price,
        items: [
          AnalyticsEventItem(
            itemId: productId,
            itemCategory: categoryId,
            price: price,
            currency: currency,
          ),
        ],
      );
    } catch (e, st) {
      talker.handle(e, st, 'analytics: productViewed failed');
    }
  }

  @override
  Future<void> searchPerformed({
    required String query,
    required int resultsCount,
    int appliedFiltersCount = 0,
  }) async {
    try {
      await _analytics.logSearch(searchTerm: query, parameters: {
        'results_count': resultsCount,
        'applied_filters_count': appliedFiltersCount,
      });
    } catch (e, st) {
      talker.handle(e, st, 'analytics: searchPerformed failed');
    }
  }

  @override
  Future<void> filterApplied({
    required int activeFacetCount,
    String? sort,
  }) {
    return _safeLog('filter_applied', {
      'active_facets': activeFacetCount,
      // ignore: use_null_aware_elements
      if (sort != null) 'sort': sort,
    });
  }

  // ── cart / favorites ──────────────────────────────────────────────────

  @override
  Future<void> addedToCart({
    required String productId,
    required double price,
    int quantity = 1,
    String currency = 'UZS',
  }) async {
    try {
      await _analytics.logAddToCart(
        currency: currency,
        value: price * quantity,
        items: [
          AnalyticsEventItem(
            itemId: productId,
            price: price,
            quantity: quantity,
            currency: currency,
          ),
        ],
      );
    } catch (e, st) {
      talker.handle(e, st, 'analytics: addedToCart failed');
    }
  }

  @override
  Future<void> removedFromCart({required String productId}) async {
    try {
      await _analytics.logRemoveFromCart(items: [
        AnalyticsEventItem(itemId: productId),
      ]);
    } catch (e, st) {
      talker.handle(e, st, 'analytics: removedFromCart failed');
    }
  }

  @override
  Future<void> cartViewed({
    required double value,
    String currency = 'UZS',
  }) async {
    try {
      await _analytics.logViewCart(currency: currency, value: value);
    } catch (e, st) {
      talker.handle(e, st, 'analytics: cartViewed failed');
    }
  }

  @override
  Future<void> wishlistToggled({
    required String productId,
    required bool added,
  }) async {
    if (added) {
      try {
        await _analytics.logAddToWishlist(items: [
          AnalyticsEventItem(itemId: productId),
        ]);
      } catch (e, st) {
        talker.handle(e, st, 'analytics: wishlistToggled(add) failed');
      }
    } else {
      // No predefined "remove from wishlist" — record a custom event so the
      // funnel still shows the unfavorite action.
      await _safeLog('remove_from_wishlist', {'item_id': productId});
    }
  }

  // ── checkout ──────────────────────────────────────────────────────────

  @override
  Future<void> beginCheckout({
    required double value,
    required int itemsCount,
    String currency = 'UZS',
  }) async {
    try {
      await _analytics.logBeginCheckout(
        currency: currency,
        value: value,
        parameters: {'items_count': itemsCount},
      );
    } catch (e, st) {
      talker.handle(e, st, 'analytics: beginCheckout failed');
    }
  }

  @override
  Future<void> shippingInfoAdded({String? city}) async {
    try {
      await _analytics.logAddShippingInfo(
        parameters: city == null ? null : {'city': city},
      );
    } catch (e, st) {
      talker.handle(e, st, 'analytics: shippingInfoAdded failed');
    }
  }

  @override
  Future<void> paymentInfoAdded({required String paymentType}) async {
    try {
      await _analytics.logAddPaymentInfo(paymentType: paymentType);
    } catch (e, st) {
      talker.handle(e, st, 'analytics: paymentInfoAdded failed');
    }
  }

  @override
  Future<void> purchased({
    required String transactionId,
    required double value,
    String currency = 'UZS',
    double? tax,
    double? shipping,
    int? itemsCount,
  }) async {
    try {
      await _analytics.logPurchase(
        transactionId: transactionId,
        currency: currency,
        value: value,
        tax: tax,
        shipping: shipping,
        parameters: itemsCount == null ? null : {'items_count': itemsCount},
      );
    } catch (e, st) {
      talker.handle(e, st, 'analytics: purchased failed');
    }
  }

  // ── chat ──────────────────────────────────────────────────────────────

  @override
  Future<void> chatOpened({
    required String chatId,
    required String viewerRole,
  }) {
    return _safeLog('chat_opened', {
      'chat_id': chatId,
      'viewer_role': viewerRole,
    });
  }

  @override
  Future<void> chatMessageSent({
    required String chatId,
    required String viewerRole,
    required bool hasImage,
  }) {
    return _safeLog('chat_message_sent', {
      'chat_id': chatId,
      'viewer_role': viewerRole,
      'has_image': hasImage ? 1 : 0,
    });
  }

  // ── seller ────────────────────────────────────────────────────────────

  @override
  Future<void> sellerModeEntered() => _safeLog('seller_mode_entered');

  @override
  Future<void> sellerOnboardingStarted() =>
      _safeLog('seller_onboarding_started');

  @override
  Future<void> sellerOnboardingCompleted() =>
      _safeLog('seller_onboarding_completed');

  @override
  Future<void> productCreated({required String productId}) {
    return _safeLog('product_created', {'product_id': productId});
  }

  @override
  Future<void> productUpdated({required String productId}) {
    return _safeLog('product_updated', {'product_id': productId});
  }

  @override
  Future<void> productDeleted({required String productId}) {
    return _safeLog('product_deleted', {'product_id': productId});
  }

  @override
  Future<void> sellerOrderStatusChanged({
    required String orderId,
    required String fromStatus,
    required String toStatus,
  }) {
    return _safeLog('seller_order_status_changed', {
      'order_id': orderId,
      'from_status': fromStatus,
      'to_status': toStatus,
    });
  }

  // ── settings ──────────────────────────────────────────────────────────

  @override
  Future<void> languageChanged({required String code}) {
    return _safeLog('language_changed', {'code': code});
  }

  @override
  Future<void> themeChanged({required String mode}) {
    return _safeLog('theme_changed', {'mode': mode});
  }
}
