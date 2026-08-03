import 'package:flutter/painting.dart';

/// Placeholder tokens mirrored in the backend `legal_documents` seed.
const kOfertaSellerName = '{{SOTUVCHI_NOMI}}';
const kOfertaCommission = '{{KOMISSIYA_FOIZI}}';
const kOfertaDate = '{{SANA}}';
const kOfertaContractNumber = '{{SHARTNOMA_RAQAMI}}';

/// Hardcoded Woody / Zettacode MCHJ bank values for the GPD requisites column.
/// Do not paraphrase — must match the registered entity.
const String kZettacodeLegalName = 'Zettacode MCHJ';
const String kZettacodeAddress =
    "Toshkent viloyati, Zangiota tumani, Boz-su, O'rikzor mahallasi, Nurobod MFY, Sharof Rashidov ko'chasi, 69-uy";
const String kZettacodeBank = 'Milliy bankning Bektemir filiali';
const String kZettacodeAccount = '2020 8000 5074 8592 8003';
const String kZettacodeMfo = '00450';
const String kZettacodeInn = '313 110 418';
const String kZettacodeDirector = 'ELDOR TURG‘UNOV';

/// Offline / 404 fallback — body only (header + requisites are Flutter/PDF chrome).
/// Keep placeholders in lockstep with the seeded `seller_oferta` rows.
const String kSellerOfertaFallbackContent =
    '''"Woody" platformasi nomidan ish ko'ruvchi "Zettacode" MCHJ (keyingi o'rinlarda "Platforma" yoki "Buyurtmachi"), bir tomondan, va mustaqil tadbirkor/jismoniy shaxs — **{{SOTUVCHI_NOMI}}** (keyingi o'rinlarda "Sotuvchi" yoki "Ijrochi"), ikkinchi tomondan, quyidagilar haqida mazkur shartnomani tuzdilar:

1. Umumiy qoidalar
1.1. Ushbu shartnoma "Woody" mebellar platformasi (keyingi o'rinlarda "Platforma") va o'z mahsulotlarini sotuvchi mustaqil tadbirkor/jismoniy shaxs — **{{SOTUVCHI_NOMI}}** (keyingi o'rinlarda "Sotuvchi") o'rtasida tuzildi.
1.2. Shartnoma elektron tarzda tasdiqlangan (tugma bosilgan) vaqtdan boshlab rasmiy yuridik kuchga kiradi. Tasdiqlash sanasi: **{{SANA}}**.

2. To'lov turlari va Escrow (Kafil) tizimi
2.1. **Onlayn to'lovlar:** Xaridor ilova orqali (Payme, Click va boshqalar) to'lov amalga oshirganda, mablag'lar Platformaning maxsus tranzit (Escrow) hisob-raqamida vaqtincha saqlanadi. Mahsulot xaridorga muvaffaqiyatli yetkazib berilgani tizimda tasdiqlangandan so'ng, vositachilik komissiyasi ushlab qolinib, qolgan summa Sotuvchining elektron hamyoniga o'tkaziladi.
2.2. **Naqd to'lovlar (COD):** Xaridor mahsulotni qabul qilib olganda to'lovni naqd pulda to'g'ridan-to'g'ri Sotuvchiga (yoki uning kuryeriga) amalga oshiradi. Bunda Platforma vositachilik komissiyasini Sotuvchining ilova ichidagi elektron hamyonidan (balansidan) avtomatik tarzda chegirib qoladi.

3. Vositachilik komissiyasi va Obuna tariflari
3.1. Platforma xizmatlari uchun komissiya miqdori Sotuvchi tanlagan va faol bo'lgan **Obuna ta'rifiga (Tarif rejasiga)** asosan belgilanadi. Sotuvchining joriy tarif komissiyasi: **{{KOMISSIYA_FOIZI}}%** (masalan: Free — 6%, Basic — 4%, Pro — 2%, Enterprise — 1%).
3.2. Sotuvchi o'z elektron hamyonida naqd to'lovli buyurtmalar komissiyasini yoplash uchun yetarli mablag' saqlash majburiyatini oladi. Qarz miqdori belgilangan limitdan oshib ketsa, Platforma Sotuvchi profilini vaqtincha bloklash huquqiga ega.

4. Sifat va Yetkazib berish (SLA) majburiyatlari
4.1. Sotuvchi mahsulotlarni ilovada ko'rsatilgan sifatda, o'lchamda va e'lon qilingan muddat ichida yetkazib berishga to'liq javobgardir.
4.2. Agar mahsulot sifatsiz bo'lsa yoki yetkazish vaqti asossiz ravishda buzilsa, Platforma tranzaksiyani bekor qilishga va mablag'ni xaridorga to'liq qaytarishga (Refund) haqli.
''';

/// Builds a stable human-readable contract number from the seller/user id.
/// Example: `W-A1B2C3` from UUID `a1b2c3d4-…`.
String generateOfertaContractNumber(String? sellerId) {
  final raw = (sellerId ?? '').replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
  if (raw.isEmpty) return 'W-XXXXXX';
  final prefix = raw.length >= 6 ? raw.substring(0, 6) : raw.padRight(6, '0');
  return 'W-${prefix.toUpperCase()}';
}

/// Injects seller-specific values into the remote (or fallback) oferta body.
String injectOfertaPlaceholders(
  String content, {
  required String sellerName,
  required String commissionPercent,
  required String dateLabel,
  String? contractNumber,
}) {
  var out = content
      .replaceAll(
        kOfertaSellerName,
        sellerName.trim().isEmpty ? '—' : sellerName.trim(),
      )
      .replaceAll(kOfertaCommission, commissionPercent)
      .replaceAll(kOfertaDate, dateLabel);
  if (contractNumber != null) {
    out = out.replaceAll(kOfertaContractNumber, contractNumber);
  }
  return out;
}

/// Localized chrome for the formal GPD header + requisites table (UI + PDF).
class OfertaGpdLabels {
  const OfertaGpdLabels({
    required this.city,
    required this.contractTitle,
    required this.datePrefix,
    required this.requisitesHeading,
    required this.platformColumnTitle,
    required this.sellerColumnTitle,
    required this.address,
    required this.bank,
    required this.account,
    required this.director,
    required this.seller,
    required this.phone,
  });

  final String city;
  final String contractTitle;
  final String datePrefix;
  final String requisitesHeading;
  final String platformColumnTitle;
  final String sellerColumnTitle;
  final String address;
  final String bank;
  final String account;
  final String director;
  final String seller;
  final String phone;

  static OfertaGpdLabels forLang(String languageCode) {
    switch (languageCode) {
      case 'ru':
        return const OfertaGpdLabels(
          city: 'г. Ташкент',
          contractTitle: 'ПОСРЕДНИЧЕСКИЙ ДОГОВОР №',
          datePrefix: 'Дата:',
          requisitesHeading: 'РЕКВИЗИТЫ И ПОДПИСИ СТОРОН',
          platformColumnTitle: 'Платформа (Заказчик)',
          sellerColumnTitle: 'Продавец (Исполнитель)',
          address: 'Адрес',
          bank: 'Банк',
          account: 'Р/с',
          director: 'Директор',
          seller: 'Продавец',
          phone: 'Телефон',
        );
      case 'en':
        return const OfertaGpdLabels(
          city: 'Tashkent',
          contractTitle: 'INTERMEDIARY AGREEMENT No.',
          datePrefix: 'Date:',
          requisitesHeading: 'PARTY DETAILS AND SIGNATURES',
          platformColumnTitle: 'Platform (Client)',
          sellerColumnTitle: 'Seller (Contractor)',
          address: 'Address',
          bank: 'Bank',
          account: 'Account',
          director: 'Director',
          seller: 'Seller',
          phone: 'Phone',
        );
      default:
        return const OfertaGpdLabels(
          city: 'Toshkent shahri',
          contractTitle: 'VOSITACHILIK SHARTNOMASI №',
          datePrefix: 'Sana:',
          requisitesHeading: 'TOMONLARNING REKVIZITLARI VA IMZOLARI',
          platformColumnTitle: 'Platforma (Buyurtmachi)',
          sellerColumnTitle: 'Sotuvchi (Ijrochi)',
          address: 'Manzil',
          bank: 'Bank',
          account: 'H/r',
          director: 'Direktor',
          seller: 'Sotuvchi',
          phone: 'Telefon',
        );
    }
  }
}


/// Platform (Zettacode) requisites block — no signature line (electronic accept).
String buildPlatformRequisitesBlock(OfertaGpdLabels labels) {
  return '$kZettacodeLegalName\n'
      '${labels.address}: $kZettacodeAddress\n'
      '${labels.bank}: $kZettacodeBank\n'
      '${labels.account}: $kZettacodeAccount\n'
      'MFO: $kZettacodeMfo\n'
      'INN: $kZettacodeInn\n'
      '${labels.director}: $kZettacodeDirector';
}

/// Seller requisites: only real non-empty fields (omit missing address/phone/name).
String buildSellerRequisitesBlock({
  required OfertaGpdLabels labels,
  required String sellerName,
  required String sellerPhone,
  required String sellerAddress,
}) {
  final lines = <String>[];
  final name = sellerName.trim();
  final address = sellerAddress.trim();
  final phone = sellerPhone.trim();
  if (name.isNotEmpty) lines.add('${labels.seller}: $name');
  if (address.isNotEmpty) lines.add('${labels.address}: $address');
  if (phone.isNotEmpty) lines.add('${labels.phone}: $phone');
  return lines.join('\n');
}

/// Renders `**bold**` markers from the legal body as [TextSpan]s.
List<InlineSpan> parseOfertaMarkdownSpans({
  required String content,
  required TextStyle body,
  required TextStyle bold,
}) {
  final spans = <InlineSpan>[];
  final pattern = RegExp(r'\*\*(.+?)\*\*', dotAll: true);
  var cursor = 0;
  for (final match in pattern.allMatches(content)) {
    if (match.start > cursor) {
      spans.add(
        TextSpan(text: content.substring(cursor, match.start), style: body),
      );
    }
    spans.add(TextSpan(text: match.group(1), style: bold));
    cursor = match.end;
  }
  if (cursor < content.length) {
    spans.add(TextSpan(text: content.substring(cursor), style: body));
  }
  if (spans.isEmpty) {
    spans.add(TextSpan(text: content, style: body));
  }
  return spans;
}

/// TODO(legal-reaccept): when [remoteVersion] is newer than the seller's
/// stamped [acceptedVersion], surface a blocking re-accept prompt on seller
/// boot / login. Comparison is lexical on the dotted version string for now.
bool ofertaNeedsReaccept({
  required String? acceptedVersion,
  required String remoteVersion,
}) {
  if (acceptedVersion == null || acceptedVersion.isEmpty) return false;
  return acceptedVersion.trim() != remoteVersion.trim();
}
