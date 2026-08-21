import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../core/theme/app_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/analytics/analytics_privacy.dart';
import '../../../../core/cache/app_cache_cubit.dart';
import '../../../../core/cache/clear_cache_dialog.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/i18n/language_picker.dart';
import '../../../../core/storage/hive_boxes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../../core/theme/theme_mode_picker.dart';
import '../../../../shared/about/about_screen.dart';

// All neutral colours now come from `SellerColors.of(context)` so the surface
// flips with the theme. Plus Jakarta Sans is applied to every `Text` explicitly
// via `AppFonts.seller` so the surface is immune to the M3 surface tint that the
// seller seed otherwise bleeds onto neutral backgrounds.

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Local UI state — wire to a real preferences store when the
  // settings persistence layer lands. (Dark mode now comes from the global
  // ThemeCubit instead of a local flag.)
  bool _newOrders = true;
  bool _customerMessages = true;
  bool _systemAlerts = true;
  // Persisted across launches via Hive (settings box) and shared with the
  // customer screen — the same key drives Analytics + Crashlytics in both
  // modes, so a seller who opts out stays opted out after a mode swap.
  bool _analyticsEnabled = true;

  Box get _settingsBox => sl<Box>(instanceName: HiveBoxes.settings);

  @override
  void initState() {
    super.initState();
    _hydrateAnalytics();
    // Compute the real cache size when the screen opens (shared cubit, so a
    // value computed on the customer side is reused if still fresh).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppCacheCubit>().calculate();
    });
  }

  Future<void> _hydrateAnalytics() async {
    final stored = readAnalyticsCollectionEnabled(_settingsBox);
    if (!mounted) return;
    setState(() => _analyticsEnabled = stored);
    // Re-assert the SDK state in case boot skipped apply (e.g. a hot-restart
    // path that remounts Settings without re-running main).
    await applyAnalyticsCollectionEnabled(stored);
  }

  Future<void> _setAnalyticsEnabled(bool value) async {
    setState(() => _analyticsEnabled = value);
    await _settingsBox.put(kAnalyticsCollectionEnabledKey, value);
    await applyAnalyticsCollectionEnabled(value);
  }

  /// Same copy as the customer screen (shared `settings.analytics_*` keys),
  /// rendered with seller tokens so it matches the indigo surface.
  void _showAnalyticsInfo(BuildContext context) {
    final c = SellerColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.paddingOf(ctx).bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Iconsax.chart_2_copy,
                      size: 22,
                      color: c.onPrimarySoft,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tr('settings.analytics_usage'),
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                tr('settings.analytics_intro'),
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: c.grey,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                tr('settings.analytics_collected_label'),
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.ink,
                ),
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
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Iconsax.shield_tick_copy,
                      size: 18,
                      color: c.onPrimarySoft,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tr('settings.analytics_privacy_note'),
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: c.ink,
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
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute<void>(
                              builder: (_) => StaticContentScreen(
                                title: tr('settings.privacy_policy'),
                                type: StaticContentType.privacy,
                              ),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: c.divider),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          tr('settings.privacy_policy'),
                          style: TextStyle(
                            fontFamily: AppFonts.seller,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: c.ink,
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
                          backgroundColor: c.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          tr('settings.understood'),
                          style: TextStyle(
                            fontFamily: AppFonts.seller,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    // Native name of the active language for the trailing label; rebuilds with
    // the rest of the tree when the locale changes.
    final languageLabel = tr('lang.${context.locale.languageCode}');
    // Theme is global — read the active preference (System / Light / Dark)
    // from the shared ThemeCubit; `watch` rebuilds the trailing label on change.
    final themeMode = context.watch<ThemeCubit>().state.themeMode;
    return Scaffold(
      backgroundColor: c.background,
      appBar: const _SettingsAppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        children: [
          _SectionLabel(text: tr('settings.section_appearance')),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              _NavRow(
                icon: Iconsax.language_square_copy,
                title: tr('settings.language_row'),
                trailingText: languageLabel,
                onTap: () => showLanguagePicker(context),
              ),
              const _RowDivider(),
              _NavRow(
                icon: Iconsax.moon_copy,
                title: tr('settings.theme'),
                trailingText: themeModeLabel(themeMode),
                onTap: () => showThemeModePicker(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionLabel(text: tr('settings.section_notifications')),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              _SwitchRow(
                icon: Iconsax.shopping_bag_copy,
                title: tr('settings.new_orders'),
                subtitle: tr('settings.push_messages'),
                value: _newOrders,
                onChanged: (v) => setState(() => _newOrders = v),
              ),
              const _RowDivider(),
              _SwitchRow(
                icon: Iconsax.message_copy,
                title: tr('settings.customer_messages'),
                subtitle: tr('settings.push_messages'),
                value: _customerMessages,
                onChanged: (v) => setState(() => _customerMessages = v),
              ),
              const _RowDivider(),
              _SwitchRow(
                icon: Iconsax.warning_2_copy,
                title: tr('settings.system_alerts'),
                subtitle: tr('settings.system_alerts_subtitle'),
                value: _systemAlerts,
                onChanged: (v) => setState(() => _systemAlerts = v),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionLabel(text: tr('settings.section_privacy')),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              _SwitchRow(
                icon: Iconsax.chart_2_copy,
                title: tr('settings.analytics_usage'),
                subtitle: tr('settings.analytics_subtitle'),
                value: _analyticsEnabled,
                onChanged: _setAnalyticsEnabled,
                onInfoTap: () => _showAnalyticsInfo(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionLabel(text: tr('settings.section_other')),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              BlocBuilder<AppCacheCubit, AppCacheState>(
                builder: (context, cache) => _NavRow(
                  icon: Iconsax.trash_copy,
                  iconColor: c.grey,
                  title: tr('settings.clear_cache'),
                  trailingText: cache.isBusy
                      ? tr('settings.calculating')
                      : (cache.sizeLabel ?? tr('settings.calculating')),
                  onTap: cache.isBusy
                      ? () {}
                      : () => confirmAndClearCache(context),
                ),
              ),
              const _RowDivider(),
              FutureBuilder<PackageInfo>(
                future: appPackageInfo(),
                builder: (context, snap) => _NavRow(
                  icon: Iconsax.info_circle_copy,
                  title: tr('settings.about'),
                  trailingText: snap.hasData
                      ? 'v${snap.data!.version} (${snap.data!.buildNumber})'
                      : null,
                  // Root navigator so the About page covers the seller tab
                  // bar — it is a full-screen detail, not a tab-scoped view.
                  onTap: () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AboutScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 1. App bar — clean white, bold title
// =============================================================================
class _SettingsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _SettingsAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return AppBar(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: c.ink,
      leading: IconButton(
        icon: Icon(Iconsax.arrow_left_2_copy, size: 22, color: c.ink),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Text(
        tr('settings.title'),
        style: TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: c.ink,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

// =============================================================================
// 2. Section label — small all-caps style above each grouped card
// =============================================================================
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          // `greyMid` is the seller twin of the customer label tone (#BDBDBD
          // light) — `grey` reads as body text at this size.
          color: c.greyMid,
          letterSpacing: 0.8,
          height: 1.2,
        ),
      ),
    );
  }
}

// =============================================================================
// 3. Grouped settings card — pure white, soft shadow, hairline dividers
// =============================================================================
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: children),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Divider(height: 1, thickness: 1, color: c.divider),
    );
  }
}

// =============================================================================
// 4. Nav row — leading icon, title, trailing text + optional chevron
// =============================================================================
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailingText,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? trailingText;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 15, 14, 15),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: c.imageBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 17, color: iconColor ?? c.ink),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                    letterSpacing: -0.1,
                    height: 1.25,
                  ),
                ),
              ),
              if (trailingText != null) ...[
                const SizedBox(width: 8),
                Text(
                  trailingText!,
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: c.grey,
                    height: 1.2,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Icon(Iconsax.arrow_right_3_copy, size: 18, color: c.greyMid),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 5. Switch row — leading icon, title + optional subtitle, indigo switch
// =============================================================================
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
  final ValueChanged<bool> onChanged;
  final VoidCallback? onInfoTap;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: c.imageBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 17, color: c.ink),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontFamily: AppFonts.seller,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: c.ink,
                              letterSpacing: -0.1,
                              height: 1.25,
                            ),
                          ),
                        ),
                        if (onInfoTap != null) ...[
                          const SizedBox(width: 6),
                          InkResponse(
                            onTap: onInfoTap,
                            radius: 14,
                            child: Icon(
                              Iconsax.info_circle_copy,
                              size: 16,
                              color: c.greyMid,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: c.grey,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              CupertinoSwitch(
                value: value,
                onChanged: onChanged,
                activeTrackColor: AppColors.sellerPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 6. Info bullet — used by the analytics explainer sheet
// =============================================================================
class _InfoBullet extends StatelessWidget {
  const _InfoBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
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
                color: c.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: c.ink,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
