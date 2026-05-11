import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/theme/app_colors.dart';

// Local tokens — kept here so the screen reads top-to-bottom without
// chasing theme indirection. Plus Jakarta Sans is applied to every
// `Text` explicitly via `GoogleFonts.plusJakartaSans` so the surface
// is immune to the M3 surface tint that the teal seller seed otherwise
// bleeds onto neutral backgrounds.
const _ink = Color(0xFF1D1D1D);
const _grey = Color(0xFF757575);
const _greyMid = Color(0xFFBDBDBD);
const _divider = Color(0xFFEFEFEF);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Local UI state — wire to a real preferences store when the
  // settings persistence layer lands.
  bool _darkMode = false;
  bool _newOrders = true;
  bool _customerMessages = true;
  bool _systemAlerts = true;

  String get _languageLabel => "O'zbekcha";

  void _openLanguagePicker() {
    // Language modal lands in a follow-up — leave the row tappable so
    // the affordance is visible to test users today.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: const _SettingsAppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        children: [
          const _SectionLabel(text: 'Tizim'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              _NavRow(
                icon: Iconsax.language_square,
                title: 'Ilova tili',
                trailingText: _languageLabel,
                onTap: _openLanguagePicker,
              ),
              const _RowDivider(),
              _SwitchRow(
                icon: Iconsax.moon,
                title: 'Tungi rejim',
                value: _darkMode,
                onChanged: (v) => setState(() => _darkMode = v),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionLabel(text: 'Bildirishnomalar'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              _SwitchRow(
                icon: Iconsax.shopping_bag,
                title: 'Yangi buyurtmalar',
                subtitle: 'Push xabarlari',
                value: _newOrders,
                onChanged: (v) => setState(() => _newOrders = v),
              ),
              const _RowDivider(),
              _SwitchRow(
                icon: Iconsax.message,
                title: 'Mijoz xabarlari va sharhlar',
                subtitle: 'Push xabarlari',
                value: _customerMessages,
                onChanged: (v) => setState(() => _customerMessages = v),
              ),
              const _RowDivider(),
              _SwitchRow(
                icon: Iconsax.warning_2,
                title: 'Tizim xabarlari',
                subtitle: 'Yangilanishlar va ogohlantirishlar',
                value: _systemAlerts,
                onChanged: (v) => setState(() => _systemAlerts = v),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionLabel(text: 'Boshqa'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              _NavRow(
                icon: Iconsax.trash,
                iconColor: _grey,
                title: 'Keshni tozalash',
                trailingText: '24 MB',
                onTap: () {},
              ),
              const _RowDivider(),
              _NavRow(
                icon: Iconsax.info_circle,
                title: 'Ilova haqida',
                trailingText: 'v1.0.0 (Beta)',
                showChevron: false,
                onTap: () {},
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
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: _ink,
      leading: IconButton(
        icon: const Icon(Iconsax.arrow_left_2, size: 22, color: _ink),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Text(
        'Sozlamalar',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: _ink,
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
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _grey,
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
    return const Padding(
      padding: EdgeInsets.only(left: 60),
      child: Divider(height: 1, thickness: 1, color: _divider),
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
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String? trailingText;
  final VoidCallback onTap;
  final Color? iconColor;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: iconColor ?? _ink),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                    letterSpacing: -0.1,
                    height: 1.25,
                  ),
                ),
              ),
              if (trailingText != null) ...[
                const SizedBox(width: 8),
                Text(
                  trailingText!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _grey,
                    height: 1.2,
                  ),
                ),
              ],
              if (showChevron) ...[
                const SizedBox(width: 8),
                const Icon(Iconsax.arrow_right_3, size: 18, color: _greyMid),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 5. Switch row — leading icon, title + optional subtitle, terracotta switch
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          child: Row(
            children: [
              Icon(icon, size: 22, color: _ink),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                        letterSpacing: -0.1,
                        height: 1.25,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _grey,
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
                activeThumbColor: AppColors.terracotta,
                activeTrackColor: AppColors.terracotta.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
