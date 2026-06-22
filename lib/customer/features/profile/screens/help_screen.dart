import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/auth/auth_cubit.dart';
import '../../home/widgets/premium/premium_tokens.dart';

// Real, shipped support channels — kept in sync with profile_screen's /support
// entry. Don't swap these for unverified handles; a dead link reads as broken.
const _telegramUrl = 'https://t.me/woody_support';
const _whatsappUrl = 'https://wa.me/998946433733';
const _emailUrl = 'mailto:info@woody.uz';

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
        "Yordam va Qo'llab-quvvatlash",
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
          const _SectionLabel('Murojaat qiling'),
          const SizedBox(height: 14),
          BlocBuilder<AuthCubit, AppAuthState>(
            builder: (context, state) =>
                _ContactRow(loggedIn: state is AppAuthAuthenticated),
          ),
          const SizedBox(height: 28),
          // ---- Categorised FAQ ---------------------------------------------
          const _SectionLabel("Tez-tez so'raladigan savollar"),
          const SizedBox(height: 12),
          const _FaqSection(
            title: 'Umumiy savollar',
            icon: Iconsax.info_circle,
            items: [
              _FaqItem(
                question: 'Yetkazib berish qancha vaqt oladi?',
                answer:
                    "Toshkent bo'ylab 1–2 ish kuni, viloyatlarga 3–5 ish kuni. "
                    'Aniq muddat buyurtma sahifasida ko\'rsatiladi.',
              ),
              _FaqItem(
                question: 'Yetkazib berish narxi qancha?',
                answer:
                    "Toshkent ichida 25 000 so'mdan boshlanadi. 500 000 "
                    "so'mdan yuqori buyurtmalarga bepul.",
              ),
              _FaqItem(
                question: "Qanday to'lov usullari mavjud?",
                answer:
                    "Naqd, Click, Payme, Uzcard va Humo. Yetkazib berishda "
                    "to'lash ham mumkin.",
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _FaqSection(
            title: 'Xaridorlar uchun',
            icon: Iconsax.bag_2,
            items: [
              _FaqItem(
                question: 'Buyurtmamni qanday bekor qilaman?',
                answer:
                    "'Buyurtmalarim'dan kerakli buyurtmani tanlab, 'Bekor "
                    "qilish'ni bosing. Jo'natilgunga qadar bekor qilish mumkin.",
              ),
              _FaqItem(
                question: 'Buyurtma holatini qanday kuzataman?',
                answer:
                    "'Buyurtmalarim' bo'limida joriy holat ko'rinadi: "
                    "Kutilmoqda, Tayyorlanmoqda, Yo'lda, Yetkazilgan.",
              ),
              _FaqItem(
                question: "To'lovni qaytarish qanday ishlaydi?",
                answer:
                    "Bekor qilinganda to'lov 3–5 ish kunida kartaga qaytadi. "
                    "Naqd to'lovlar darhol qaytariladi.",
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _FaqSection(
            title: 'Sotuvchilar uchun',
            icon: Iconsax.shop,
            items: [
              _FaqItem(
                question: "Qanday qilib sotuvchi bo'lish mumkin?",
                answer:
                    "Profil bo'limidan 'Sotuvchi bo'ling' tugmasini bosib, "
                    "so'rovnoma to'ldiring.",
              ),
              _FaqItem(
                question: 'Sotuvchilardan nimalar talab qilinadi?',
                answer:
                    "Faqat sifatli mebel suratlari, to'g'ri o'lchamlar va o'z "
                    'vaqtida yetkazib berish.',
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _QuickContact(
          icon: Icon(Icons.email_outlined, size: 24, color: pt.dark),
          tint: pt.dark,
          label: 'Email',
          onTap: () => _launch(_emailUrl),
        ),
        _QuickContact(
          icon: const FaIcon(
            FontAwesomeIcons.telegram,
            size: 22,
            color: _telegramBlue,
          ),
          tint: _telegramBlue,
          label: 'Telegram',
          onTap: () => _launch(_telegramUrl),
        ),
        _QuickContact(
          icon: const FaIcon(
            FontAwesomeIcons.whatsapp,
            size: 22,
            color: _whatsappGreen,
          ),
          tint: _whatsappGreen,
          label: 'WhatsApp',
          onTap: () => _launch(_whatsappUrl),
        ),
        if (loggedIn)
          _QuickContact(
            icon: const Icon(
              Icons.support_agent,
              size: 24,
              color: PremiumTokens.accent,
            ),
            tint: PremiumTokens.accent,
            label: 'Onlayn chat',
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
              style: PremiumTokens.body(size: 13, color: pt.grey, height: 1.5),
            ),
          ),
        ],
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
