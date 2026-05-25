import 'package:equatable/equatable.dart';

import 'multilingual_text.dart';

class HomeBanner extends Equatable {
  const HomeBanner({
    required this.id,
    required this.imageUrl,
    this.title,
    this.subtitle,
    this.linkType,
    this.linkTarget,
  });

  final String id;
  final String imageUrl;
  final MultilingualText? title;
  final MultilingualText? subtitle;
  final String? linkType; // 'category' | 'product' | 'shop' | 'url'
  final String? linkTarget;

  factory HomeBanner.fromJson(Map<String, dynamic> json) {
    return HomeBanner(
      id: json['id'] as String,
      imageUrl: json['image_url'] as String? ?? '',
      title: MultilingualText.fromJson(json['title'] as Map<String, dynamic>?),
      subtitle: MultilingualText.fromJson(
        json['subtitle'] as Map<String, dynamic>?,
      ),
      linkType: json['link_type'] as String?,
      linkTarget: json['link_target'] as String?,
    );
  }

  /// Maps a flat Supabase row (plain text columns) to [HomeBanner].
  /// Both [title] and [subtitle] are stored as single-language strings
  /// in the DB; they are broadcast to all locales so the app renders them
  /// regardless of the user's chosen language.
  factory HomeBanner.fromSupabaseJson(Map<String, dynamic> json) {
    final title = json['title'] as String?;
    final subtitle = json['subtitle'] as String?;
    return HomeBanner(
      id: json['id'] as String,
      imageUrl: json['image_url'] as String? ?? '',
      title: title != null
          ? MultilingualText(uz: title, ru: title, en: title)
          : null,
      subtitle: subtitle != null
          ? MultilingualText(uz: subtitle, ru: subtitle, en: subtitle)
          : null,
      linkType: json['action_type'] as String?,
      linkTarget: json['action_value'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'image_url': imageUrl,
    'title': title?.toJson(),
    'subtitle': subtitle?.toJson(),
    'link_type': linkType,
    'link_target': linkTarget,
  };

  @override
  List<Object?> get props => [id, imageUrl];
}
