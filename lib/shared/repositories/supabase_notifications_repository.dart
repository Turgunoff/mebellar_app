import 'package:supabase_flutter/supabase_flutter.dart';

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

/// Reads / mutates the `public.notifications` table for the currently
/// authenticated user. RLS policies in
/// `20260510000002_create_notifications_table.sql` already restrict every
/// query to `auth.uid() = user_id`, so we don't need to filter by user_id
/// on the client side.
class SupabaseNotificationsRepository implements NotificationDataSource {
  SupabaseNotificationsRepository({required SupabaseClient supabase})
    : _supabase = supabase;

  final SupabaseClient _supabase;

  @override
  Future<List<NotificationModel>> list() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return const [];
    return fetchNotifications(user.id);
  }

  @override
  Future<List<NotificationModel>> fetchNotifications(String userId) async {
    final data = await _supabase
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (data as List)
        .whereType<Map<String, dynamic>>()
        .map(NotificationModel.fromJson)
        .toList(growable: false);
  }

  @override
  Future<int> unreadCount() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 0;
    final data = await _supabase
        .from('notifications')
        .select('id')
        .eq('user_id', user.id)
        .eq('is_read', false);
    return (data as List).length;
  }

  @override
  Future<void> markRead(String id) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('id', id)
        .eq('user_id', user.id);
  }

  @override
  Future<void> markAllRead() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', user.id)
        .eq('is_read', false);
  }
}

/// Fallback when there's no Supabase session (guest browsing) or in tests.
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
