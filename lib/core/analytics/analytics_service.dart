/// Top-level analytics abstraction. Every screen / cubit / bloc that wants
/// to record user behaviour talks to this interface — never to the SDK
/// directly. That keeps the data model type-safe (no string-typo events),
/// keeps PII out of the wire (the method signatures only accept ids and
/// numbers), and lets us swap the underlying provider (Firebase → PostHog,
/// or add a second sink alongside) without touching call sites.
///
/// All methods are intentionally side-effecting and non-throwing. Analytics
/// failures must never break the user-facing flow, so implementations
/// swallow errors and surface them only through the app's logger.
abstract class AnalyticsService {
  // ── lifecycle ──────────────────────────────────────────────────────────

  /// Tag every subsequent event with the current user. Pass `null` on
  /// sign-out so further events are anonymous.
  Future<void> setUserId(String? userId);

  /// Master switch — used by the settings screen's "Analytics yig'ish"
  /// toggle. Off ⇒ events are dropped at the SDK boundary; on ⇒ collection
  /// resumes immediately.
  Future<void> setAnalyticsEnabled(bool enabled);

  /// Records the current screen — feeds Firebase's screen_view dashboard
  /// and the Crashlytics breadcrumb stack. Called by the router observer.
  Future<void> setCurrentScreen(String screenName);

  // ── auth ──────────────────────────────────────────────────────────────

  Future<void> signedUp({required String method});
  Future<void> loggedIn({required String method});
  Future<void> loggedOut();

  // ── catalog browsing ──────────────────────────────────────────────────

  Future<void> categoryViewed({
    required String categoryId,
    String? subcategoryId,
  });

  Future<void> productViewed({
    required String productId,
    String? categoryId,
    required double price,
    String currency = 'UZS',
  });

  Future<void> searchPerformed({
    required String query,
    required int resultsCount,
    int appliedFiltersCount = 0,
  });

  Future<void> filterApplied({
    required int activeFacetCount,
    String? sort,
  });

  // ── cart / favorites ──────────────────────────────────────────────────

  Future<void> addedToCart({
    required String productId,
    required double price,
    int quantity = 1,
    String currency = 'UZS',
  });

  Future<void> removedFromCart({required String productId});

  Future<void> cartViewed({required double value, String currency = 'UZS'});

  Future<void> wishlistToggled({
    required String productId,
    required bool added,
  });

  // ── checkout ──────────────────────────────────────────────────────────

  Future<void> beginCheckout({
    required double value,
    required int itemsCount,
    String currency = 'UZS',
  });

  Future<void> shippingInfoAdded({String? city});
  Future<void> paymentInfoAdded({required String paymentType});

  /// Final conversion event — the most valuable signal in the funnel.
  /// `transactionId` MUST be unique per order; passing the same id twice
  /// would mean a double-counted purchase in the dashboard.
  Future<void> purchased({
    required String transactionId,
    required double value,
    String currency = 'UZS',
    double? tax,
    double? shipping,
    int? itemsCount,
  });

  // ── chat ──────────────────────────────────────────────────────────────

  Future<void> chatOpened({
    required String chatId,
    required String viewerRole,
  });

  Future<void> chatMessageSent({
    required String chatId,
    required String viewerRole,
    required bool hasImage,
  });

  // ── seller actions ────────────────────────────────────────────────────

  Future<void> sellerModeEntered();
  Future<void> sellerOnboardingStarted();
  Future<void> sellerOnboardingCompleted();

  Future<void> productCreated({required String productId});
  Future<void> productUpdated({required String productId});
  Future<void> productDeleted({required String productId});

  Future<void> sellerOrderStatusChanged({
    required String orderId,
    required String fromStatus,
    required String toStatus,
  });

  // ── settings / preferences ────────────────────────────────────────────

  Future<void> languageChanged({required String code});
  Future<void> themeChanged({required String mode});
}
