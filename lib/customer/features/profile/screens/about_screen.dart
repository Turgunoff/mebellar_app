import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../home/widgets/premium/premium_tokens.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _version = '1.0.0';
  static const _termsUrl = 'https://mebellar.uz/terms';
  static const _privacyUrl = 'https://mebellar.uz/privacy';

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
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
                  'Mebellar Olami',
                  style: PremiumTokens.display(size: 26, letterSpacing: -0.3),
                ),
                const SizedBox(height: 6),
                Text(
                  'Versiya $_version',
                  style: PremiumTokens.body(
                    size: 13,
                    color: pt.grey,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "O'zbekistonning eng yirik mebel bozori. "
                  "Minglab mebel mahsulotlarini qulay narxlarda "
                  "topib, bir necha daqiqada buyurtma bering.",
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
                  title: 'Foydalanish shartlari',
                  onTap: () => _launch(_termsUrl),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Divider(height: 1, color: pt.divider),
                ),
                _LinkRow(
                  icon: Iconsax.shield_tick,
                  title: 'Maxfiylik siyosati',
                  onTap: () => _launch(_privacyUrl),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          // Footer
          Center(
            child: Text(
              '© 2025 Mebellar Olami',
              style: PremiumTokens.body(
                size: 12,
                color: pt.greyLight,
              ),
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
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: pt.dark,
        ),
      ),
      title: Text(
        'Ilova haqida',
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
                  style: PremiumTokens.body(
                    size: 14,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
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
