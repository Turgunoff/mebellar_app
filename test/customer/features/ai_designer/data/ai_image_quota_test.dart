import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/customer/features/ai_designer/data/ai_image_quota.dart';

class _MockBox extends Mock implements Box {}

void main() {
  late Box box;
  late Map<dynamic, dynamic> mem;

  setUp(() {
    mem = {};
    box = _MockBox();
    when(() => box.get(any())).thenAnswer((i) => mem[i.positionalArguments[0]]);
    when(() => box.put(any(), any())).thenAnswer((i) async {
      mem[i.positionalArguments[0]] = i.positionalArguments[1];
    });
  });

  test('allows up to the daily limit, then blocks', () async {
    final quota = AiImageQuota(box: box, dailyLimit: 2);
    expect(quota.usedToday, 0);
    expect(quota.canUpload, isTrue);

    await quota.increment();
    expect(quota.usedToday, 1);
    expect(quota.canUpload, isTrue);

    await quota.increment();
    expect(quota.usedToday, 2);
    expect(quota.canUpload, isFalse, reason: 'reached the daily cap');
  });

  test('a stale day stamp reads as zero (rollover, no cleanup needed)', () {
    // Simulate yesterday's leftover state in the box.
    mem['ai_img_quota_date'] = '1999-1-1';
    mem['ai_img_quota_count'] = 9;
    final quota = AiImageQuota(box: box, dailyLimit: 10);
    expect(quota.usedToday, 0);
    expect(quota.canUpload, isTrue);
  });
}
