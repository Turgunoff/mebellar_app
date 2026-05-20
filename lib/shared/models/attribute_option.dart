import 'package:equatable/equatable.dart';

/// A single allowed value for a `select` / `multiselect` [AttributeDefinition].
/// The canonical [value] is what persists into `products.attributes` JSONB;
/// [labelUz] / [labelRu] are the user-facing labels resolved at render time.
class AttributeOption extends Equatable {
  const AttributeOption({
    required this.id,
    required this.attributeId,
    required this.value,
    required this.labelUz,
    required this.labelRu,
    required this.sortOrder,
  });

  final String id;
  final String attributeId;
  final String value;
  final String labelUz;
  final String labelRu;
  final int sortOrder;

  String labelFor(String locale) {
    if (locale.toLowerCase().startsWith('ru')) return labelRu;
    return labelUz;
  }

  factory AttributeOption.fromJson(Map<String, dynamic> json) {
    return AttributeOption(
      id: json['id'] as String,
      attributeId: json['attribute_id'] as String,
      value: json['value'] as String,
      labelUz: json['label_uz'] as String,
      labelRu: json['label_ru'] as String,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props =>
      [id, attributeId, value, labelUz, labelRu, sortOrder];
}
