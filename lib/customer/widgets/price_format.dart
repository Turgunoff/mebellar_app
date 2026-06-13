import '../../core/i18n/i18n.dart';

/// Customer-feed price formatter: grouped thousands + ` UZS`
/// (e.g. `6,292,203 UZS`). Shared by the home feed and the category product
/// list so a row's effective/old price reads identically across the grid and
/// list cards instead of each surface re-deriving the same `NumberFormat`.
String formatUzsPrice(double price) =>
    '${NumberFormat('#,##0', 'en_US').format(price)} UZS';
