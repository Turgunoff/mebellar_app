import '../../config/app_mode.dart';
import '../../core/network/token_store.dart';
import '../../core/network/woody_api_client.dart';
import '../models/notification_model.dart';

abstract class NotificationDataSource {
  /// Returns the authenticated user's notifications, newest first; empty when
  /// there is no session.
  ///
  /// [mode] scopes the result to one app surface — `'customer'` (buyer-facing
  /// + global rows) or `'seller'` (seller-panel rows only) — matching the
  /// backend's `data->>'mode'` audience filter. Omit it for the unfiltered
  /// inbox. The customer inbox passes `'customer'` so seller alerts never leak
  /// into the buyer's bell.
  Future<List<NotificationModel>> list({String? mode});

  /// Same as [list] but lets the caller pass an explicit user id. Useful
  /// when the cubit holds the id from auth state and wants to avoid the
  /// implicit `currentUser` lookup.
  Future<List<NotificationModel>> fetchNotifications(String userId);

  /// Unread count for the given [mode] (the backend scopes `unread_count` to
  /// the audience). Omit [mode] for the all-surfaces total.
  Future<int> unreadCount({String? mode});
  Future<void> markRead(String id);

  /// Marks every unread notification read. [mode] scopes the bulk read to one
  /// surface, so clearing the customer inbox never wipes the seller panel.
  Future<void> markAllRead({String? mode});
}

/// Reads / mutates the customer inbox via `GET /notifications`,
/// `PATCH /notifications/{id}/read` and `POST /notifications/mark-all-read`. The
/// backend scopes every query to the JWT's user, so no client-side user filter
/// is needed; the row carries no `user_id`, so we stamp a synthetic one.
///
/// When [tokens] is wired, guest sessions short-circuit to empty / zero without
/// hitting the network — `GET /notifications` 401s without a JWT, and the
/// launcher-badge sync used to fire that call at every cold start.
class WoodyNotificationDataSource implements NotificationDataSource {
  WoodyNotificationDataSource({required WoodyApiClient api, TokenStore? tokens})
    : _api = api,
      _tokens = tokens;

  final WoodyApiClient _api;
  final TokenStore? _tokens;

  /// `true` when there is a session, or when no [TokenStore] was injected
  /// (unit tests that drive the fake adapter without auth plumbing).
  Future<bool> get _signedIn async {
    final tokens = _tokens;
    if (tokens == null) return true;
    return (tokens.current ?? await tokens.read()) != null;
  }

  @override
  Future<List<NotificationModel>> list({String? mode}) async {
    if (!await _signedIn) return const [];
    final body = await _api.get<Map<String, dynamic>>(
      '/notifications',
      query: mode == null ? null : {'mode': mode},
    );
    final rows = body['rows'] as List<dynamic>? ?? const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(_toModel)
        .toList(growable: false);
  }

  @override
  Future<List<NotificationModel>> fetchNotifications(String userId) => list();

  @override
  Future<int> unreadCount({String? mode}) async {
    if (!await _signedIn) return 0;
    final body = await _api.get<Map<String, dynamic>>(
      '/notifications',
      query: mode == null ? null : {'mode': mode},
    );
    return (body['unread_count'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> markRead(String id) async {
    if (!await _signedIn) return;
    await _api.patch<dynamic>('/notifications/$id/read');
  }

  @override
  Future<void> markAllRead({String? mode}) async {
    if (!await _signedIn) return;
    await _api.post<dynamic>(
      '/notifications/mark-all-read',
      query: mode == null ? null : {'mode': mode},
    );
  }

  NotificationModel _toModel(Map<String, dynamic> r) {
    final rawPayload = r['data'];
    final payload = rawPayload is Map
        ? Map<String, dynamic>.from(rawPayload)
        : null;
    return NotificationModel(
      id: r['id'] as String,
      userId: 'me',
      title: r['title'] as String? ?? '',
      body: r['body'] as String? ?? '',
      kind: NotificationKind.fromString(r['type'] as String?),
      referenceId: r['reference_id'] as String?,
      isRead: r['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(r['created_at'] as String),
      notificationType: NotificationCategory.fromString(
        r['notification_type'] as String?,
      ),
      payload: payload,
    );
  }
}

/// Fallback when there's no Woody session (guest browsing) or in tests.
/// Returns a small canned inbox so the UI still renders something readable
/// instead of an awkward empty state.
class MockNotificationDataSource implements NotificationDataSource {
  static const _delay = Duration(milliseconds: 200);

  final List<NotificationModel> _items = [
    NotificationModel(
      id: 'mock-1',
      userId: 'guest',
      title: 'Welcome to Woody',
      body: 'Tap the heart on any product to save it for later.',
      kind: NotificationKind.general,
      referenceId: null,
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
    ),
    NotificationModel(
      id: 'mock-2',
      userId: 'guest',
      title: 'Spring Collection 2026',
      body: 'Discover the new arrivals — up to 30% off this week.',
      kind: NotificationKind.promo,
      referenceId: null,
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    NotificationModel(
      id: 'mock-3',
      userId: 'guest',
      title: 'Free delivery',
      body: 'Orders above 5M UZS now ship free across Tashkent.',
      kind: NotificationKind.news,
      referenceId: null,
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  /// Mirrors the backend audience filter client-side: `'seller'` keeps only
  /// seller-surface rows, anything else keeps the buyer surface. `null` keeps
  /// all. Lets the mock behave like the real `?mode=` query in tests.
  bool _inMode(NotificationModel n, String? mode) {
    if (mode == null) return true;
    final isSeller = n.resolveTargetMode() == AppMode.seller;
    return mode == AppMode.seller.name ? isSeller : !isSeller;
  }

  @override
  Future<List<NotificationModel>> list({String? mode}) async {
    await Future<void>.delayed(_delay);
    return List.unmodifiable(_items.where((n) => _inMode(n, mode)));
  }

  @override
  Future<List<NotificationModel>> fetchNotifications(String userId) async {
    // The mock ignores the user id and returns the canned list — useful in
    // tests / guest browsing where the cubit still calls through.
    await Future<void>.delayed(_delay);
    return List.unmodifiable(_items);
  }

  @override
  Future<int> unreadCount({String? mode}) async {
    await Future<void>.delayed(_delay);
    return _items.where((n) => !n.isRead && _inMode(n, mode)).length;
  }

  @override
  Future<void> markRead(String id) async {
    await Future<void>.delayed(_delay);
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx < 0 || _items[idx].isRead) return;
    _items[idx] = _items[idx].copyWith(isRead: true);
  }

  @override
  Future<void> markAllRead({String? mode}) async {
    await Future<void>.delayed(_delay);
    for (var i = 0; i < _items.length; i++) {
      if (!_items[i].isRead && _inMode(_items[i], mode)) {
        _items[i] = _items[i].copyWith(isRead: true);
      }
    }
  }
}
