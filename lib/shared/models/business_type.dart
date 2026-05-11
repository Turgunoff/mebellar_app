/// Legal entity type the seller registers as. Determines which extra
/// verification documents the wizard collects (sole-proprietorships and
/// LLCs need certificates + tax IDs, individuals don't).
enum BusinessType {
  individual('individual'),
  selfEmployed('self_employed'),
  llc('llc'),
  corporation('corporation');

  const BusinessType(this.code);
  final String code;

  static BusinessType? fromCode(String? code) {
    if (code == null) return null;
    for (final t in values) {
      if (t.code == code) return t;
    }
    return null;
  }

  /// Whether the seller must upload a state registration certificate +
  /// tax ID on top of the personal ID documents.
  bool get requiresBusinessDocs =>
      this == BusinessType.selfEmployed ||
      this == BusinessType.llc ||
      this == BusinessType.corporation;
}
