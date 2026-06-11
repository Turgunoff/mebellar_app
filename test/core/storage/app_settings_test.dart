import 'dart:io';

import 'package:flutter/material.dart' show ThemeMode;
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

  group('theme mode', () {
    test('defaults to system when nothing is persisted', () {
      expect(settings.themeMode, ThemeMode.system);
    });

    test('round-trips each explicit mode', () async {
      await settings.setThemeMode(ThemeMode.dark);
      expect(settings.themeMode, ThemeMode.dark);
      await settings.setThemeMode(ThemeMode.light);
      expect(settings.themeMode, ThemeMode.light);
      await settings.setThemeMode(ThemeMode.system);
      expect(settings.themeMode, ThemeMode.system);
    });

    test('migrates a legacy isDarkMode=true to ThemeMode.dark', () async {
      await box.put('isDarkMode', true);
      expect(settings.themeMode, ThemeMode.dark);
    });

    test('legacy isDarkMode=false still follows system (not light)', () async {
      await box.put('isDarkMode', false);
      expect(settings.themeMode, ThemeMode.system);
    });

    test('explicit theme_mode wins over the legacy bool', () async {
      await box.put('isDarkMode', true);
      await settings.setThemeMode(ThemeMode.light);
      expect(settings.themeMode, ThemeMode.light);
    });

    test('survives clearUserScopedKeys (device-level preference)', () async {
      await settings.setThemeMode(ThemeMode.dark);
      await settings.clearUserScopedKeys();
      expect(settings.themeMode, ThemeMode.dark);
    });
  });
}
