class Paginated<T> {
  const Paginated({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
    required this.hasNext,
  });

  final List<T> items;
  final int page;
  final int perPage;
  final int total;
  final bool hasNext;

  factory Paginated.empty() => const Paginated(
        items: [],
        page: 1,
        perPage: 20,
        total: 0,
        hasNext: false,
      );

  factory Paginated.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parse,
  ) {
    final dataRaw = json['data'];
    final items = dataRaw is List
        ? dataRaw.whereType<Map<String, dynamic>>().map(parse).toList()
        : <T>[];
    final meta = json['meta'] is Map<String, dynamic>
        ? json['meta'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final page = (meta['page'] as num?)?.toInt() ?? 1;
    final perPage = (meta['per_page'] as num?)?.toInt() ?? items.length;
    final total = (meta['total'] as num?)?.toInt() ?? items.length;
    final hasNext = meta['has_next'] as bool? ?? (page * perPage < total);
    return Paginated(
      items: items,
      page: page,
      perPage: perPage,
      total: total,
      hasNext: hasNext,
    );
  }

  Paginated<T> append(Paginated<T> next) {
    return Paginated(
      items: [...items, ...next.items],
      page: next.page,
      perPage: next.perPage,
      total: next.total,
      hasNext: next.hasNext,
    );
  }
}
