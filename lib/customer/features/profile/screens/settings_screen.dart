import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/analytics/analytics_privacy.dart';
import '../../../../core/auth/auth_cubit.dart';
import '../../../../core/auth/auth_repository.dart';
import '../../../../core/cache/app_cache_cubit.dart';
import '../../../../core/cache/clear_cache_dialog.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/i18n/language_picker.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/network/woody_api_client.dart';
import '../../../../core/notifications/push_service.dart';
import '../../../../core/storage/hive_boxes.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../../core/theme/theme_mode_picker.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../../../shared/about/about_screen.dart';
import '../widgets/account_dialogs.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.authRepository,
    this.pushService,
  });

  final AuthRepository authRepository;

  /// Optional — not every scope registers it; callers treat a null the same
  /// as the old `sl.isRegistered<PushService>()` guard.
  final PushService? pushService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _orderUpdates = true;
  bool _orderUpdatesBusy = false;
  // Persisted across launches via Hive (settings box). Hydrate once at
  // open and write through on every toggle.
  bool _analyticsEnabled = true;

  Box get _settingsBox => sl<Box>(instanceName: HiveBoxes.settings);

  @override
  void initState() {
    super.initState();
    _hydrate();
    // Compute the real cache size when the screen opens (shared cubit).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppCacheCubit>().calculate();
    });
  }

  Future<void> _hydrate() async {
    final box = _settingsBox;
    final storedAnalytics = readAnalyticsCollectionEnabled(box);
    final storedPromo = box.get(kPromoPushEnabledKey);
    final storedOrder = box.get(kOrderPushEnabledKey);

    if (!mounted) return;
    setState(() {
      _analyticsEnabled = storedAnalytics;
      if (storedPromo is bool) _pushNotifications = storedPromo;
      if (storedOrder is bool) _orderUpdates = storedOrder;
    });
    // Re-assert the SDK state in case boot somehow skipped apply (e.g. a
    // hot-restart path that remounts Settings without re-running main).
    await applyAnalyticsCollectionEnabled(storedAnalytics);

    // Server is source of truth when signed in — refresh Hive + topic state.
    if (!mounted) return;
    if (context.read<AuthCubit>().state is! AppAuthAuthenticated) return;
    try {
      final me = await widget.authRepository.fetchMe();
      if (!mounted) return;
      setState(() {
        _pushNotifications = me.promoPushEnabled;
        _orderUpdates = me.orderPushEnabled;
      });
      await box.put(kPromoPushEnabledKey, me.promoPushEnabled);
      await box.put(kOrderPushEnabledKey, me.orderPushEnabled);
      await widget.pushService?.setPromoTopicEnabled(me.promoPushEnabled);
    } catch (e, st) {
      appLog.handle(e, st, 'SettingsScreen hydrate push prefs failed');
    }
  }

  Future<void> _setAnalyticsEnabled(bool value) async {
    setState(() => _analyticsEnabled = value);
    await _settingsBox.put(kAnalyticsCollectionEnabledKey, value);
    await applyAnalyticsCollectionEnabled(value);
  }

  Future<void> _setPromoPushEnabled(bool value) async {
    setState(() => _pushNotifications = value);
    await _settingsBox.put(kPromoPushEnabledKey, value);
    await widget.pushService?.setPromoTopicEnabled(value);
    if (!mounted) return;
    if (context.read<AuthCubit>().state is! AppAuthAuthenticated) return;
    try {
      await widget.authRepository.updateProfile(promoPushEnabled: value);
    } catch (e, st) {
      appLog.handle(e, st, 'SettingsScreen sync promo_push_enabled failed');
    }
  }

  Future<void> _setOrderUpdatesEnabled(bool value) async {
    if (_orderUpdatesBusy) return;
    final previous = _orderUpdates;
    setState(() {
      _orderUpdates = value;
      _orderUpdatesBusy = true;
    });
    await _settingsBox.put(kOrderPushEnabledKey, value);

    if (!mounted) return;
    if (context.read<AuthCubit>().state is! AppAuthAuthenticated) {
      setState(() => _orderUpdatesBusy = false);
      return;
    }
    try {
      await widget.authRepository.updateProfile(orderPushEnabled: value);
      if (mounted) setState(() => _orderUpdatesBusy = false);
    } catch (e, st) {
      appLog.handle(e, st, 'SettingsScreen sync order_push_enabled failed');
      await _settingsBox.put(kOrderPushEnabledKey, previous);
      if (mounted) {
        setState(() {
          _orderUpdates = previous;
          _orderUpdatesBusy = false;
        });
      }
    }
  }

  void _showAnalyticsInfo(BuildContext context) {
    final pt = PremiumTokens.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: pt.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          MediaQuery.paddingOf(ctx).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          // Theme already draws the drag handle (`showDragHandle: true` in
          // app_theme.dart) — don't add a second bar here or the sheet shows
          // two stacked dashes.
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: PremiumTokens.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Iconsax.chart_2,
                    size: 22,
                    color: PremiumTokens.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tr('settings.analytics_usage'),
                    style: PremiumTokens.display(size: 18, letterSpacing: -0.2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              tr('settings.analytics_intro'),
              style: PremiumTokens.body(size: 14, color: pt.grey, height: 1.55),
            ),
            const SizedBox(height: 20),
            Text(
              tr('settings.analytics_collected_label'),
              style: PremiumTokens.body(size: 13, weight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            _InfoBullet(text: tr('settings.analytics_b1')),
            _InfoBullet(text: tr('settings.analytics_b2')),
            _InfoBullet(text: tr('settings.analytics_b3')),
            _InfoBullet(text: tr('settings.analytics_b4')),
            _InfoBullet(text: tr('settings.analytics_b5')),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: PremiumTokens.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Iconsax.shield_tick,
                    size: 18,
                    color: PremiumTokens.accent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tr('settings.analytics_privacy_note'),
                      style: PremiumTokens.body(
                        size: 12.5,
                        color: pt.dark,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => StaticContentScreen(
                              title: tr('settings.privacy_policy'),
                              type: StaticContentType.privacy,
                            ),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: pt.divider),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        tr('settings.privacy_policy'),
                        style: PremiumTokens.body(
                          size: 13.5,
                          weight: FontWeight.w600,
                          color: pt.dark,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: PremiumTokens.accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        tr('settings.understood'),
                        style: PremiumTokens.body(
                          size: 14,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final pt = PremiumTokens.of(context);
    return AppBar(
      backgroundColor: pt.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: Icon(Iconsax.arrow_left_2_copy, size: 18, color: pt.dark),
      ),
      title: Text(
        tr('settings.title'),
        style: PremiumTokens.body(size: 17, weight: FontWeight.w600),
      ),
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: pt.divider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    // The active theme preference (System / Light / Dark) drives the trailing
    // label on the appearance row; `watch` rebuilds it when the choice changes.
    final themeMode = context.watch<ThemeCubit>().state.themeMode;
    final languageLabel = tr('lang.${context.locale.languageCode}');
    final isAuthenticated =
        context.watch<AuthCubit>().state is AppAuthAuthenticated;
    return Scaffold(
      backgroundColor: pt.background,
      appBar: _buildAppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        physics: const BouncingScrollPhysics(),
        children: [
          _SectionLabel(tr('settings.section_appearance')),
          const SizedBox(height: 8),
          _Card(
            children: [
              _NavRow(
                icon: Iconsax.language_square,
                title: tr('settings.language_row'),
                trailingLabel: languageLabel,
                onTap: () => showLanguagePicker(context),
              ),
              const _RowDivider(),
              _NavRow(
                icon: Iconsax.moon,
                title: tr('settings.theme'),
                trailingLabel: themeModeLabel(themeMode),
                onTap: () => showThemeModePicker(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionLabel(tr('settings.section_notifications')),
          const SizedBox(height: 8),
          _Card(
            children: [
              _SwitchRow(
                icon: Iconsax.notification,
                title: tr('settings.push_notifications'),
                value: _pushNotifications,
                onChanged: _setPromoPushEnabled,
              ),
              const _RowDivider(),
              _SwitchRow(
                icon: Iconsax.box,
                title: tr('settings.order_updates'),
                value: _orderUpdates,
                onChanged: _orderUpdatesBusy ? null : _setOrderUpdatesEnabled,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionLabel(tr('settings.section_privacy')),
          const SizedBox(height: 8),
          _Card(
            children: [
              _SwitchRow(
                icon: Iconsax.chart_2,
                title: tr('settings.analytics_usage'),
                subtitle: tr('settings.analytics_subtitle'),
                value: _analyticsEnabled,
                onChanged: _setAnalyticsEnabled,
                onInfoTap: () => _showAnalyticsInfo(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionLabel(tr('settings.section_storage')),
          const SizedBox(height: 8),
          _Card(
            children: [
              BlocBuilder<AppCacheCubit, AppCacheState>(
                builder: (context, cache) => _NavRow(
                  icon: Iconsax.trash,
                  title: tr('settings.clear_cache'),
                  trailingLabel: cache.isBusy
                      ? tr('settings.calculating')
                      : (cache.sizeLabel ?? tr('settings.calculating')),
                  onTap: () {
                    if (!cache.isBusy) confirmAndClearCache(context);
                  },
                ),
              ),
            ],
          ),
          if (isAuthenticated) ...[
            const SizedBox(height: 24),
            _SectionLabel(tr('settings.section_account')),
            const SizedBox(height: 8),
            _Card(
              children: [
                _DangerNavRow(
                  icon: Iconsax.trash,
                  title: tr('profile.delete_account_title'),
                  onTap: () => confirmAccountDeletion(
                    context,
                    authRepository: widget.authRepository,
                    api: sl<WoodyApiClient>(),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared components
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        text.toUpperCase(),
        style: PremiumTokens.body(
          size: 11,
          weight: FontWeight.w600,
          color: pt.greyLight,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: PremiumTokens.softShadow,
      ),
      child: Column(children: children),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Divider(height: 1, color: pt.divider),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    this.trailingLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? trailingLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 15, 14, 15),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: pt.imageBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 17, color: pt.dark),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: PremiumTokens.body(size: 14, weight: FontWeight.w500),
                ),
              ),
              if (trailingLabel != null) ...[
                Text(
                  trailingLabel!,
                  style: PremiumTokens.body(
                    size: 13,
                    color: PremiumTokens.accent,
                    weight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Iconsax.arrow_right_3_copy, size: 18, color: pt.greyLight),
              ] else
                Icon(Iconsax.arrow_right_3_copy, size: 18, color: pt.greyLight),
            ],
          ),
        ),
      ),
    );
  }
}

class _DangerNavRow extends StatelessWidget {
  const _DangerNavRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final danger = Theme.of(context).colorScheme.error;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 15, 14, 15),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: danger.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 17, color: danger),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: PremiumTokens.body(
                    size: 14,
                    weight: FontWeight.w500,
                    color: danger,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.onInfoTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onInfoTap;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: pt.imageBg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 17, color: pt.dark),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: PremiumTokens.body(
                          size: 14,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (onInfoTap != null) ...[
                      const SizedBox(width: 6),
                      InkResponse(
                        onTap: onInfoTap,
                        radius: 14,
                        child: Icon(
                          Iconsax.info_circle,
                          size: 16,
                          color: pt.greyLight,
                        ),
                      ),
                    ],
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: PremiumTokens.body(size: 12, color: pt.grey),
                  ),
                ],
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: PremiumTokens.accent,
          ),
        ],
      ),
    );
  }
}

class _InfoBullet extends StatelessWidget {
  const _InfoBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: PremiumTokens.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: PremiumTokens.body(
                size: 13.5,
                color: pt.dark,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
