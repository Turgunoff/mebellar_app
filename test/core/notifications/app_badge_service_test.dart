import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woody_app/core/notifications/app_badge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('app_badge_plus');
  late List<MethodCall> badgeCalls;

  void stubLauncher({required bool supported}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      badgeCalls.add(call);
      if (call.method == 'isSupported') return supported;
      return null;
    });
  }

  setUp(() {
    badgeCalls = [];
    SharedPreferences.setMockInitialValues({});
    resetAppBadgeSupportCacheForTest();
    stubLauncher(supported: true);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<int?> storedCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getInt('app_badge_count');
  }

  Iterable<MethodCall> updates() =>
      badgeCalls.where((c) => c.method == 'updateBadge');

  group('AppBadgeService', () {
    test('setCount persists the value and writes it to the launcher', () async {
      await AppBadgeService().setCount(5);

      expect(await storedCount(), 5);
      expect(updates().single.arguments['count'], 5);
    });

    test('setCount clamps negatives to zero', () async {
      await AppBadgeService().setCount(-3);

      expect(await storedCount(), 0);
      expect(updates().single.arguments['count'], 0);
    });

    test('clear resets the stored tally and removes the badge', () async {
      await AppBadgeService().setCount(7);
      await AppBadgeService().clear();

      expect(await storedCount(), 0);
      expect(updates().last.arguments['count'], 0);
    });

    test('an unsupported launcher persists but never calls updateBadge',
        () async {
      stubLauncher(supported: false);
      resetAppBadgeSupportCacheForTest();

      await AppBadgeService().setCount(4);

      // The tally still advances (iOS/APNs + the next supported device read it),
      // but the no-op launcher is skipped instead of throwing.
      expect(await storedCount(), 4);
      expect(updates(), isEmpty);
    });
  });

  group('incrementAppBadgeFromBackground', () {
    test('increments the persisted tally on each call', () async {
      await incrementAppBadgeFromBackground();
      expect(await storedCount(), 1);

      await incrementAppBadgeFromBackground();
      expect(await storedCount(), 2);
    });

    test('continues from a value the live app already stored', () async {
      await AppBadgeService().setCount(4);

      await incrementAppBadgeFromBackground();

      expect(await storedCount(), 5);
    });
  });
}
