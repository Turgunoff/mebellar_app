import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../core/theme/app_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/cache/app_cache_cubit.dart';
import '../../../../core/cache/clear_cache_dialog.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/i18n/language_picker.dart';
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

  @override
  void initState() {
    super.initState();
    // Compute the real cache size when the screen opens (shared cubit, so a
    // value computed on the customer side is reused if still fresh).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppCacheCubit>().calculate();
    });
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
          _SectionLabel(text: tr('settings.section_system')),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              _NavRow(
                icon: Iconsax.language_square,
                title: tr('settings.language_row'),
                trailingText: languageLabel,
                onTap: () => showLanguagePicker(context),
              ),
              const _RowDivider(),
              _NavRow(
                icon: Iconsax.moon,
                title: tr('settings.theme'),
                trailingText: themeModeLabel(themeMode),
                onTap: () => showThemeModePicker(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionLabel(text: tr('settings.section_notifications')),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              _SwitchRow(
                icon: Iconsax.shopping_bag,
                title: tr('settings.new_orders'),
                subtitle: tr('settings.push_messages'),
                value: _newOrders,
                onChanged: (v) => setState(() => _newOrders = v),
              ),
              const _RowDivider(),
              _SwitchRow(
                icon: Iconsax.message,
                title: tr('settings.customer_messages'),
                subtitle: tr('settings.push_messages'),
                value: _customerMessages,
                onChanged: (v) => setState(() => _customerMessages = v),
              ),
              const _RowDivider(),
              _SwitchRow(
                icon: Iconsax.warning_2,
                title: tr('settings.system_alerts'),
                subtitle: tr('settings.system_alerts_subtitle'),
                value: _systemAlerts,
                onChanged: (v) => setState(() => _systemAlerts = v),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionLabel(text: tr('settings.section_other')),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              BlocBuilder<AppCacheCubit, AppCacheState>(
                builder: (context, cache) => _NavRow(
                  icon: Iconsax.trash,
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
                  icon: Iconsax.info_circle,
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
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: c.grey,
          letterSpacing: 0.4,
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
      padding: const EdgeInsets.only(left: 60),
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
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: iconColor ?? c.ink),
              const SizedBox(width: 16),
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
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          child: Row(
            children: [
              Icon(icon, size: 22, color: c.ink),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
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
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeThumbColor: AppColors.sellerPrimary,
                activeTrackColor: AppColors.sellerPrimary.withValues(
                  alpha: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
