import '../../core/result/result.dart';
import '../models/analytics.dart';

/// Read-only analytics surface for the seller dashboard. The implementation
/// owns the SQL aggregation; consumers (the cubit + screen) only deal in
/// the post-aggregated [AnalyticsSnapshot] value.
abstract class SellerAnalyticsRepository {
  /// Snapshot for [range], anchored on [now] (defaults to current wall
  /// clock — overridable for deterministic tests / fixed-time previews).
  Future<Result<AnalyticsSnapshot>> snapshot(
    AnalyticsRange range, {
    DateTime? now,
  });
}
