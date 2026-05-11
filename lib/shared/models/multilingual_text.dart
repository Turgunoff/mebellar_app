class MultilingualText {
  const MultilingualText({this.uz, this.ru, this.en});

  final String? uz;
  final String? ru;
  final String? en;

  factory MultilingualText.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MultilingualText();
    return MultilingualText(
      uz: json['uz'] as String?,
      ru: json['ru'] as String?,
      en: json['en'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (uz != null) 'uz': uz,
        if (ru != null) 'ru': ru,
        if (en != null) 'en': en,
      };

  String get(String lang) {
    return switch (lang) {
      'ru' => ru ?? uz ?? en ?? '',
      'en' => en ?? uz ?? ru ?? '',
      _ => uz ?? ru ?? en ?? '',
    };
  }
}
