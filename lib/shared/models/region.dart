import 'package:equatable/equatable.dart';

import 'multilingual_text.dart';

class Region extends Equatable {
  const Region({
    required this.id,
    required this.code,
    required this.name,
    this.parentId,
    this.children = const [],
  });

  final String id;
  final String code;
  final MultilingualText name;
  final String? parentId;
  final List<Region> children;

  bool get hasChildren => children.isNotEmpty;

  factory Region.fromJson(Map<String, dynamic> json) {
    final childrenRaw = json['children'];
    final children = childrenRaw is List
        ? childrenRaw
            .whereType<Map<String, dynamic>>()
            .map(Region.fromJson)
            .toList(growable: false)
        : const <Region>[];
    return Region(
      id: json['id'] as String,
      code: json['code'] as String? ?? json['id'] as String,
      name: MultilingualText.fromJson(json['name'] as Map<String, dynamic>?),
      parentId: json['parent_id'] as String?,
      children: children,
    );
  }

  @override
  List<Object?> get props => [id, code, parentId, children.length];
}
