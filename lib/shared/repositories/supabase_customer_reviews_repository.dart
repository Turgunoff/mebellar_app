import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/failure.dart';
import '../../core/result/result.dart';
import '../models/review.dart';
import 'customer_reviews_repository.dart';

/// Live Supabase implementation of [CustomerReviewsRepository].
///
/// Schema — `supabase/migrations/20260521013046_create_reviews_table.sql`.
/// A `BEFORE INSERT` trigger backfills `shop_id` and rejects the row unless
/// the order is `delivered` and owned by the caller, so this class only has
/// to pass the user's `customer_id` through; RLS does the rest.
class SupabaseCustomerReviewsRepository implements CustomerReviewsRepository {
  SupabaseCustomerReviewsRepository({required SupabaseClient supabase})
      : _client = supabase;

  final SupabaseClient _client;

  static const String _table = 'reviews';

  static const String _baseColumns =
      'id, order_item_id, product_id, customer_id, rating, comment, '
      'created_at, seller_reply, seller_replied_at';

  /// Adds the buyer's display name — used by the product page review list.
  static const String _productColumns =
      '$_baseColumns, profiles!reviews_customer_id_fkey(full_name)';

  @override
  Future<Result<Map<String, Review>>> reviewsForOrder(String orderId) =>
      runCatching(() async {
        final userId = _requireUserId();
        final rows = await _client
            .from(_table)
            .select(_baseColumns)
            .eq('order_id', orderId)
            .eq('customer_id', userId);
        final byItem = <String, Review>{};
        for (final row in (rows as List).whereType<Map<String, dynamic>>()) {
          final review = Review.fromRow(row);
          final itemId = review.orderItemId;
          if (itemId != null) byItem[itemId] = review;
        }
        return byItem;
      });

  @override
  Future<Result<Review>> submitReview({
    required String orderItemId,
    required String orderId,
    required String productId,
    required int rating,
    String? comment,
  }) =>
      runCatching(() async {
        final userId = _requireUserId();
        final row = await _client
            .from(_table)
            .insert({
              'order_item_id': orderItemId,
              'order_id': orderId,
              'product_id': productId,
              'customer_id': userId,
              'rating': rating,
              'comment': _clean(comment),
            })
            .select(_baseColumns)
            .single();
        return Review.fromRow(row);
      });

  @override
  Future<Result<Review>> updateReview({
    required String reviewId,
    required int rating,
    String? comment,
  }) =>
      runCatching(() async {
        final userId = _requireUserId();
        final row = await _client
            .from(_table)
            .update({'rating': rating, 'comment': _clean(comment)})
            .eq('id', reviewId)
            .eq('customer_id', userId)
            .select(_baseColumns)
            .single();
        return Review.fromRow(row);
      });

  @override
  Future<Result<ProductReviewSummary>> reviewsForProduct(String productId) =>
      runCatching(() async {
        final rows = await _client
            .from(_table)
            .select(_productColumns)
            .eq('product_id', productId)
            .order('created_at', ascending: false)
            .limit(50);
        final reviews = (rows as List)
            .whereType<Map<String, dynamic>>()
            .map(Review.fromRow)
            .toList(growable: false);
        if (reviews.isEmpty) return ProductReviewSummary.empty;
        final total = reviews.fold<int>(0, (sum, r) => sum + r.rating);
        return ProductReviewSummary(
          average: total / reviews.length,
          count: reviews.length,
          reviews: reviews,
        );
      });

  String _requireUserId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthFailure(message: 'Tizimga kirish talab qilinadi');
    }
    return userId;
  }

  /// Trims a comment, collapsing blank input to `null` so the DB column
  /// stays clean rather than holding empty strings.
  static String? _clean(String? comment) {
    final trimmed = comment?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
