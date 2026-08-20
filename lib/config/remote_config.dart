import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/logging/app_logger.dart';
import '../core/network/api_error.dart';
import '../core/network/woody_api_client.dart';
import '../shared/payments/payment_provider_mode.dart';

/// Runtime feature flags sourced from the woody_backend `app_settings` table
/// via the public `GET /catalog/settings/{key}` endpoint.
///
/// Unlike [AppConfig] (compile-time env), these can be flipped server-side
/// without shipping a new build. The value is hydrated synchronously from the
/// Hive `settings` box (offline-safe, instant) and refreshed from the network
/// in the background — a failed or pending fetch keeps the last cached value,
/// or `false` on a first launch, so tariff stays *off* rather than wrongly
/// gating sellers behind a paywall.
///
/// Read synchronously anywhere via [RemoteConfig.instance]. Listeners are
/// notified when `payment_methods` (provider modes + min top-up) changes so
/// payment surfaces can rebuild without an app restart.
class RemoteConfig extends ChangeNotifier {
  RemoteConfig._();

  static final RemoteConfig instance = RemoteConfig._();

  /// Master switch for the tariff / subscription system. When `false` the app
  /// hides every tariff surface and product creation is unlimited. Mirrors the
  /// DB `app_settings.tariff_enabled` flag, which the quota triggers also gate
  /// on — so the app and the database agree.
  bool tariffEnabled = false;

  /// Force-update threshold for Android, e.g. `"1.0.3"`. An installed version
  /// below this triggers the blocking force-update overlay. `null` (key missing
  /// server-side or never fetched) means nothing is forced.
  String? androidMinVersion;

  /// Force-update threshold for iOS, e.g. `"1.0.3"`. Same semantics as
  /// [androidMinVersion] — the stores release on independent cadences, so each
  /// platform carries its own threshold.
  String? iosMinVersion;

  /// When `true` the whole app is frozen behind a blocking maintenance overlay
  /// (checked BEFORE the force-update gate). Mirrors `app_settings.maintenance`.
  bool maintenanceEnabled = false;

  /// Customer-facing maintenance copy, set by the operator. Empty until fetched;
  /// the overlay falls back to a localized default when blank.
  String maintenanceMessage = '';

  // Support contacts (email / phone / Telegram). Mirror
  // `app_settings.support_contacts`, edited from the admin panel. Unlike the
  // flags above these carry non-empty platform defaults so the help screen
  // always has a valid channel to launch, even before the first fetch. The
  // cached/fetched values override; a 404 resets to these defaults.
  static const defaultSupportEmail = 'info@woody.uz';
  static const defaultSupportPhone = '+998 94 643 37 33';
  static const defaultTelegramChannel = '@woody_yordam';

  /// Support e-mail address, e.g. `info@woody.uz`.
  String supportEmail = defaultSupportEmail;

  /// Support phone in display form, e.g. `+998 94 643 37 33`.
  String supportPhone = defaultSupportPhone;

  /// Public support Telegram channel, e.g. `@woody_support` (a `@handle` or a
  /// full `t.me` URL — both normalise to [telegramUrl]).
  String telegramChannel = defaultTelegramChannel;

  // Payment-provider modes. Mirror `app_settings.payment_methods`
  // (`{click, payme}`), toggled from the admin panel. Three states per provider:
  // enabled (selectable), comingSoon (visible but greyed out), hidden (not shown).
  // The backend also refuses to mint a checkout link for a non-enabled provider.
  // Default *enabled*: a missing setting or failed fetch must never hide every
  // payment option.

  PaymentProviderMode clickMode = PaymentProviderMode.enabled;
  PaymentProviderMode paymeMode = PaymentProviderMode.enabled;

  /// Whether Click checkout links may be minted / selected.
  bool get clickEnabled => clickMode == PaymentProviderMode.enabled;

  /// Whether Payme checkout links may be minted / selected.
  bool get paymeEnabled => paymeMode == PaymentProviderMode.enabled;

  /// Whether the Click tile should appear in the mobile UI.
  bool get clickVisible => clickMode != PaymentProviderMode.hidden;

  /// Whether the Payme tile should appear in the mobile UI.
  bool get paymeVisible => paymeMode != PaymentProviderMode.hidden;

  /// Whether Click is shown as "coming soon" (visible but not selectable).
  bool get clickComingSoon => clickMode == PaymentProviderMode.comingSoon;

  /// Whether Payme is shown as "coming soon" (visible but not selectable).
  bool get paymeComingSoon => paymeMode == PaymentProviderMode.comingSoon;

  /// Any online provider is selectable right now.
  bool get anyOnlineProviderEnabled => clickEnabled || paymeEnabled;

  /// Any online provider tile should be shown (enabled or coming soon).
  bool get anyOnlineProviderVisible => clickVisible || paymeVisible;

  /// Minimum wallet top-up in whole so'm (online Payme/Click + manual card).
  /// Mirrors `app_settings.payment_methods.min_topup_uzs`; default 50 000.
  static const defaultMinWalletTopUp = 50000;

  int minWalletTopUp = defaultMinWalletTopUp;

  // Demo 3D models (home-screen AR showcase). Mirror `app_settings.demo_models`
  // (`{demo_glb_url, demo_usdz_url}`) — tech-debt roadmap T-04. Blank means "not
  // uploaded to R2 yet"; the caller (`ar_demo_launcher.dart`) then falls back to
  // the bundled `assets/models/3d_model_demo.*` so the AR demo never breaks
  // while the operator is still setting these up.
  String demoGlbUrl = '';
  String demoUsdzUrl = '';

  static const _tariffHiveKey = 'remote_config.tariff_enabled';
  static const _androidMinVersionHiveKey = 'remote_config.android_min_version';
  static const _iosMinVersionHiveKey = 'remote_config.ios_min_version';
  static const _maintenanceEnabledHiveKey = 'remote_config.maintenance_enabled';
  static const _maintenanceMessageHiveKey = 'remote_config.maintenance_message';
  static const _supportEmailHiveKey = 'remote_config.support_email';
  static const _supportPhoneHiveKey = 'remote_config.support_phone';
  static const _telegramChannelHiveKey = 'remote_config.telegram_channel';
  static const _clickModeHiveKey = 'remote_config.click_mode';
  static const _paymeModeHiveKey = 'remote_config.payme_mode';
  static const _minWalletTopUpHiveKey = 'remote_config.min_wallet_topup_uzs';
  static const _demoGlbUrlHiveKey = 'remote_config.demo_glb_url';
  static const _demoUsdzUrlHiveKey = 'remote_config.demo_usdz_url';
  // Legacy bool keys — read once when migrating cached values.
  static const _clickEnabledHiveKey = 'remote_config.click_enabled';
  static const _paymeEnabledHiveKey = 'remote_config.payme_enabled';

  /// `mailto:` URI for [supportEmail].
  String get supportEmailUri => 'mailto:$supportEmail';

  /// `tel:` URI for [supportPhone], stripped to dialable characters (`+`/digits).
  String get supportPhoneUri =>
      'tel:${supportPhone.replaceAll(RegExp(r'[^+\d]'), '')}';

  /// `https://t.me/<handle>` deep link — accepts `@handle`, a bare handle, or a
  /// full `t.me`/`telegram.me` URL and always emits a canonical link.
  String get telegramUrl => 'https://t.me/$_telegramHandle';

  /// Display form of the Telegram channel, always `@handle`.
  String get telegramHandleLabel => '@$_telegramHandle';

  String get _telegramHandle => telegramChannel
      .trim()
      .replaceAll(
        RegExp(r'^https?://(t\.me|telegram\.me)/', caseSensitive: false),
        '',
      )
      .replaceAll('@', '')
      .replaceAll(RegExp(r'/+$'), '');

  /// Seeds the flags from the last cached values. Synchronous, so it can run
  /// at boot before the first frame.
  void hydrateFromCache(Box box) {
    final cached = box.get(_tariffHiveKey);
    if (cached is bool) tariffEnabled = cached;
    final androidMin = box.get(_androidMinVersionHiveKey);
    if (androidMin is String && androidMin.isNotEmpty) {
      androidMinVersion = androidMin;
    }
    final iosMin = box.get(_iosMinVersionHiveKey);
    if (iosMin is String && iosMin.isNotEmpty) iosMinVersion = iosMin;
    final maint = box.get(_maintenanceEnabledHiveKey);
    if (maint is bool) maintenanceEnabled = maint;
    final maintMsg = box.get(_maintenanceMessageHiveKey);
    if (maintMsg is String) maintenanceMessage = maintMsg;
    final email = box.get(_supportEmailHiveKey);
    if (email is String && email.isNotEmpty) supportEmail = email;
    final phone = box.get(_supportPhoneHiveKey);
    if (phone is String && phone.isNotEmpty) supportPhone = phone;
    final tg = box.get(_telegramChannelHiveKey);
    if (tg is String && tg.isNotEmpty) telegramChannel = tg;
    final clickModeRaw = box.get(_clickModeHiveKey);
    if (clickModeRaw is String) {
      clickMode = parsePaymentProviderMode(clickModeRaw);
    } else {
      final clickLegacy = box.get(_clickEnabledHiveKey);
      if (clickLegacy is bool) {
        clickMode = clickLegacy
            ? PaymentProviderMode.enabled
            : PaymentProviderMode.hidden;
      }
    }
    final paymeModeRaw = box.get(_paymeModeHiveKey);
    if (paymeModeRaw is String) {
      paymeMode = parsePaymentProviderMode(paymeModeRaw);
    } else {
      final paymeLegacy = box.get(_paymeEnabledHiveKey);
      if (paymeLegacy is bool) {
        paymeMode = paymeLegacy
            ? PaymentProviderMode.enabled
            : PaymentProviderMode.hidden;
      }
    }
    final minTopUp = box.get(_minWalletTopUpHiveKey);
    if (minTopUp is int && minTopUp >= 1000) {
      minWalletTopUp = minTopUp;
    }
    final demoGlb = box.get(_demoGlbUrlHiveKey);
    if (demoGlb is String) demoGlbUrl = demoGlb;
    final demoUsdz = box.get(_demoUsdzUrlHiveKey);
    if (demoUsdz is String) demoUsdzUrl = demoUsdz;
  }

  Future<void>? _inflightRefresh;

  /// Completes when the in-flight [refresh] does (or immediately when none is
  /// running). The update gate awaits this so a min_version bumped server-side
  /// takes effect on the very launch that fetched it, not the next one.
  Future<void> get whenRefreshed => _inflightRefresh ?? Future.value();

  /// Re-fetches every flag from `GET /catalog/settings/{key}`. Best-effort:
  /// on any failure the cached/default value is kept, so boot is never
  /// blocked on the network. A 404 means the key isn't configured
  /// server-side — tariff is treated as *disabled*, versions as *unset*.
  Future<void> refresh(WoodyApiClient api, Box box) {
    final work = Future.wait([
      _refreshTariff(api, box),
      _refreshAppVersions(api, box),
      _refreshMaintenance(api, box),
      _refreshSupportContacts(api, box),
      _refreshPaymentMethods(api, box),
      _refreshDemoModels(api, box),
    ]).then((_) {}).catchError((Object _, StackTrace _) {});
    _inflightRefresh = work;
    return work;
  }

  Future<void> _refreshTariff(WoodyApiClient api, Box box) async {
    try {
      final body = await api
          .get<Map<String, dynamic>>('/catalog/settings/tariff_enabled')
          .timeout(const Duration(seconds: 6));
      // `value` is the jsonb column — a boolean, but tolerate 'true' too.
      final value = body['value'];
      tariffEnabled = value == true || value == 'true';
      await box.put(_tariffHiveKey, tariffEnabled);
      appLog.info('[remote-config] tariff_enabled=$tariffEnabled');
    } on ApiError catch (e, st) {
      if (e.isNotFound) {
        tariffEnabled = false;
        await box.put(_tariffHiveKey, false);
        return;
      }
      appLog.handle(
        e,
        st,
        '[remote-config] refresh failed — kept cached value',
      );
    } catch (e, st) {
      appLog.handle(
        e,
        st,
        '[remote-config] refresh failed — kept cached value',
      );
    }
  }

  Future<void> _refreshAppVersions(WoodyApiClient api, Box box) async {
    try {
      final body = await api
          .get<Map<String, dynamic>>('/catalog/settings/app_versions')
          .timeout(const Duration(seconds: 6));
      final (:androidMin, :iosMin) = parseMinVersions(body['value']);
      androidMinVersion = androidMin;
      iosMinVersion = iosMin;
      await box.put(_androidMinVersionHiveKey, androidMin ?? '');
      await box.put(_iosMinVersionHiveKey, iosMin ?? '');
      appLog.info('[remote-config] min android=$androidMin ios=$iosMin');
    } on ApiError catch (e, st) {
      if (e.isNotFound) {
        androidMinVersion = null;
        iosMinVersion = null;
        await box.put(_androidMinVersionHiveKey, '');
        await box.put(_iosMinVersionHiveKey, '');
        return;
      }
      appLog.handle(
        e,
        st,
        '[remote-config] app_versions refresh failed — kept cached value',
      );
    } catch (e, st) {
      appLog.handle(
        e,
        st,
        '[remote-config] app_versions refresh failed — kept cached value',
      );
    }
  }

  /// Extracts each platform's `min_version` from the `app_versions` jsonb value:
  /// `{"android": {"min_version": "1.0.0", ...}, "ios": {"min_version": ...}}`.
  /// Defensive against partial / malformed payloads — a missing or non-string
  /// field reads as `null` rather than throwing during boot.
  static ({String? androidMin, String? iosMin}) parseMinVersions(
    dynamic value,
  ) {
    String? minOf(dynamic block) {
      if (block is! Map) return null;
      final v = block['min_version'];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    if (value is! Map) return (androidMin: null, iosMin: null);
    return (androidMin: minOf(value['android']), iosMin: minOf(value['ios']));
  }

  Future<void> _refreshMaintenance(WoodyApiClient api, Box box) async {
    try {
      final body = await api
          .get<Map<String, dynamic>>('/catalog/settings/maintenance')
          .timeout(const Duration(seconds: 6));
      final (:enabled, :message) = parseMaintenance(body['value']);
      maintenanceEnabled = enabled;
      maintenanceMessage = message;
      await box.put(_maintenanceEnabledHiveKey, enabled);
      await box.put(_maintenanceMessageHiveKey, message);
      appLog.info('[remote-config] maintenance=$enabled');
    } on ApiError catch (e, st) {
      if (e.isNotFound) {
        maintenanceEnabled = false;
        maintenanceMessage = '';
        await box.put(_maintenanceEnabledHiveKey, false);
        await box.put(_maintenanceMessageHiveKey, '');
        return;
      }
      appLog.handle(
        e,
        st,
        '[remote-config] maintenance refresh failed — kept cached value',
      );
    } catch (e, st) {
      appLog.handle(
        e,
        st,
        '[remote-config] maintenance refresh failed — kept cached value',
      );
    }
  }

  /// Extracts `(enabled, message)` from the `maintenance` jsonb value:
  /// `{"enabled": true, "message": "..."}`. Defensive — anything unexpected
  /// reads as *disabled* with an empty message rather than throwing at boot.
  static ({bool enabled, String message}) parseMaintenance(dynamic value) {
    if (value is! Map) return (enabled: false, message: '');
    final raw = value['enabled'];
    final enabled = raw == true || raw == 'true';
    final msg = value['message'];
    return (enabled: enabled, message: msg is String ? msg.trim() : '');
  }

  Future<void> _refreshSupportContacts(WoodyApiClient api, Box box) async {
    try {
      final body = await api
          .get<Map<String, dynamic>>('/catalog/settings/support_contacts')
          .timeout(const Duration(seconds: 6));
      final (:email, :phone, :telegram) = parseSupportContacts(body['value']);
      final changed =
          supportEmail != email ||
          supportPhone != phone ||
          telegramChannel != telegram;
      supportEmail = email;
      supportPhone = phone;
      telegramChannel = telegram;
      await box.put(_supportEmailHiveKey, email);
      await box.put(_supportPhoneHiveKey, phone);
      await box.put(_telegramChannelHiveKey, telegram);
      appLog.info('[remote-config] support_contacts updated');
      if (changed) notifyListeners();
    } on ApiError catch (e, st) {
      if (e.isNotFound) {
        // Key not configured server-side — fall back to the platform defaults
        // (not empty), so the help screen still has a channel to launch.
        final changed =
            supportEmail != defaultSupportEmail ||
            supportPhone != defaultSupportPhone ||
            telegramChannel != defaultTelegramChannel;
        supportEmail = defaultSupportEmail;
        supportPhone = defaultSupportPhone;
        telegramChannel = defaultTelegramChannel;
        await box.put(_supportEmailHiveKey, defaultSupportEmail);
        await box.put(_supportPhoneHiveKey, defaultSupportPhone);
        await box.put(_telegramChannelHiveKey, defaultTelegramChannel);
        if (changed) notifyListeners();
        return;
      }
      appLog.handle(
        e,
        st,
        '[remote-config] support_contacts refresh failed — kept cached value',
      );
    } catch (e, st) {
      appLog.handle(
        e,
        st,
        '[remote-config] support_contacts refresh failed — kept cached value',
      );
    }
  }

  /// Extracts `(email, phone, telegram)` from the `support_contacts` jsonb
  /// value: `{"support_email": ..., "support_phone": ..., "telegram_channel":
  /// ...}`. Defensive — a missing or blank field reads as the platform default
  /// rather than an empty string, so a launch URL is never malformed.
  static ({String email, String phone, String telegram}) parseSupportContacts(
    dynamic value,
  ) {
    String pick(dynamic v, String fallback) =>
        v is String && v.trim().isNotEmpty ? v.trim() : fallback;

    if (value is! Map) {
      return (
        email: defaultSupportEmail,
        phone: defaultSupportPhone,
        telegram: defaultTelegramChannel,
      );
    }
    return (
      email: pick(value['support_email'], defaultSupportEmail),
      phone: pick(value['support_phone'], defaultSupportPhone),
      telegram: pick(value['telegram_channel'], defaultTelegramChannel),
    );
  }

  /// Re-fetch only `payment_methods` (provider modes + min wallet top-up).
  /// Payment screens call this on open so an admin toggle takes effect without
  /// forcing an app restart. Failures keep the cached value.
  /// Re-fetch the admin-edited support contacts. Call when opening the help
  /// screen so an admin edit lands without an app restart.
  Future<void> refreshSupportContacts(WoodyApiClient api, Box box) =>
      _refreshSupportContacts(api, box);

  Future<void> refreshPaymentMethods(WoodyApiClient api, Box box) =>
      _refreshPaymentMethods(api, box);

  Future<void> _refreshPaymentMethods(WoodyApiClient api, Box box) async {
    try {
      final body = await api
          .get<Map<String, dynamic>>('/catalog/settings/payment_methods')
          .timeout(const Duration(seconds: 6));
      final (:click, :payme, :minTopUpUzs) = parsePaymentMethods(body['value']);
      final changed =
          clickMode != click ||
          paymeMode != payme ||
          minWalletTopUp != minTopUpUzs;
      clickMode = click;
      paymeMode = payme;
      minWalletTopUp = minTopUpUzs;
      await box.put(_clickModeHiveKey, click.name);
      await box.put(_paymeModeHiveKey, payme.name);
      await box.put(_minWalletTopUpHiveKey, minTopUpUzs);
      appLog.info(
        '[remote-config] payment_methods click=${click.name} payme=${payme.name} '
        'min_topup=$minTopUpUzs',
      );
      if (changed) notifyListeners();
    } on ApiError catch (e, st) {
      if (e.isNotFound) {
        // Key not configured server-side — keep BOTH enabled (never a checkout
        // blackout) rather than resetting to off.
        final changed =
            clickMode != PaymentProviderMode.enabled ||
            paymeMode != PaymentProviderMode.enabled ||
            minWalletTopUp != defaultMinWalletTopUp;
        clickMode = PaymentProviderMode.enabled;
        paymeMode = PaymentProviderMode.enabled;
        minWalletTopUp = defaultMinWalletTopUp;
        await box.put(_clickModeHiveKey, PaymentProviderMode.enabled.name);
        await box.put(_paymeModeHiveKey, PaymentProviderMode.enabled.name);
        await box.put(_minWalletTopUpHiveKey, defaultMinWalletTopUp);
        if (changed) notifyListeners();
        return;
      }
      appLog.handle(
        e,
        st,
        '[remote-config] payment_methods refresh failed — kept cached value',
      );
    } catch (e, st) {
      appLog.handle(
        e,
        st,
        '[remote-config] payment_methods refresh failed — kept cached value',
      );
    }
  }

  /// Extracts per-provider modes and min top-up from the `payment_methods`
  /// jsonb value. Backward-compatible with the original bool flags.
  static ({
    PaymentProviderMode click,
    PaymentProviderMode payme,
    int minTopUpUzs,
  })
  parsePaymentMethods(dynamic value) {
    if (value is! Map) {
      return (
        click: PaymentProviderMode.enabled,
        payme: PaymentProviderMode.enabled,
        minTopUpUzs: defaultMinWalletTopUp,
      );
    }
    return (
      click: parsePaymentProviderMode(value['click']),
      payme: parsePaymentProviderMode(value['payme']),
      minTopUpUzs: _parseMinTopUpUzs(value['min_topup_uzs']),
    );
  }

  static int _parseMinTopUpUzs(dynamic raw) {
    if (raw is num && raw >= 1000) return raw.toInt();
    return defaultMinWalletTopUp;
  }

  Future<void> _refreshDemoModels(WoodyApiClient api, Box box) async {
    try {
      final body = await api
          .get<Map<String, dynamic>>('/catalog/settings/demo_models')
          .timeout(const Duration(seconds: 6));
      final (:glb, :usdz) = parseDemoModels(body['value']);
      demoGlbUrl = glb;
      demoUsdzUrl = usdz;
      await box.put(_demoGlbUrlHiveKey, glb);
      await box.put(_demoUsdzUrlHiveKey, usdz);
      appLog.info(
        '[remote-config] demo_models glb=${glb.isNotEmpty} usdz=${usdz.isNotEmpty}',
      );
    } on ApiError catch (e, st) {
      if (e.isNotFound) {
        // Not configured server-side yet — blank means "use the bundled asset".
        demoGlbUrl = '';
        demoUsdzUrl = '';
        await box.put(_demoGlbUrlHiveKey, '');
        await box.put(_demoUsdzUrlHiveKey, '');
        return;
      }
      appLog.handle(
        e,
        st,
        '[remote-config] demo_models refresh failed — kept cached value',
      );
    } catch (e, st) {
      appLog.handle(
        e,
        st,
        '[remote-config] demo_models refresh failed — kept cached value',
      );
    }
  }

  /// Extracts `(glb, usdz)` from the `demo_models` jsonb value:
  /// `{"demo_glb_url": ..., "demo_usdz_url": ...}`. Defensive — anything
  /// unexpected reads as blank rather than throwing at boot.
  static ({String glb, String usdz}) parseDemoModels(dynamic value) {
    if (value is! Map) return (glb: '', usdz: '');
    String pick(dynamic v) => v is String ? v.trim() : '';
    return (
      glb: pick(value['demo_glb_url']),
      usdz: pick(value['demo_usdz_url']),
    );
  }
}
