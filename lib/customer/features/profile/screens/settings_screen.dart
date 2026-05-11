import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/i18n/app_locale_controller.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../../main.dart' show AppLocaleScope;
import '../../home/widgets/premium/premium_tokens.dart';

const _languages = [
  (code: 'uz', label: "O'zbekcha"),
  (code: 'ru', label: 'Русский'),
  (code: 'en', label: 'English'),
];

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _orderUpdates = true;
  bool _promotions = false;

  bool get _isLoggedIn =>
      Supabase.instance.client.auth.currentSession != null;

  String _localeName(String code) =>
      _languages.firstWhere((l) => l.code == code, orElse: () => _languages.first).label;

  Future<void> _pickLanguage(AppLocaleController controller) async {
    final pt = PremiumTokens.of(context);
    final current = controller.value.languageCode;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: pt.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: pt.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Ilova tili',
                  style: PremiumTokens.body(
                    size: 15,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            ..._languages.map((lang) => ListTile(
                  title: Text(
                    lang.label,
                    style: PremiumTokens.body(
                      size: 14,
                      weight: lang.code == current
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: lang.code == current
                          ? PremiumTokens.accent
                          : pt.dark,
                    ),
                  ),
                  trailing: lang.code == current
                      ? const Icon(Icons.check_rounded,
                          color: PremiumTokens.accent, size: 20)
                      : null,
                  onTap: () async {
                    await controller.setLocale(Locale(lang.code));
                    if (mounted) Navigator.of(context).pop();
                  },
                )),
            const SizedBox(height: 8),
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
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: pt.dark,
        ),
      ),
      title: Text(
        'Sozlamalar',
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
    return Scaffold(
      backgroundColor: pt.background,
      appBar: _buildAppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        physics: const BouncingScrollPhysics(),
        children: [
          if (_isLoggedIn) ...[
            const _SectionLabel('Profil'),
            const SizedBox(height: 8),
            _Card(
              children: [
                _NavRow(
                  icon: Iconsax.edit_2,
                  title: 'Profilni yangilash',
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
          const _SectionLabel('Til'),
          const SizedBox(height: 8),
          Builder(builder: (ctx) {
            final controller = AppLocaleScope.of(ctx);
            return ValueListenableBuilder<Locale>(
              valueListenable: controller,
              builder: (_, locale, _) => _Card(
                children: [
                  _NavRow(
                    icon: Iconsax.language_square,
                    title: 'Ilova tili',
                    trailingLabel: _localeName(locale.languageCode),
                    onTap: () => _pickLanguage(controller),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          const _SectionLabel('Bildirishnomalar'),
          const SizedBox(height: 8),
          _Card(
            children: [
              _SwitchRow(
                icon: Iconsax.notification,
                title: 'Push bildirishnomalar',
                value: _pushNotifications,
                onChanged: (v) => setState(() => _pushNotifications = v),
              ),
              const _RowDivider(),
              _SwitchRow(
                icon: Iconsax.box,
                title: 'Buyurtma yangilanishlari',
                value: _orderUpdates,
                onChanged: (v) => setState(() => _orderUpdates = v),
              ),
              const _RowDivider(),
              _SwitchRow(
                icon: Iconsax.discount_shape,
                title: 'Aksiyalar va takliflar',
                value: _promotions,
                onChanged: (v) => setState(() => _promotions = v),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionLabel("Ko'rinish"),
          const SizedBox(height: 8),
          BlocBuilder<ThemeCubit, ThemeState>(
            builder: (context, themeState) => _Card(
              children: [
                _SwitchRow(
                  icon: Iconsax.moon,
                  title: "Qorong'i rejim",
                  value: themeState.themeMode == ThemeMode.dark,
                  onChanged: (v) => context.read<ThemeCubit>().setDark(v),
                ),
              ],
            ),
          ),
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
              if (trailingLabel != null)
                Text(
                  trailingLabel!,
                  style: PremiumTokens.body(
                    size: 13,
                    color: PremiumTokens.accent,
                    weight: FontWeight.w500,
                  ),
                ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: pt.greyLight,
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
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

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
            child: Text(
              title,
              style: PremiumTokens.body(size: 14, weight: FontWeight.w500),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: PremiumTokens.accent,
          ),
        ],
      ),
    );
  }
}
