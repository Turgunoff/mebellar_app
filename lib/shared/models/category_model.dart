import 'package:equatable/equatable.dart';

class SubcategoryModel extends Equatable {
  const SubcategoryModel({
    required this.id,
    required this.categoryId,
    required this.name,
  });

  final String id;
  final String categoryId;
  final String name;

  factory SubcategoryModel.fromJson(Map<String, dynamic> json) {
    return SubcategoryModel(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      name: json['name'] as String,
    );
  }

  @override
  List<Object?> get props => [id, categoryId, name];
}

class CategoryModel extends Equatable {
  const CategoryModel({
    required this.id,
    required this.name,
    this.subtitle,
    this.imageUrl,
    required this.sortOrder,
    this.subcategories = const [],
  });

  final String id;
  final String name;
  final String? subtitle;
  final String? imageUrl;
  final int sortOrder;
  final List<SubcategoryModel> subcategories;

  int get subcategoryCount => subcategories.length;

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    final subs = json['subcategories'];
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      subtitle: json['subtitle'] as String?,
      imageUrl: json['image_url'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      subcategories: subs is List
          ? subs
              .whereType<Map<String, dynamic>>()
              .map(SubcategoryModel.fromJson)
              .toList(growable: false)
          : const [],
    );
  }

  @override
  List<Object?> get props => [id, name, sortOrder, subcategories.length];
}
