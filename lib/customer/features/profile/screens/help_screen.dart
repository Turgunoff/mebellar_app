import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/remote_config.dart';
import '../../../../core/auth/auth_cubit.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/network/woody_api_client.dart';
import '../../../../core/storage/hive_boxes.dart';
import '../../../../core/theme/premium_tokens.dart';

// Support channels come from the backend (`app_settings.support_contacts`, via
// RemoteConfig) so the owner can change the email / phone / Telegram from the
// admin panel without shipping a build. RemoteConfig carries non-empty defaults,
// so the launch URLs are always valid even before the first fetch.

const _telegramBlue = Color(0xFF2AABEE);

Future<void> _launch(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  @override
  void initState() {
    super.initState();
    // Boot already fetched these, but an admin edit since then would only land
    // on the next launch — re-fetch on open. Guarded because widget tests pump
    // this screen without the DI scope.
    if (sl.isRegistered<WoodyApiClient>()) {
      unawaited(
        RemoteConfig.instance.refreshSupportContacts(
          sl<WoodyApiClient>(),
          sl<Box>(instanceName: HiveBoxes.settings),
        ),
      );
    }
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
// Quick contact list — one full-width tile per channel showing the channel
// name AND the live contact value (phone number / email / @handle) from
// RemoteConfig, so the user knows exactly where the tap will take them.
// The in-app chat tile appears only when signed in.
// ---------------------------------------------------------------------------

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.loggedIn});

  final bool loggedIn;

  @override
  Widget build(BuildContext context) {
    // RemoteConfig notifies when the boot-time fetch lands new server values,
    // so the tiles swap from cached/default contacts without a screen reopen.
    return ListenableBuilder(
      listenable: RemoteConfig.instance,
      builder: (context, _) => _buildTiles(context),
    );
  }

  Widget _buildTiles(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final config = RemoteConfig.instance;
    return Column(
      children: [
        if (loggedIn) ...[
          _ContactTile(
            icon: const Icon(
              Icons.support_agent,
              size: 22,
              color: Colors.white,
            ),
            iconBackground: PremiumTokens.accent,
            title: tr('profile.help_contact_online_chat'),
            subtitle: tr('profile.help_contact_online_chat_sub'),
            highlighted: true,
            onTap: () => context.push('/support'),
          ),
          const SizedBox(height: 10),
        ],
        _ContactTile(
          icon: Icon(Iconsax.call, size: 20, color: pt.dark),
          iconBackground: pt.dark.withValues(alpha: 0.08),
          title: tr('profile.help_contact_call'),
          subtitle: config.supportPhone,
          onTap: () => _launch(config.supportPhoneUri),
        ),
        const SizedBox(height: 10),
        _ContactTile(
          icon: const FaIcon(
            FontAwesomeIcons.telegram,
            size: 20,
            color: _telegramBlue,
          ),
          iconBackground: _telegramBlue.withValues(alpha: 0.12),
          title: tr('profile.help_contact_telegram'),
          subtitle: config.telegramHandleLabel,
          onTap: () => _launch(config.telegramUrl),
        ),
        const SizedBox(height: 10),
        _ContactTile(
          icon: Icon(Icons.email_outlined, size: 20, color: pt.dark),
          iconBackground: pt.dark.withValues(alpha: 0.08),
          title: tr('profile.help_contact_email'),
          subtitle: config.supportEmail,
          onTap: () => _launch(config.supportEmailUri),
        ),
      ],
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
  });

  /// Pre-built glyph — a [FaIcon] for brand logos, a plain [Icon] otherwise.
  final Widget icon;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// The primary channel (in-app chat) gets an accent border to stand out.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Semantics(
      button: true,
      label: '$title, $subtitle',
      child: Material(
        color: pt.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: highlighted
                    ? PremiumTokens.accent.withValues(alpha: 0.45)
                    : pt.divider,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: icon,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: PremiumTokens.body(
                          size: 14,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PremiumTokens.body(size: 12.5, color: pt.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Iconsax.arrow_right_3_copy, size: 18, color: pt.greyLight),
              ],
            ),
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
