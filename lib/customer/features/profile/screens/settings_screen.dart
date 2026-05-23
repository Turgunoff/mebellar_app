import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/storage/hive_boxes.dart';
import '../../home/widgets/premium/premium_tokens.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _orderUpdates = true;
  // Persisted across launches via Hive (settings box). Hydrate once at
  // open and write through on every toggle.
  bool _analyticsEnabled = true;

  static const _analyticsBoxKey = 'analytics_collection_enabled';

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    final box = sl<Box>(instanceName: HiveBoxes.settings);
    final stored = box.get(_analyticsBoxKey);
    if (stored is bool && stored != _analyticsEnabled && mounted) {
      setState(() => _analyticsEnabled = stored);
      await sl<AnalyticsService>().setAnalyticsEnabled(stored);
    }
  }

  Future<void> _setAnalyticsEnabled(bool value) async {
    setState(() => _analyticsEnabled = value);
    final box = sl<Box>(instanceName: HiveBoxes.settings);
    await box.put(_analyticsBoxKey, value);
    await sl<AnalyticsService>().setAnalyticsEnabled(value);
  }

  void _showComingSoon(BuildContext context, String feature) {
    final pt = PremiumTokens.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: pt.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
          28,
          0,
          28,
          MediaQuery.paddingOf(ctx).bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 28),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: pt.divider,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: PremiumTokens.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.hourglass_top_rounded,
                size: 30,
                color: PremiumTokens.accent,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              feature,
              style: PremiumTokens.display(size: 20, letterSpacing: -0.3),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              "Ushbu funksiya keyingi versiyada qo'shiladi.\nBiz bilan qoling!",
              textAlign: TextAlign.center,
              style: PremiumTokens.body(
                size: 14,
                color: pt.grey,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: PremiumTokens.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Tushunarli',
                  style: PremiumTokens.body(
                    size: 15,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
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
          const _SectionLabel('Til'),
          const SizedBox(height: 8),
          _Card(
            children: [
              _NavRow(
                icon: Iconsax.language_square,
                title: 'Ilova tili',
                trailingLabel: "O'zbekcha",
                onTap: () => _showComingSoon(context, 'Ilova tili'),
              ),
            ],
          ),
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
            ],
          ),
          const SizedBox(height: 24),
          const _SectionLabel("Ko'rinish"),
          const SizedBox(height: 8),
          _Card(
            children: [
              _NavRow(
                icon: Iconsax.moon,
                title: "Qorong'i rejim",
                trailingWidget: const _ComingSoonBadge(),
                onTap: () => _showComingSoon(context, "Qorong'i rejim"),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Maxfiylik'),
          const SizedBox(height: 8),
          _Card(
            children: [
              _SwitchRow(
                icon: Iconsax.chart_2,
                title: "Foydalanish statistikasi",
                subtitle:
                    "Anonim event'lar ilovani yaxshilashga yordam beradi",
                value: _analyticsEnabled,
                onChanged: _setAnalyticsEnabled,
              ),
            ],
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
    this.trailingWidget,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? trailingLabel;
  final Widget? trailingWidget;
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
              if (trailingWidget != null)
                trailingWidget!
              else if (trailingLabel != null) ...[
                Text(
                  trailingLabel!,
                  style: PremiumTokens.body(
                    size: 13,
                    color: PremiumTokens.accent,
                    weight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right, size: 18, color: pt.greyLight),
              ] else
                Icon(Icons.chevron_right, size: 18, color: pt.greyLight),
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
  });

  final IconData icon;
  final String title;
  final String? subtitle;
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: PremiumTokens.body(size: 14, weight: FontWeight.w500),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: PremiumTokens.body(
                      size: 12,
                      color: pt.grey,
                    ),
                  ),
                ],
              ],
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

class _ComingSoonBadge extends StatelessWidget {
  const _ComingSoonBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: PremiumTokens.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Tez orada',
        style: PremiumTokens.body(
          size: 11,
          weight: FontWeight.w600,
          color: PremiumTokens.accent,
        ),
      ),
    );
  }
}
