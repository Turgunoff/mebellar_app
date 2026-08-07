import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/remote_config.dart';
import '../../../../core/auth/auth_cubit.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/theme/premium_tokens.dart';

// Support channels come from the backend (`app_settings.support_contacts`, via
// RemoteConfig) so the owner can change the email / phone / Telegram from the
// admin panel without shipping a build. RemoteConfig carries non-empty defaults,
// so the launch URLs are always valid even before the first fetch.

const _telegramBlue = Color(0xFF2AABEE);
const _whatsappGreen = Color(0xFF25D366);

Future<void> _launch(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

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
        tr('profile.help_title'),
        style: PremiumTokens.body(size: 16, weight: FontWeight.w600),
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
      appBar: _buildAppBar(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        physics: const BouncingScrollPhysics(),
        children: [
          // ---- Quick contact row (top) -------------------------------------
          _SectionLabel(tr('profile.help_contact_section')),
          const SizedBox(height: 14),
          BlocBuilder<AuthCubit, AppAuthState>(
            builder: (context, state) =>
                _ContactRow(loggedIn: state is AppAuthAuthenticated),
          ),
          const SizedBox(height: 28),
          // ---- Categorised FAQ ---------------------------------------------
          _SectionLabel(tr('profile.help_faq_section')),
          const SizedBox(height: 12),
          _FaqSection(
            title: tr('profile.help_faq_general_title'),
            icon: Iconsax.info_circle,
            items: [
              _FaqItem(
                question: tr('profile.help_faq_delivery_time_q'),
                answer: tr('profile.help_faq_delivery_time_a'),
              ),
              _FaqItem(
                question: tr('profile.help_faq_delivery_price_q'),
                answer: tr('profile.help_faq_delivery_price_a'),
              ),
              _FaqItem(
                question: tr('profile.help_faq_payment_methods_q'),
                answer: tr('profile.help_faq_payment_methods_a'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _FaqSection(
            title: tr('profile.help_faq_buyers_title'),
            icon: Iconsax.bag_2,
            items: [
              _FaqItem(
                question: tr('profile.help_faq_cancel_q'),
                answer: tr('profile.help_faq_cancel_a'),
              ),
              _FaqItem(
                question: tr('profile.help_faq_track_q'),
                answer: tr('profile.help_faq_track_a'),
              ),
              _FaqItem(
                question: tr('profile.help_faq_refund_q'),
                answer: tr('profile.help_faq_refund_a'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _FaqSection(
            title: tr('profile.help_faq_sellers_title'),
            icon: Iconsax.shop,
            items: [
              _FaqItem(
                question: tr('profile.help_faq_become_seller_q'),
                answer: tr('profile.help_faq_become_seller_a'),
              ),
              _FaqItem(
                question: tr('profile.help_faq_seller_reqs_q'),
                answer: tr('profile.help_faq_seller_reqs_a'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick contact row — circular brand icon buttons, labels dropped (the glyphs
// are universally recognised). The in-app chat icon appears only when signed in.
// ---------------------------------------------------------------------------

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.loggedIn});

  final bool loggedIn;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final config = RemoteConfig.instance;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _QuickContact(
          icon: Icon(Icons.email_outlined, size: 24, color: pt.dark),
          tint: pt.dark,
          label: 'Email',
          onTap: () => _launch(config.supportEmailUri),
        ),
        _QuickContact(
          icon: const FaIcon(
            FontAwesomeIcons.telegram,
            size: 22,
            color: _telegramBlue,
          ),
          tint: _telegramBlue,
          label: 'Telegram',
          onTap: () => _launch(config.telegramUrl),
        ),
        _QuickContact(
          icon: const FaIcon(
            FontAwesomeIcons.whatsapp,
            size: 22,
            color: _whatsappGreen,
          ),
          tint: _whatsappGreen,
          label: 'WhatsApp',
          onTap: () => _launch(config.whatsappUri),
        ),
        if (loggedIn)
          _QuickContact(
            icon: const Icon(
              Icons.support_agent,
              size: 24,
              color: PremiumTokens.accent,
            ),
            tint: PremiumTokens.accent,
            label: tr('profile.help_contact_online_chat'),
            onTap: () => context.push('/support'),
          ),
      ],
    );
  }
}

class _QuickContact extends StatelessWidget {
  const _QuickContact({
    required this.icon,
    required this.tint,
    required this.label,
    required this.onTap,
  });

  /// Pre-built glyph — a [FaIcon] for brand logos, a plain [Icon] otherwise.
  final Widget icon;

  /// Circle fill colour (the glyph colour at low opacity).
  final Color tint;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: tint.withValues(alpha: 0.12),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(width: 58, height: 58, child: Center(child: icon)),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FAQ section — a card with a bold header and compact expansion tiles.
// ---------------------------------------------------------------------------

class _FaqItem {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;
}

class _FaqSection extends StatelessWidget {
  const _FaqSection({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<_FaqItem> items;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: PremiumTokens.softShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: pt.imageBg,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: 15, color: PremiumTokens.accent),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: PremiumTokens.body(
                      size: 14,
                      weight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < items.length; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(height: 1, color: pt.divider),
              ),
              _CompactFaqTile(item: items[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompactFaqTile extends StatelessWidget {
  const _CompactFaqTile({required this.item});

  final _FaqItem item;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: PremiumTokens.accent.withValues(alpha: 0.06),
      ),
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          visualDensity: VisualDensity.compact,
          minTileHeight: 46,
          tilePadding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          iconColor: PremiumTokens.accent,
          collapsedIconColor: pt.greyLight,
          title: Text(
            item.question,
            style: PremiumTokens.body(size: 13, weight: FontWeight.w500),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                item.answer,
                style: PremiumTokens.body(
                  size: 13,
                  color: pt.grey,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section label
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
