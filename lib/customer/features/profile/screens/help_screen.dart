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
          // ---- Contact block (top) -----------------------------------------
          // No section label here: the staffed-hours strip already titles the
          // block, and a second all-caps label above it read as noise.
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
// Contact block — a staffed-hours strip, the in-app chat CTA (signed-in only),
// and the public channels grouped into one card. Every row shows the live
// contact value (phone number / email / @handle) from RemoteConfig, so the user
// knows exactly where the tap will take them.
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
        _SupportHoursStrip(
          open: config.isSupportOpen,
          hours: config.supportHoursLabel,
        ),
        const SizedBox(height: 12),
        if (loggedIn) ...[
          _OnlineChatCta(onTap: () => context.push('/support')),
          const SizedBox(height: 12),
        ],
        _ContactGroupCard(
          rows: [
            _ContactRowData(
              icon: Icon(Iconsax.call, size: 20, color: pt.dark),
              label: tr('profile.help_contact_call'),
              value: config.supportPhone,
              onTap: () => _launch(config.supportPhoneUri),
            ),
            _ContactRowData(
              icon: const FaIcon(
                FontAwesomeIcons.telegram,
                size: 20,
                color: _telegramBlue,
              ),
              label: tr('profile.help_contact_telegram'),
              value: config.telegramHandleLabel,
              onTap: () => _launch(config.telegramUrl),
            ),
            _ContactRowData(
              icon: Icon(Icons.email_outlined, size: 20, color: pt.dark),
              label: tr('profile.help_contact_email'),
              value: config.supportEmail,
              onTap: () => _launch(config.supportEmailUri),
            ),
          ],
        ),
      ],
    );
  }
}

/// Staffed-hours strip. It titles the contact block (there is no all-caps
/// section label above it) and, more usefully, tells the customer whether a
/// human is on the other end before they burn a call outside working hours.
class _SupportHoursStrip extends StatelessWidget {
  const _SupportHoursStrip({required this.open, required this.hours});

  final bool open;
  final String hours;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: open ? pt.success : pt.greyLight,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              open
                  ? tr('profile.help_support_open')
                  : tr('profile.help_support_closed'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PremiumTokens.body(size: 13, weight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Text(hours, style: PremiumTokens.body(size: 12, color: pt.grey)),
        ],
      ),
    );
  }
}

/// The primary channel, signed-in only. Painted on [PremiumTokens.card] — the
/// inverted brand surface that stays dark in BOTH themes — so it outranks the
/// plain rows below it without a second accent colour competing with the icon.
class _OnlineChatCta extends StatelessWidget {
  const _OnlineChatCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final title = tr('profile.help_contact_online_chat');
    final subtitle = tr('profile.help_contact_online_chat_sub');
    return Semantics(
      button: true,
      label: '$title, $subtitle',
      child: Material(
        color: pt.card,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: PremiumTokens.accent,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.support_agent,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PremiumTokens.body(
                          size: 15,
                          weight: FontWeight.w600,
                          color: pt.onCard,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PremiumTokens.body(
                          size: 11.5,
                          color: pt.onCard.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Iconsax.arrow_right_3_copy,
                  size: 18,
                  color: pt.onCard.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactRowData {
  const _ContactRowData({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  /// Pre-built glyph — a [FaIcon] for brand logos, a plain [Icon] otherwise.
  final Widget icon;
  final String label;
  final String value;
  final VoidCallback onTap;
}

/// The public channels as ONE grouped card: label left, live value right,
/// hairlines inset past the icon column so they read as one object rather than
/// three stacked cards.
class _ContactGroupCard extends StatelessWidget {
  const _ContactGroupCard({required this.rows});

  final List<_ContactRowData> rows;

  /// Left inset shared by the divider and the label column, so the hairline
  /// starts exactly where the text does.
  static const double iconColumn = 58;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: pt.divider),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: iconColumn,
                  color: pt.divider,
                ),
              _ContactGroupRow(data: rows[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContactGroupRow extends StatelessWidget {
  const _ContactGroupRow({required this.data});

  final _ContactRowData data;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Semantics(
      button: true,
      label: '${data.label}, ${data.value}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: data.onTap,
          child: Container(
            height: 56,
            padding: const EdgeInsets.only(left: 18, right: 14),
            child: Row(
              children: [
                SizedBox(width: 20, child: Center(child: data.icon)),
                const SizedBox(width: 20),
                // Capped rather than flexible: a loose Flexible would leave the
                // slack at the end of the row and drag the chevron off the edge.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    data.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PremiumTokens.body(size: 14, weight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    data.value,
                    maxLines: 1,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: PremiumTokens.body(size: 13, color: pt.grey),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Iconsax.arrow_right_3_copy,
                  size: 16,
                  color: pt.greyLight,
                ),
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
