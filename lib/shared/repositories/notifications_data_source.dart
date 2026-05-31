import '../../core/network/woody_api_client.dart';
import '../models/notification_model.dart';

abstract class NotificationDataSource {
  /// Returns every notification for the *currently authenticated* user,
  /// newest first. Returns an empty list when there is no session.
  Future<List<NotificationModel>> list();

  /// Same as [list] but lets the caller pass an explicit user id. Useful
  /// when the cubit holds the id from auth state and wants to avoid the
  /// implicit `currentUser` lookup.
  Future<List<NotificationModel>> fetchNotifications(String userId);

  Future<int> unreadCount();
  Future<void> markRead(String id);
  Future<void> markAllRead();
}

/// Reads / mutates the customer inbox via `GET /notifications`,
/// `PATCH /notifications/{id}/read` and `POST /notifications/read-all`. The
/// backend scopes every query to the JWT's user, so no client-side user filter
/// is needed; the row carries no `user_id`, so we stamp a synthetic one.
class WoodyNotificationDataSource implements NotificationDataSource {
  WoodyNotificationDataSource({required WoodyApiClient api}) : _api = api;

  final WoodyApiClient _api;

  @override
  Future<List<NotificationModel>> list() async {
    final body = await _api.get<Map<String, dynamic>>('/notifications');
    final rows = body['rows'] as List<dynamic>? ?? const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(_toModel)
        .toList(growable: false);
  }

  @override
  Future<List<NotificationModel>> fetchNotifications(String userId) => list();

  @override
  Future<int> unreadCount() async {
    final body = await _api.get<Map<String, dynamic>>('/notifications');
    return (body['unread_count'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> markRead(String id) async {
    await _api.patch<dynamic>('/notifications/$id/read');
  }

  @override
  Future<void> markAllRead() async {
    await _api.post<dynamic>('/notifications/read-all');
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

  @override
  Future<List<NotificationModel>> list() async {
    await Future<void>.delayed(_delay);
    return List.unmodifiable(_items);
  }

  @override
  Future<List<NotificationModel>> fetchNotifications(String userId) async {
    // The mock ignores the user id and returns the canned list — useful in
    // tests / guest browsing where the cubit still calls through.
    await Future<void>.delayed(_delay);
    return List.unmodifiable(_items);
  }

  @override
  Future<int> unreadCount() async {
    await Future<void>.delayed(_delay);
    return _items.where((n) => !n.isRead).length;
  }

  @override
  Future<void> markRead(String id) async {
    await Future<void>.delayed(_delay);
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx < 0 || _items[idx].isRead) return;
    _items[idx] = _items[idx].copyWith(isRead: true);
  }

  @override
  Future<void> markAllRead() async {
    await Future<void>.delayed(_delay);
    for (var i = 0; i < _items.length; i++) {
      if (!_items[i].isRead) _items[i] = _items[i].copyWith(isRead: true);
    }
  }
}
