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

  /// Accepts both shapes the backend emits: the canonical `{uz,ru,en}` map
  /// and a plain pre-localised string (the favorites/cart snapshot splice
  /// rewrites `name` to the caller's language server-side). A string is
  /// mirrored into every slot so `get()` resolves regardless of locale.
  factory MultilingualText.fromDynamic(Object? raw) {
    if (raw is String) return MultilingualText(uz: raw, ru: raw, en: raw);
    return MultilingualText.fromJson(raw is Map<String, dynamic> ? raw : null);
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
