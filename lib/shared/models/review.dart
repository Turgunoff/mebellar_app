import 'package:equatable/equatable.dart';

/// One product review, optionally with a seller reply.
///
/// Mirrors a row in `public.reviews`. The seller listing joins the product
/// (for `productName` + `productImage`) and the customer profile (for
/// `customerName`) — those columns ride along as denormalised display
/// strings and are populated from the joined SELECT, not from
/// `reviews.*` directly.
class Review extends Equatable {
  const Review({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.customerName,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.orderItemId,
    this.sellerReply,
    this.sellerRepliedAt,
  });

  final String id;

  /// The reviewed `order_items` row. Present on customer-side rows (used to
  /// match a review back to its order line); the seller listing omits it.
  final String? orderItemId;
  final String productId;
  final String productName;
  final String productImage;
  final String customerName;
  final int rating;
  final String comment;
  final DateTime createdAt;
  final String? sellerReply;
  final DateTime? sellerRepliedAt;

  bool get hasReply => sellerReply != null && sellerReply!.isNotEmpty;

  /// Parses a `public.reviews` row. Embedded `products(name, images)` and
  /// `profiles(full_name)` are optional — when absent (e.g. a customer-side
  /// order-state query that needs only rating/comment) the display fields
  /// degrade to neutral defaults.
  factory Review.fromRow(Map<String, dynamic> row) {
    final product = row['products'];
    final productMap = product is Map<String, dynamic> ? product : const <String, dynamic>{};
    final profile = row['profiles'];
    final profileMap = profile is Map<String, dynamic> ? profile : const <String, dynamic>{};

    return Review(
      id: row['id'] as String,
      orderItemId: row['order_item_id'] as String?,
      productId: row['product_id'] as String,
      productName: _multilingual(productMap['name']) ??
          (productMap['name'] as String? ?? "Mahsulot"),
      productImage: _firstImage(productMap) ?? '',
      customerName: (profileMap['full_name'] as String?)?.trim().isNotEmpty == true
          ? (profileMap['full_name'] as String).trim()
          : 'Xaridor',
      rating: (row['rating'] as num).toInt(),
      comment: (row['comment'] as String?) ?? '',
      createdAt: DateTime.parse(row['created_at'] as String),
      sellerReply: row['seller_reply'] as String?,
      sellerRepliedAt: row['seller_replied_at'] is String
          ? DateTime.parse(row['seller_replied_at'] as String)
          : null,
    );
  }

  Review copyWith({
    String? sellerReply,
    DateTime? sellerRepliedAt,
  }) {
    return Review(
      id: id,
      orderItemId: orderItemId,
      productId: productId,
      productName: productName,
      productImage: productImage,
      customerName: customerName,
      rating: rating,
      comment: comment,
      createdAt: createdAt,
      sellerReply: sellerReply ?? this.sellerReply,
      sellerRepliedAt: sellerRepliedAt ?? this.sellerRepliedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        orderItemId,
        productId,
        productName,
        productImage,
        customerName,
        rating,
        comment,
        createdAt,
        sellerReply,
        sellerRepliedAt,
      ];
}

/// Products store name as `multilingual_text` jsonb. The seller listing
/// only needs the UZ fallback for display — RU/EN switching happens on the
/// customer-facing product page.
String? _multilingual(Object? raw) {
  if (raw is Map) {
    final uz = raw['uz'] as String?;
    if (uz != null && uz.trim().isNotEmpty) return uz.trim();
    final ru = raw['ru'] as String?;
    if (ru != null && ru.trim().isNotEmpty) return ru.trim();
    final en = raw['en'] as String?;
    if (en != null && en.trim().isNotEmpty) return en.trim();
  }
  return null;
}

String? _firstImage(Map<String, dynamic> productMap) {
  final primary = productMap['primary_image'] as String?;
  if (primary != null && primary.isNotEmpty) return primary;
  final images = productMap['images'];
  if (images is List && images.isNotEmpty) {
    final first = images.first;
    if (first is String && first.isNotEmpty) return first;
  }
  return null;
}
