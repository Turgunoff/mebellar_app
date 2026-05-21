import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/failure.dart';
import '../../core/result/result.dart';
import '../models/review.dart';
import 'seller_reviews_repository.dart';

/// Live Supabase implementation of [SellerReviewsRepository].
///
/// Schema — see `supabase/migrations/20260521013046_create_reviews_table.sql`.
/// The seller listing pulls every review where `shop_id` is owned by the
/// authenticated user; the `shop_id` denormalisation on `reviews` is what
/// keeps this a single-table SELECT (modulo the embedded product + profile
/// joins for display fields).
class SupabaseSellerReviewsRepository implements SellerReviewsRepository {
  SupabaseSellerReviewsRepository({required SupabaseClient supabase})
      : _client = supabase;

  final SupabaseClient _client;

  static const String _table = 'reviews';

  /// PostgREST embed names are disambiguated by FK constraint so the schema
  /// cache picks the right relationship the first time (a generic
  /// `profiles!inner(...)` can fail if the cache hasn't refreshed since the
  /// FK was added). `products` only has an `images text[]` array — there is
  /// no separate `primary_image` column, so we let the model pick the first
  /// element of `images`.
  static const String _selectColumns =
      'id, product_id, customer_id, rating, comment, created_at, '
      'seller_reply, seller_replied_at, '
      'products!reviews_product_id_fkey(name, images), '
      'profiles!reviews_customer_id_fkey(full_name)';

  @override
  Future<Result<List<Review>>> fetchReviews() => runCatching(() async {
        final userId = _requireUserId();
        final shopId = await _requireShopId(userId);
        final rows = await _client
            .from(_table)
            .select(_selectColumns)
            .eq('shop_id', shopId)
            .order('created_at', ascending: false);
        return rows
            .map<Review>((row) => Review.fromSellerRow(row))
            .toList(growable: false);
      });

  @override
  Future<Result<Review>> postReply({
    required String reviewId,
    required String reply,
  }) =>
      runCatching(() async {
        final trimmed = reply.trim();
        if (trimmed.isEmpty) {
          throw const ServerFailure(message: "Javob matni bo'sh bo'lishi mumkin emas");
        }
        final row = await _client
            .from(_table)
            .update({
              'seller_reply': trimmed,
              'seller_replied_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', reviewId)
            .select(_selectColumns)
            .single();
        return Review.fromSellerRow(row);
      });

  String _requireUserId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthFailure(message: 'Tizimga kirish talab qilinadi');
    }
    return userId;
  }

  Future<String> _requireShopId(String userId) async {
    final row = await _client
        .from('shops')
        .select('id')
        .eq('seller_id', userId)
        .maybeSingle();
    final shopId = row?['id'] as String?;
    if (shopId == null) {
      throw const ServerFailure(message: "Do'kon topilmadi");
    }
    return shopId;
  }
}
