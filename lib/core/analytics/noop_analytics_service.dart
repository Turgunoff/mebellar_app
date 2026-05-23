import 'analytics_service.dart';

/// No-op fallback used in tests, golden runs, and the no-Firebase build.
/// Every method completes immediately so call sites can fire-and-forget
/// without conditional checks.
class NoopAnalyticsService implements AnalyticsService {
  const NoopAnalyticsService();

  @override
  Future<void> setUserId(String? userId) async {}

  @override
  Future<void> setAnalyticsEnabled(bool enabled) async {}

  @override
  Future<void> setCurrentScreen(String screenName) async {}

  @override
  Future<void> signedUp({required String method}) async {}

  @override
  Future<void> loggedIn({required String method}) async {}

  @override
  Future<void> loggedOut() async {}

  @override
  Future<void> categoryViewed({
    required String categoryId,
    String? subcategoryId,
  }) async {}

  @override
  Future<void> productViewed({
    required String productId,
    String? categoryId,
    required double price,
    String currency = 'UZS',
  }) async {}

  @override
  Future<void> searchPerformed({
    required String query,
    required int resultsCount,
    int appliedFiltersCount = 0,
  }) async {}

  @override
  Future<void> filterApplied({
    required int activeFacetCount,
    String? sort,
  }) async {}

  @override
  Future<void> addedToCart({
    required String productId,
    required double price,
    int quantity = 1,
    String currency = 'UZS',
  }) async {}

  @override
  Future<void> removedFromCart({required String productId}) async {}

  @override
  Future<void> cartViewed({
    required double value,
    String currency = 'UZS',
  }) async {}

  @override
  Future<void> wishlistToggled({
    required String productId,
    required bool added,
  }) async {}

  @override
  Future<void> beginCheckout({
    required double value,
    required int itemsCount,
    String currency = 'UZS',
  }) async {}

  @override
  Future<void> shippingInfoAdded({String? city}) async {}

  @override
  Future<void> paymentInfoAdded({required String paymentType}) async {}

  @override
  Future<void> purchased({
    required String transactionId,
    required double value,
    String currency = 'UZS',
    double? tax,
    double? shipping,
    int? itemsCount,
  }) async {}

  @override
  Future<void> chatOpened({
    required String chatId,
    required String viewerRole,
  }) async {}

  @override
  Future<void> chatMessageSent({
    required String chatId,
    required String viewerRole,
    required bool hasImage,
  }) async {}

  @override
  Future<void> sellerModeEntered() async {}

  @override
  Future<void> sellerOnboardingStarted() async {}

  @override
  Future<void> sellerOnboardingCompleted() async {}

  @override
  Future<void> productCreated({required String productId}) async {}

  @override
  Future<void> productUpdated({required String productId}) async {}

  @override
  Future<void> productDeleted({required String productId}) async {}

  @override
  Future<void> sellerOrderStatusChanged({
    required String orderId,
    required String fromStatus,
    required String toStatus,
  }) async {}

  @override
  Future<void> languageChanged({required String code}) async {}

  @override
  Future<void> themeChanged({required String mode}) async {}
}
