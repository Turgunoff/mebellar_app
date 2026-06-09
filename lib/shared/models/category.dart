import 'package:equatable/equatable.dart';

import 'multilingual_text.dart';

class Category extends Equatable {
  const Category({
    required this.id,
    required this.slug,
    required this.name,
    this.iconUrl,
    this.imageUrl,
    this.parentSlug,
    this.children = const [],
    this.productCount,
  });

  final String id;
  final String slug;
  final MultilingualText name;
  final String? iconUrl;
  final String? imageUrl;
  final String? parentSlug;
  final List<Category> children;
  final int? productCount;

  bool get hasChildren => children.isNotEmpty;

  factory Category.fromJson(Map<String, dynamic> json) {
    final childrenRaw = json['children'];
    final children = childrenRaw is List
        ? childrenRaw
            .whereType<Map<String, dynamic>>()
            .map(Category.fromJson)
            .toList(growable: false)
        : const <Category>[];
    return Category(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: MultilingualText.fromJson(json['name'] as Map<String, dynamic>?),
      iconUrl: json['icon_url'] as String?,
      imageUrl: json['image_url'] as String?,
      parentSlug: json['parent_slug'] as String?,
      children: children,
      productCount: json['product_count'] as int?,
    );
  }

  @override
  List<Object?> get props => [id, slug, parentSlug, children.length];
}
