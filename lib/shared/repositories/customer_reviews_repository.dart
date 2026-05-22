import '../../core/result/result.dart';
import '../models/review.dart';

/// Aggregated review data for a product page: the average score, total
/// count, and the most recent review rows.
class ProductReviewSummary {
  const ProductReviewSummary({
    required this.average,
    required this.count,
    required this.reviews,
  });

  final double average;
  final int count;
  final List<Review> reviews;

  bool get isEmpty => count == 0;

  static const ProductReviewSummary empty =
      ProductReviewSummary(average: 0, count: 0, reviews: []);
}

/// Customer-side reviews: write a review for a delivered order item, read
/// back which order lines the customer has already reviewed, and load the
/// public review list for a product page.
///
/// All writes are RLS-guarded — the `reviews` table only accepts a row whose
/// `customer_id` is the caller and whose order is `delivered` (enforced by a
/// trigger). See `20260521013046_create_reviews_table.sql`.
abstract class CustomerReviewsRepository {
  /// The current user's reviews on [orderId], keyed by `order_item_id`. Used
  /// by the order screen to show which products are still un-reviewed.
  Future<Result<Map<String, Review>>> reviewsForOrder(String orderId);

  /// Inserts a new review for a delivered order item.
  Future<Result<Review>> submitReview({
    required String orderItemId,
    required String orderId,
    required String productId,
    required int rating,
    String? comment,
  });

  /// Edits the rating/comment of an existing review the customer owns.
  Future<Result<Review>> updateReview({
    required String reviewId,
    required int rating,
    String? comment,
  });

  /// Public review list + aggregate for a product page, newest first.
  Future<Result<ProductReviewSummary>> reviewsForProduct(String productId);
}
