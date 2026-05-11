import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../home/widgets/premium/premium_tokens.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _telegramUrl = 'https://t.me/mebellar_support';
  static const _whatsappUrl = 'https://wa.me/998901234567';

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
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
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        physics: const BouncingScrollPhysics(),
        children: [
          const _SectionLabel('Tez-tez so\'raladigan savollar'),
          const SizedBox(height: 8),
          _FaqCard(
            category: 'Buyurtmalar',
            icon: Iconsax.box,
            items: const [
              _FaqItem(
                question: 'Buyurtmamni qanday bekor qilaman?',
                answer:
                    'Buyurtmangizni "Buyurtmalarim" bo\'limiga kirib, kerakli buyurtmani tanlang va "Bekor qilish" tugmasini bosing. Buyurtma jo\'natilgunga qadar bekor qilish mumkin.',
              ),
              _FaqItem(
                question: 'Buyurtma holatini qanday kuzataman?',
                answer:
                    '"Buyurtmalarim" bo\'limiga kiring. U yerda barcha buyurtmalaringizning joriy holati ko\'rsatiladi: Kutilmoqda, Tayyorlanmoqda, Yo\'lda, Yetkazilgan.',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _FaqCard(
            category: 'Yetkazib berish',
            icon: Iconsax.truck,
            items: const [
              _FaqItem(
                question: 'Yetkazib berish qancha vaqt oladi?',
                answer:
                    'Toshkent shahri bo\'ylab 1–2 ish kuni. Viloyatlarga yetkazib berish 3–5 ish kunini olishi mumkin. Aniq muddatlar buyurtma sahifasida ko\'rsatiladi.',
              ),
              _FaqItem(
                question: 'Yetkazib berish narxi qancha?',
                answer:
                    'Toshkent ichida yetkazib berish 25 000 so\'mdan boshlanadi. 500 000 so\'mdan yuqori buyurtmalar uchun yetkazib berish bepul.',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _FaqCard(
            category: "To'lovlar",
            icon: Iconsax.card,
            items: const [
              _FaqItem(
                question: "Qanday to'lov usullari mavjud?",
                answer:
                    "Naqd pul, Click, Payme, Uzcard va Humo kartalar orqali to'lashingiz mumkin. Yetkazib berishda ham to'lash imkoniyati mavjud.",
              ),
              _FaqItem(
                question: "To'lovni qaytarish qanday ishlaydi?",
                answer:
                    "Buyurtma bekor qilinsa, to'lov 3–5 ish kuni ichida kartangizga qaytariladi. Naqd pul to'lovlari darhol qaytariladi.",
              ),
            ],
          ),
          const SizedBox(height: 32),
          const _SectionLabel("Murojaat qiling"),
          const SizedBox(height: 8),
          _ContactCard(
            icon: Iconsax.message,
            label: 'Telegram orqali',
            subtitle: '@mebellar_support',
            color: const Color(0xFF2AABEE),
            onTap: () => _launch(_telegramUrl),
          ),
          const SizedBox(height: 10),
          _ContactCard(
            icon: Iconsax.call,
            label: 'WhatsApp orqali',
            subtitle: '+998 90 123 45 67',
            color: const Color(0xFF25D366),
            onTap: () => _launch(_whatsappUrl),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FAQ card
// ---------------------------------------------------------------------------

class _FaqItem {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;
}

class _FaqCard extends StatelessWidget {
  const _FaqCard({
    required this.category,
    required this.icon,
    required this.items,
  });

  final String category;
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
            // Category header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: pt.imageBg,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: 16, color: PremiumTokens.accent),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    category,
                    style: PremiumTokens.body(
                      size: 14,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Divider(height: 1, color: pt.divider),
            ),
            // FAQ items
            for (final item in items)
              Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  splashColor: PremiumTokens.accent.withValues(alpha: 0.06),
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.fromLTRB(18, 0, 14, 0),
                  childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                  iconColor: PremiumTokens.accent,
                  collapsedIconColor: pt.greyLight,
                  title: Text(
                    item.question,
                    style: PremiumTokens.body(
                      size: 13,
                      weight: FontWeight.w500,
                    ),
                  ),
                  children: [
                    Text(
                      item.answer,
                      style: PremiumTokens.body(
                        size: 13,
                        color: pt.grey,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Contact card
// ---------------------------------------------------------------------------

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Material(
      color: pt.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: PremiumTokens.softShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: PremiumTokens.body(
                        size: 14,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: PremiumTokens.body(
                        size: 12,
                        color: pt.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: color,
              ),
            ],
          ),
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
