import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/config/remote_config.dart';
import 'package:woody_app/shared/payments/payment_provider_mode.dart';

void main() {
  group('RemoteConfig.parseMinVersions', () {
    test('reads both platforms from the canonical payload', () {
      final parsed = RemoteConfig.parseMinVersions({
        'android': {'min_version': '1.0.3', 'latest_version': '1.0.9'},
        'ios': {'min_version': '2.0.0', 'latest_version': '2.1.0'},
      });
      expect(parsed.androidMin, '1.0.3');
      expect(parsed.iosMin, '2.0.0');
    });

    test('tolerates a payload missing one platform', () {
      final parsed = RemoteConfig.parseMinVersions({
        'android': {'min_version': '1.0.3'},
      });
      expect(parsed.androidMin, '1.0.3');
      expect(parsed.iosMin, isNull);
    });

    test('empty and whitespace-only strings read as null', () {
      final parsed = RemoteConfig.parseMinVersions({
        'android': {'min_version': ''},
        'ios': {'min_version': '   '},
      });
      expect(parsed.androidMin, isNull);
      expect(parsed.iosMin, isNull);
    });

    test('non-map payloads read as null instead of throwing', () {
      expect(RemoteConfig.parseMinVersions(null).androidMin, isNull);
      expect(RemoteConfig.parseMinVersions('1.0.9').androidMin, isNull);
      expect(
        RemoteConfig.parseMinVersions(<String, dynamic>{}).androidMin,
        isNull,
      );
      expect(
        RemoteConfig.parseMinVersions({'android': '1.0.9'}).androidMin,
        isNull,
      );
    });
  });

  group('RemoteConfig.parseMaintenance', () {
    test('reads enabled flag and trimmed message', () {
      final parsed = RemoteConfig.parseMaintenance({
        'enabled': true,
        'message': '  Tez orada qaytamiz.  ',
      });
      expect(parsed.enabled, isTrue);
      expect(parsed.message, 'Tez orada qaytamiz.');
    });

    test('disabled by default for partial / missing payloads', () {
      expect(RemoteConfig.parseMaintenance({'message': 'x'}).enabled, isFalse);
      expect(
        RemoteConfig.parseMaintenance(<String, dynamic>{}).enabled,
        isFalse,
      );
    });

    test('non-map payloads read as disabled with empty message', () {
      final parsed = RemoteConfig.parseMaintenance(null);
      expect(parsed.enabled, isFalse);
      expect(parsed.message, '');
      expect(RemoteConfig.parseMaintenance('true').enabled, isFalse);
    });

    test('tolerates a string "true" flag', () {
      expect(
        RemoteConfig.parseMaintenance({'enabled': 'true'}).enabled,
        isTrue,
      );
    });
  });

  group('RemoteConfig.parseSupportContacts', () {
    test('reads and trims all three channels', () {
      final parsed = RemoteConfig.parseSupportContacts({
        'support_email': '  help@woody.uz ',
        'support_phone': '+998 90 555 55 55',
        'telegram_channel': '@woody_help',
      });
      expect(parsed.email, 'help@woody.uz');
      expect(parsed.phone, '+998 90 555 55 55');
      expect(parsed.telegram, '@woody_help');
    });

    test('blank / missing fields fall back to the platform defaults', () {
      final parsed = RemoteConfig.parseSupportContacts({
        'support_email': '   ',
        'support_phone': '',
      });
      expect(parsed.email, RemoteConfig.defaultSupportEmail);
      expect(parsed.phone, RemoteConfig.defaultSupportPhone);
      expect(parsed.telegram, RemoteConfig.defaultTelegramChannel);
    });

    test('non-map payloads read as the platform defaults', () {
      final parsed = RemoteConfig.parseSupportContacts(null);
      expect(parsed.email, RemoteConfig.defaultSupportEmail);
      expect(parsed.phone, RemoteConfig.defaultSupportPhone);
      expect(parsed.telegram, RemoteConfig.defaultTelegramChannel);
    });
  });

  group('RemoteConfig.parsePaymentMethods', () {
    test('reads explicit per-provider modes', () {
      final parsed = RemoteConfig.parsePaymentMethods({
        'click': 'hidden',
        'payme': 'enabled',
      });
      expect(parsed.click, PaymentProviderMode.hidden);
      expect(parsed.payme, PaymentProviderMode.enabled);
    });

    test('reads coming_soon mode', () {
      final parsed = RemoteConfig.parsePaymentMethods({
        'click': 'coming_soon',
        'payme': 'enabled',
      });
      expect(parsed.click, PaymentProviderMode.comingSoon);
      expect(parsed.payme, PaymentProviderMode.enabled);
    });

    test('missing / non-map / malformed reads as both enabled', () {
      expect(
        RemoteConfig.parsePaymentMethods(null).click,
        PaymentProviderMode.enabled,
      );
      expect(
        RemoteConfig.parsePaymentMethods(null).payme,
        PaymentProviderMode.enabled,
      );
      expect(
        RemoteConfig.parsePaymentMethods('x').click,
        PaymentProviderMode.enabled,
      );
      final partial = RemoteConfig.parsePaymentMethods({'click': false});
      expect(partial.click, PaymentProviderMode.hidden);
      expect(partial.payme, PaymentProviderMode.enabled);
    });

    test('reads min_topup_uzs with provider modes', () {
      final parsed = RemoteConfig.parsePaymentMethods({
        'click': 'enabled',
        'payme': 'hidden',
        'min_topup_uzs': 100_000,
      });
      expect(parsed.minTopUpUzs, 100_000);
      expect(parsed.payme, PaymentProviderMode.hidden);
    });

    test('missing min_topup_uzs defaults to 50_000', () {
      final parsed = RemoteConfig.parsePaymentMethods({
        'click': 'enabled',
        'payme': 'enabled',
      });
      expect(parsed.minTopUpUzs, RemoteConfig.defaultMinWalletTopUp);
    });

    test('tolerates legacy bool flags', () {
      final parsed = RemoteConfig.parsePaymentMethods({
        'click': 'false',
        'payme': 'true',
      });
      expect(parsed.click, PaymentProviderMode.hidden);
      expect(parsed.payme, PaymentProviderMode.enabled);
    });
  });

  group('RemoteConfig.parseDemoModels', () {
    test('reads both R2 URLs and trims them', () {
      final parsed = RemoteConfig.parseDemoModels({
        'demo_glb_url': '  https://cdn.woody.uz/demo/3d_model_demo.glb ',
        'demo_usdz_url': 'https://cdn.woody.uz/demo/3d_model_demo.usdz',
      });
      expect(parsed.glb, 'https://cdn.woody.uz/demo/3d_model_demo.glb');
      expect(parsed.usdz, 'https://cdn.woody.uz/demo/3d_model_demo.usdz');
    });

    test('missing / non-map payloads read as blank (bundled fallback)', () {
      expect(RemoteConfig.parseDemoModels(null).glb, '');
      expect(RemoteConfig.parseDemoModels(null).usdz, '');
      expect(RemoteConfig.parseDemoModels('x').glb, '');
      expect(
        RemoteConfig.parseDemoModels(<String, dynamic>{}).glb,
        '',
      );
    });

    test('blank stored URL reads as blank', () {
      final parsed = RemoteConfig.parseDemoModels({
        'demo_glb_url': '',
        'demo_usdz_url': '   ',
      });
      expect(parsed.glb, '');
      expect(parsed.usdz, '');
    });
  });

  group('RemoteConfig contact URI helpers', () {
    test('telegramUrl normalises a @handle, bare handle and full URL', () {
      final config = RemoteConfig.instance;
      config.telegramChannel = '@woody_support';
      expect(config.telegramUrl, 'https://t.me/woody_support');
      config.telegramChannel = 'woody_support';
      expect(config.telegramUrl, 'https://t.me/woody_support');
      config.telegramChannel = 'https://t.me/woody_support';
      expect(config.telegramUrl, 'https://t.me/woody_support');
    });

    test('phone helpers strip display spacing', () {
      final config = RemoteConfig.instance;
      config.supportPhone = '+998 71 200 70 07';
      expect(config.supportPhoneUri, 'tel:+998712007007');
      expect(config.whatsappUri, 'https://wa.me/998712007007');
    });
  });
}
