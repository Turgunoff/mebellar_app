import 'package:flutter/painting.dart';

/// Uzbek public-offer (oferta) body for seller onboarding.
///
/// Key commercial terms (online vs COD, tariff commission ladder) are rendered
/// in [bold]. [sellerName] is injected into §1.1 when known so the signed
/// party is named on the face of the document.
List<InlineSpan> buildSellerContractSpans({
  required String sellerName,
  required TextStyle body,
  required TextStyle bold,
  required TextStyle heading,
  required TextStyle section,
}) {
  InlineSpan p(String text, [TextStyle? style]) =>
      TextSpan(text: text, style: style ?? body);

  final namedParty = sellerName.trim().isNotEmpty &&
          sellerName.trim() != '[Sotuvchi Nomi]'
      ? sellerName.trim()
      : null;

  return [
    p(
      'OMMAVIY OFERTA (Platformadan foydalanish va vositachilik '
      'xizmatlari ko\'rsatish shartnomasi)\n\n',
      heading,
    ),

    // --- 1 ---
    p('1. Umumiy qoidalar\n', section),
    p(
      '1.1. Ushbu shartnoma "Woody" mebellar platformasi (keyingi o\'rinlarda '
      '"Platforma") va o\'z mahsulotlarini sotuvchi mustaqil '
      'tadbirkor/jismoniy shaxs',
    ),
    if (namedParty != null) ...[
      p(' — '),
      p(namedParty, bold),
    ],
    p(
      ' (keyingi o\'rinlarda "Sotuvchi") o\'rtasida tuzildi.\n'
      '1.2. Shartnoma elektron tarzda tasdiqlangan (tugma bosilgan) vaqtdan '
      'boshlab rasmiy yuridik kuchga kiradi.\n\n',
    ),

    // --- 2 ---
    p('2. To\'lov turlari va Escrow (Kafil) tizimi\n', section),
    p('2.1. '),
    p('Onlayn to\'lovlar:', bold),
    p(
      ' Xaridor ilova orqali (Payme, Click va boshqalar) to\'lov amalga '
      'oshirganda, mablag\'lar Platformaning maxsus tranzit (Escrow) '
      'hisob-raqamida vaqtincha saqlanadi. Mahsulot xaridorga muvaffaqiyatli '
      'yetkazib berilgani tizimda tasdiqlangandan so\'ng, vositachilik '
      'komissiyasi ushlab qolinib, qolgan summa Sotuvchining elektron '
      'hamyoniga o\'tkaziladi.\n'
      '2.2. ',
    ),
    p('Naqd to\'lovlar (COD):', bold),
    p(
      ' Xaridor mahsulotni qabul qilib olganda to\'lovni naqd pulda '
      'to\'g\'ridan-to\'g\'ri Sotuvchiga (yoki uning kuryeriga) amalga '
      'oshiradi. Bunda Platforma vositachilik komissiyasini Sotuvchining '
      'ilova ichidagi elektron hamyonidan (balansidan) avtomatik tarzda '
      'chegirib qoladi.\n\n',
    ),

    // --- 3 ---
    p('3. Vositachilik komissiyasi va Obuna tariflari\n', section),
    p(
      '3.1. Platforma xizmatlari uchun komissiya miqdori Sotuvchi tanlagan '
      'va faol bo\'lgan ',
    ),
    p('Obuna ta\'rifiga (Tarif rejasiga)', bold),
    p(' asosan belgilanadi (masalan: '),
    p('Free — 6%', bold),
    p(', '),
    p('Basic — 4%', bold),
    p(', '),
    p('Pro — 2%', bold),
    p(', '),
    p('Enterprise — 1%', bold),
    p(
      ').\n'
      '3.2. Sotuvchi o\'z elektron hamyonida naqd to\'lovli buyurtmalar '
      'komissiyasini yoplash uchun yetarli mablag\' saqlash majburiyatini '
      'oladi. Qarz miqdori belgilangan limitdan oshib ketsa, Platforma '
      'Sotuvchi profilini vaqtincha bloklash huquqiga ega.\n\n',
    ),

    // --- 4 ---
    p('4. Sifat va Yetkazib berish (SLA) majburiyatlari\n', section),
    p(
      '4.1. Sotuvchi mahsulotlarni ilovada ko\'rsatilgan sifatda, o\'lchamda '
      'va e\'lon qilingan muddat ichida yetkazib berishga to\'liq '
      'javobgardir.\n'
      '4.2. Agar mahsulot sifatsiz bo\'lsa yoki yetkazish vaqti asossiz '
      'ravishda buzilsa, Platforma tranzaksiyani bekor qilishga va '
      'mablag\'ni xaridorga to\'liq qaytarishga (Refund) haqli.\n',
    ),
  ];
}
