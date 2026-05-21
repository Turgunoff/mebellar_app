import '../../core/result/result.dart';
import '../models/review.dart';

/// Seller-side reviews: list every review left on a product belonging to
/// the authenticated seller's shop, and post a reply.
abstract class SellerReviewsRepository {
  /// Every review on this seller's products, newest first.
  Future<Result<List<Review>>> fetchReviews();

  /// Writes the seller reply onto a review. RLS enforces shop ownership.
  /// Resolves to the updated review (with `sellerRepliedAt` populated).
  Future<Result<Review>> postReply({
    required String reviewId,
    required String reply,
  });
}
