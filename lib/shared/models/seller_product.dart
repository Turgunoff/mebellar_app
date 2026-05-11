import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import 'multilingual_text.dart';

/// Seller-side moderation states for products. Public catalog only renders
/// `approved`. Anything else is internal to the seller dashboard.
enum SellerProductStatus {
  draft('draft'),
  pendingReview('pending_review'),
  approved('approved'),
  rejected('rejected'),
  archived('archived');

  const SellerProductStatus(this.code);
  final String code;

  static SellerProductStatus fromCode(String? code) {
    return values.firstWhere(
      (s) => s.code == code,
      orElse: () => SellerProductStatus.draft,
    );
  }

  bool get isPublished => this == SellerProductStatus.approved;
  bool get isMutable =>
      this == SellerProductStatus.draft || this == SellerProductStatus.rejected;

  IconData get icon => switch (this) {
        SellerProductStatus.draft => Icons.edit_note_outlined,
        SellerProductStatus.pendingReview => Icons.hourglass_top_outlined,
        SellerProductStatus.approved => Icons.check_circle_outline,
        SellerProductStatus.rejected => Icons.error_outline,
        SellerProductStatus.archived => Icons.inventory_outlined,
      };
}

class SellerProductImage extends Equatable {
  const SellerProductImage({
    required this.id,
    this.localPath,
    this.remoteUrl,
    this.uploadProgress = 1.0,
    this.uploading = false,
    this.error,
  });

  final String id;
  final String? localPath;
  final String? remoteUrl;
  final double uploadProgress;
  final bool uploading;
  final String? error;

  bool get isUploaded => remoteUrl != null;
  String? get displayUrl => remoteUrl ?? localPath;

  SellerProductImage copyWith({
    String? remoteUrl,
    double? uploadProgress,
    bool? uploading,
    String? error,
    bool clearError = false,
  }) {
    return SellerProductImage(
      id: id,
      localPath: localPath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      uploading: uploading ?? this.uploading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props =>
      [id, localPath, remoteUrl, uploadProgress, uploading, error];
}

class SellerProduct extends Equatable {
  const SellerProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.categorySlug,
    required this.price,
    this.oldPrice,
    required this.stock,
    required this.sku,
    required this.images,
    this.primaryImageId,
    this.attributes = const {},
    this.lengthCm,
    this.widthCm,
    this.heightCm,
    this.weightKg,
    required this.status,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final MultilingualText name;
  final MultilingualText description;
  final String categorySlug;
  final num price;
  final num? oldPrice;
  final int stock;
  final String sku;
  final List<SellerProductImage> images;
  final String? primaryImageId;
  final Map<String, dynamic> attributes;
  final num? lengthCm;
  final num? widthCm;
  final num? heightCm;
  final num? weightKg;
  final SellerProductStatus status;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  String? get heroImage {
    if (images.isEmpty) return null;
    final primary = primaryImageId == null
        ? images.first
        : images.firstWhere(
            (img) => img.id == primaryImageId,
            orElse: () => images.first,
          );
    return primary.displayUrl;
  }

  SellerProduct copyWith({
    MultilingualText? name,
    MultilingualText? description,
    String? categorySlug,
    num? price,
    num? oldPrice,
    int? stock,
    String? sku,
    List<SellerProductImage>? images,
    String? primaryImageId,
    Map<String, dynamic>? attributes,
    num? lengthCm,
    num? widthCm,
    num? heightCm,
    num? weightKg,
    SellerProductStatus? status,
    String? rejectionReason,
    bool clearRejectionReason = false,
    DateTime? updatedAt,
  }) {
    return SellerProduct(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      categorySlug: categorySlug ?? this.categorySlug,
      price: price ?? this.price,
      oldPrice: oldPrice ?? this.oldPrice,
      stock: stock ?? this.stock,
      sku: sku ?? this.sku,
      images: images ?? this.images,
      primaryImageId: primaryImageId ?? this.primaryImageId,
      attributes: attributes ?? this.attributes,
      lengthCm: lengthCm ?? this.lengthCm,
      widthCm: widthCm ?? this.widthCm,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      status: status ?? this.status,
      rejectionReason: clearRejectionReason
          ? null
          : (rejectionReason ?? this.rejectionReason),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, status, updatedAt, images.length];
}
