class LegalDocument {
  const LegalDocument({
    required this.id,
    required this.type,
    required this.content,
    required this.version,
    this.lang = 'uz',
    this.updatedAt,
  });

  final String id;
  final String type;
  final String lang;
  final String content;
  final String version;
  final DateTime? updatedAt;

  factory LegalDocument.fromJson(Map<String, dynamic> json) {
    return LegalDocument(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'seller_oferta',
      lang: json['lang'] as String? ?? 'uz',
      content: json['content'] as String? ?? '',
      version: json['version'] as String? ?? '1.0',
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }
}
