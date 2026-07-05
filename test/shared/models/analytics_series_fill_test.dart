import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/shared/models/analytics.dart';

void main() {
  test('fillRevenueSeries spans all 30 day buckets', () {
    final now = DateTime.utc(2026, 7, 5, 12);
    const filter = AnalyticsFilter(range: AnalyticsRange.d30);
    final sparse = [
      RevenuePoint(bucketStart: DateTime.utc(2026, 6, 26), revenue: 100),
      RevenuePoint(bucketStart: DateTime.utc(2026, 6, 28), revenue: 200),
    ];

    final filled = filter.fillRevenueSeries(sparse, now: now);

    expect(filled.length, 30);
    expect(filled.first.bucketStart, DateTime.utc(2026, 6, 6));
    expect(filled.last.bucketStart, DateTime.utc(2026, 7, 5));
    expect(filled[20].revenue, 100);
    expect(filled[21].revenue, 0);
    expect(filled[22].revenue, 200);
  });
}
