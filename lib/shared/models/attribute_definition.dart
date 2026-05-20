import 'package:equatable/equatable.dart';

import 'attribute_option.dart';

/// Data type discriminator for [AttributeDefinition]. Drives which widget the
/// dynamic form renders and how the value is interpreted when round-tripping
/// through `products.attributes` JSONB.
enum AttributeDataType {
  select,
  multiselect,
  number,
  text,
  bool_,
}

extension AttributeDataTypeX on AttributeDataType {
  String get wireValue {
    switch (this) {
      case AttributeDataType.select:
        return 'select';
      case AttributeDataType.multiselect:
        return 'multiselect';
      case AttributeDataType.number:
        return 'number';
      case AttributeDataType.text:
        return 'text';
      case AttributeDataType.bool_:
        return 'bool';
    }
  }

  static AttributeDataType fromWire(String wire) {
    switch (wire) {
      case 'select':
        return AttributeDataType.select;
      case 'multiselect':
        return AttributeDataType.multiselect;
      case 'number':
        return AttributeDataType.number;
      case 'text':
        return AttributeDataType.text;
      case 'bool':
        return AttributeDataType.bool_;
      default:
        throw ArgumentError('Unknown AttributeDataType: $wire');
    }
  }
}

/// A single collectable attribute, scoped to either a category or a
/// subcategory (exactly one — enforced by a DB CHECK constraint). Carries the
/// canonical JSONB key, localised labels, type discriminator, optional unit,
/// requiredness, sort order, and (for select/multiselect) the value options.
class AttributeDefinition extends Equatable {
  const AttributeDefinition({
    required this.id,
    required this.categoryId,
    required this.subcategoryId,
    required this.key,
    required this.labelUz,
    required this.labelRu,
    required this.dataType,
    required this.unit,
    required this.isRequired,
    required this.sortOrder,
    this.options = const [],
  });

  final String id;
  final String? categoryId;
  final String? subcategoryId;
  final String key;
  final String labelUz;
  final String labelRu;
  final AttributeDataType dataType;
  final String? unit;
  final bool isRequired;
  final int sortOrder;
  final List<AttributeOption> options;

  /// True when the row was authored against a subcategory rather than the
  /// parent category. Used by the merger to decide collision precedence.
  bool get isSubcategoryScoped => subcategoryId != null;

  String labelFor(String locale) {
    if (locale.toLowerCase().startsWith('ru')) return labelRu;
    return labelUz;
  }

  factory AttributeDefinition.fromJson(
    Map<String, dynamic> json, {
    List<AttributeOption> options = const [],
  }) {
    return AttributeDefinition(
      id: json['id'] as String,
      categoryId: json['category_id'] as String?,
      subcategoryId: json['subcategory_id'] as String?,
      key: json['key'] as String,
      labelUz: json['label_uz'] as String,
      labelRu: json['label_ru'] as String,
      dataType: AttributeDataTypeX.fromWire(json['data_type'] as String),
      unit: json['unit'] as String?,
      isRequired: json['is_required'] as bool? ?? false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      options: options,
    );
  }

  AttributeDefinition copyWith({List<AttributeOption>? options}) {
    return AttributeDefinition(
      id: id,
      categoryId: categoryId,
      subcategoryId: subcategoryId,
      key: key,
      labelUz: labelUz,
      labelRu: labelRu,
      dataType: dataType,
      unit: unit,
      isRequired: isRequired,
      sortOrder: sortOrder,
      options: options ?? this.options,
    );
  }

  @override
  List<Object?> get props => [
        id,
        categoryId,
        subcategoryId,
        key,
        labelUz,
        labelRu,
        dataType,
        unit,
        isRequired,
        sortOrder,
        options,
      ];
}
