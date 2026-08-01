import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:woody_app/core/analytics/analytics_privacy.dart';

void main() {
  late Box box;

  setUp(() async {
    Hive.init('test_analytics_privacy');
    box = await Hive.openBox(
      'analytics_privacy_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() async {
    await box.deleteFromDisk();
  });

  test('defaults to true when the key has never been written', () {
    expect(readAnalyticsCollectionEnabled(box), isTrue);
  });

  test('returns the stored bool', () async {
    await box.put(kAnalyticsCollectionEnabledKey, false);
    expect(readAnalyticsCollectionEnabled(box), isFalse);

    await box.put(kAnalyticsCollectionEnabledKey, true);
    expect(readAnalyticsCollectionEnabled(box), isTrue);
  });

  test('ignores non-bool stored values and falls back to true', () async {
    await box.put(kAnalyticsCollectionEnabledKey, 'nope');
    expect(readAnalyticsCollectionEnabled(box), isTrue);
  });
}
