import 'package:woody_app/core/error/failure.dart';
import 'package:woody_app/core/result/result.dart';
import 'package:woody_app/shared/models/analytics.dart';
import 'package:woody_app/shared/repositories/seller_analytics_repository.dart';

/// Test double for [SellerAnalyticsRepository] with deterministic snapshots.
///
/// Per-filter overrides + a "next call fails" knob cover every cubit branch
/// (initial load, success → success refetch, filter change, failure, racy
/// out-of-order responses). Custom filters fall back to the preset-keyed
/// snapshot for their underlying range so tests don't have to enumerate
/// every custom window.
class FakeSellerAnalyticsRepository implements SellerAnalyticsRepository {
  FakeSellerAnalyticsRepository({Map<AnalyticsRange, AnalyticsSnapshot>? seed})
      : _byRange = {...?seed};

  final Map<AnalyticsRange, AnalyticsSnapshot> _byRange;
  Failure? _nextFailure;
  Future<void> Function()? _onSnapshotCalled;

  /// Last filter the cubit asked for — useful for verifying call sequencing.
  AnalyticsFilter? lastRequested;

  int snapshotCalls = 0;

  /// Override the snapshot returned for [range] on subsequent calls.
  void setSnapshot(AnalyticsRange range, AnalyticsSnapshot snapshot) {
    _byRange[range] = snapshot;
  }

  /// The next `snapshot(...)` call resolves to an `Err` carrying this
  /// failure, then the failure clears. Lets tests force a single bad
  /// fetch without sticking with it on subsequent retries.
  void failNextWith(Failure failure) => _nextFailure = failure;

  /// Inject an async hook that runs inside `snapshot(...)` before the
  /// result resolves — lets tests interleave events (e.g. issue a range
  /// change while an in-flight fetch is pending).
  set onSnapshotCalled(Future<void> Function()? hook) =>
      _onSnapshotCalled = hook;

  @override
  Future<Result<AnalyticsSnapshot>> snapshot(
    AnalyticsFilter filter, {
    DateTime? now,
  }) async {
    snapshotCalls += 1;
    lastRequested = filter;
    final hook = _onSnapshotCalled;
    if (hook != null) await hook();
    final failure = _nextFailure;
    if (failure != null) {
      _nextFailure = null;
      return Err(failure);
    }
    final snap = _byRange[filter.range] ?? AnalyticsSnapshot.empty(filter);
    return Ok(snap);
  }
}
