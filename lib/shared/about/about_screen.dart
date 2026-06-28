import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../config/remote_config.dart';
import '../../core/i18n/i18n.dart';
import '../../customer/features/home/widgets/premium/premium_tokens.dart';

Future<PackageInfo>? _packageInfo;

/// Memoised platform lookup so every caller (About screen, seller settings
/// row) shares one channel round-trip per app session.
Future<PackageInfo> appPackageInfo() =>
    _packageInfo ??= PackageInfo.fromPlatform();

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  PackageInfo? _info;

  @override
  void initState() {
    super.initState();
    appPackageInfo().then((info) {
      if (mounted) setState(() => _info = info);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final version = _info == null
        ? ' '
        : tr('about.version_label', namedArgs: {
            'version': _info!.version,
            'build': _info!.buildNumber,
          });
    return Scaffold(
      backgroundColor: pt.background,
      appBar: _buildAppBar(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
        physics: const BouncingScrollPhysics(),
        children: [
          // App identity block
          Center(
            child: Column(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [PremiumTokens.accent, PremiumTokens.accentDeep],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: PremiumTokens.accentDeep.withValues(alpha: 0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Iconsax.shop,
                    size: 44,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Woody',
                  style: PremiumTokens.display(size: 26, letterSpacing: -0.3),
                ),
                const SizedBox(height: 6),
                Text(
                  version,
                  style: PremiumTokens.body(size: 13, color: pt.grey),
                ),
                const SizedBox(height: 16),
                Text(
                  tr('about.tagline'),
                  textAlign: TextAlign.center,
                  style: PremiumTokens.body(
                    size: 14,
                    color: pt.grey,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          // Links card
          Container(
            decoration: BoxDecoration(
              color: pt.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: PremiumTokens.softShadow,
            ),
            child: Column(
              children: [
                _LinkRow(
                  icon: Iconsax.document_text,
                  title: tr('about.terms_of_use'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => StaticContentScreen(
                        title: tr('about.terms_of_use'),
                        type: StaticContentType.terms,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Divider(height: 1, color: pt.divider),
                ),
                _LinkRow(
                  icon: Iconsax.shield_tick,
                  title: tr('about.privacy_policy'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => StaticContentScreen(
                        title: tr('about.privacy_policy'),
                        type: StaticContentType.privacy,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          // Footer
          Center(
            child: Text(
              tr('about.copyright'),
              style: PremiumTokens.body(size: 12, color: pt.greyLight),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
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
        tr('about.title'),
        style: PremiumTokens.body(size: 17, weight: FontWeight.w600),
      ),
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: pt.divider),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Link row
// ---------------------------------------------------------------------------

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
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
              Icon(
                Iconsax.arrow_right_3_copy,
                size: 14,
                color: pt.greyLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Static content screen (Terms / Privacy)
// ---------------------------------------------------------------------------

enum StaticContentType { terms, privacy }

class StaticContentScreen extends StatelessWidget {
  const StaticContentScreen({
    super.key,
    required this.title,
    required this.type,
  });

  final String title;
  final StaticContentType type;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Scaffold(
      backgroundColor: pt.background,
      appBar: AppBar(
        backgroundColor: pt.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            Iconsax.arrow_left_2_copy,
            size: 18,
            color: pt.dark,
          ),
        ),
        title: Text(
          title,
          style: PremiumTokens.body(size: 17, weight: FontWeight.w600),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: pt.divider),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
        physics: const BouncingScrollPhysics(),
        children: [
          Text(
            type == StaticContentType.terms
                ? tr('about.terms_body')
                // The privacy text cites the support email, which is backend-
                // driven (RemoteConfig) — inject it via the `{email}` placeholder.
                : tr(
                    'about.privacy_body',
                    namedArgs: {'email': RemoteConfig.instance.supportEmail},
                  ),
            style: PremiumTokens.body(size: 14, color: pt.grey, height: 1.7),
          ),
        ],
      ),
    );
  }
}
