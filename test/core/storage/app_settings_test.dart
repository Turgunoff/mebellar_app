import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:woody_app/core/storage/app_settings.dart';

void main() {
  late Directory tmp;
  late Box box;
  late AppSettings settings;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('woody_app_settings_');
    Hive.init(tmp.path);
    box = await Hive.openBox('settings');
    settings = AppSettings(box);
  });

  tearDown(() async {
    await Hive.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('seller welcome flag', () {
    test('defaults to false for an unknown seller', () {
      expect(settings.hasSeenSellerWelcome('seller-1'), isFalse);
    });

    test('round-trips after being marked seen', () async {
      await settings.setSellerWelcomeSeen('seller-1');
      expect(settings.hasSeenSellerWelcome('seller-1'), isTrue);
    });

    test('is isolated per seller id', () async {
      await settings.setSellerWelcomeSeen('seller-1');
      expect(settings.hasSeenSellerWelcome('seller-1'), isTrue);
      expect(settings.hasSeenSellerWelcome('seller-2'), isFalse);
    });

    test('survives clearUserScopedKeys (logout must not replay it)', () async {
      await settings.setSellerWelcomeSeen('seller-1');
      await settings.clearUserScopedKeys();
      expect(settings.hasSeenSellerWelcome('seller-1'), isTrue);
    });
  });
}
