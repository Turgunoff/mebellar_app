import 'package:flutter/painting.dart';

/// Placeholder tokens mirrored in the backend `legal_documents` seed.
const kOfertaSellerName = '{{SOTUVCHI_NOMI}}';
const kOfertaCommission = '{{KOMISSIYA_FOIZI}}';
const kOfertaDate = '{{SANA}}';

/// Offline / 404 fallback — must stay in lockstep with the seeded
/// `seller_oferta` row until the Admin edits it remotely.
const String kSellerOfertaFallbackContent = '''OMMAVIY OFERTA (Platformadan foydalanish va vositachilik xizmatlari ko'rsatish shartnomasi)

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

/// Injects seller-specific values into the remote (or fallback) oferta body.
String injectOfertaPlaceholders(
  String content, {
  required String sellerName,
  required String commissionPercent,
  required String dateLabel,
}) {
  return content
      .replaceAll(
        kOfertaSellerName,
        sellerName.trim().isEmpty ? '—' : sellerName.trim(),
      )
      .replaceAll(kOfertaCommission, commissionPercent)
      .replaceAll(kOfertaDate, dateLabel);
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
      spans.add(TextSpan(text: content.substring(cursor, match.start), style: body));
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
