import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../home/widgets/premium/premium_tokens.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _version = '1.0.0';

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
                  'Woody',
                  style: PremiumTokens.display(size: 26, letterSpacing: -0.3),
                ),
                const SizedBox(height: 6),
                Text(
                  'Versiya $_version',
                  style: PremiumTokens.body(size: 13, color: pt.grey),
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
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const StaticContentScreen(
                        title: 'Foydalanish shartlari',
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
                  title: 'Maxfiylik siyosati',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const StaticContentScreen(
                        title: 'Maxfiylik siyosati',
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
              '© 2026 Woody',
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
        icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: pt.dark),
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
                  style: PremiumTokens.body(size: 14, weight: FontWeight.w500),
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
            Icons.arrow_back_ios_new_rounded,
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
            type == StaticContentType.terms ? _kTermsText : _kPrivacyText,
            style: PremiumTokens.body(size: 14, color: pt.grey, height: 1.7),
          ),
        ],
      ),
    );
  }
}

const _kTermsText = '''
Ushbu foydalanish shartlari Woody ilovasi (keyingi o'rinlarda "Ilova") foydalanuvchilari uchun mo'ljallangan va Ilova orqali taqdim etiladigan xizmatlardan foydalanish qoidalarini belgilaydi.

1. Xizmatlardan foydalanish

Ilovadan foydalanish uchun siz kamida 18 yoshda bo'lishingiz yoki ota-onangiz yoxud qonuniy vakilingizning roziligi bilan harakat qilishingiz lozim. Foydalanuvchi o'z hisobi orqali amalga oshirilgan barcha harakatlar uchun to'liq javobgar hisoblanadi. Hisob ma'lumotlarini uchinchi shaxslarga berish qat'iyan taqiqlanadi.

2. Buyurtmalar va to'lovlar

Ilova orqali berilgan barcha buyurtmalar uchun belgilangan narxlar va yetkazib berish shartlari amal qiladi. Sotuvchi tomonidan tasdiqlangan buyurtmani bekor qilish yoki o'zgartirish uchun Woody mijozlar xizmati bilan bog'lanish talab etiladi. To'lovlar xavfsiz to'lov tizimlari orqali amalga oshiriladi; Woody to'lov kartasi ma'lumotlarini saqlamaydi.

3. Mas'uliyat chegaralari

Woody platforma sifatida harakat qilib, sotuvchi va xaridor o'rtasidagi savdoni osonlashtiradi. Mahsulot sifati, yetkazib berish muddatlari va boshqa savdo shartlari bo'yicha yuzaga kelgan nizolarda Woody vositachi sifatida ko'maklashadi, ammo to'liq javobgarlik sotuvchi zimmasida qoladi. Fors-major holatlari (tabiiy ofatlar, tashqi tarmoq uzilishlari va shu kabilar) da Woody mas'uliyatdan ozod etiladi.
''';

const _kPrivacyText = '''
Woody ilovasi foydalanuvchilarning shaxsiy ma'lumotlarini to'plash, saqlash va qayta ishlashda O'zbekiston Respublikasining "Shaxsiy ma'lumotlar to'g'risida"gi qonuniga va xalqaro eng yaxshi amaliyotlarga amal qiladi.

1. Qanday ma'lumotlar to'planadi

Biz foydalanuvchi ro'yxatdan o'tishda ko'rsatgan ism, elektron pochta manzili va telefon raqami; buyurtmalar tarixi va yetkazib berish manzillari; qurilma identifikatori va ilova foydalanish statistikasini to'playmiz. Joylashuv ma'lumotlari faqat foydalanuvchi roziligidan so'ng va yetkazib berish manzilini aniqlash maqsadida olinadi.

2. Ma'lumotlardan foydalanish maqsadlari

To'plangan ma'lumotlar buyurtmalarni qayta ishlash va yetkazib berish, mijozlarga xizmat ko'rsatish, ilova ishlashini yaxshilash hamda qonuniy majburiyatlarni bajarish uchun ishlatiladi. Shaxsiy ma'lumotlar uchinchi shaxslarga faqat xizmat ko'rsatuvchi hamkorlar (to'lov tizimlari, yetkazib berish xizmatlari) bilan almashiladi va faqat zarur miqdorda uzatiladi.

3. Ma'lumotlarni himoya qilish va huquqlar

Barcha ma'lumotlar shifrlangan kanallar orqali uzatiladi va xavfsiz serverllarda saqlanadi. Foydalanuvchi o'z shaxsiy ma'lumotlarini ko'rish, o'zgartirish yoki o'chirish huquqiga ega. Bunday so'rovlar bilan privacy@mebellar.uz elektron pochta manziliga murojaat qilishingiz mumkin.
''';
