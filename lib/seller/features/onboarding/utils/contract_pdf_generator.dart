import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Localized PDF chrome for the two-column party-requisites footer.
class _PdfLabels {
  const _PdfLabels({
    required this.title,
    required this.partiesHeading,
    required this.platform,
    required this.seller,
    required this.address,
    required this.bank,
    required this.account,
    required this.director,
    required this.phone,
    required this.platformEntityLine,
  });

  final String title;
  final String partiesHeading;
  final String platform;
  final String seller;
  final String address;
  final String bank;
  final String account;
  final String director;
  final String phone;
  final String platformEntityLine;

  static _PdfLabels forLang(String languageCode) {
    switch (languageCode) {
      case 'ru':
        return const _PdfLabels(
          title: 'ПУБЛИЧНАЯ ОФЕРТА',
          partiesHeading: 'Реквизиты сторон',
          platform: 'Платформа',
          seller: 'Продавец',
          address: 'Адрес',
          bank: 'Банк',
          account: 'Р/с',
          director: 'Директор',
          phone: 'Телефон',
          platformEntityLine: 'Платформа "Woody" (Zettacode MCHJ)',
        );
      case 'en':
        return const _PdfLabels(
          title: 'PUBLIC OFFER',
          partiesHeading: 'Party details',
          platform: 'Platform',
          seller: 'Seller',
          address: 'Address',
          bank: 'Bank',
          account: 'Account',
          director: 'Director',
          phone: 'Phone',
          platformEntityLine: '"Woody" platform (Zettacode LLC)',
        );
      default:
        return const _PdfLabels(
          title: 'OMMAVIY OFERTA',
          partiesHeading: 'Tomonlar rekvizitlari',
          platform: 'Platforma',
          seller: 'Sotuvchi',
          address: 'Manzil',
          bank: 'Bank',
          account: 'H/r',
          director: 'Direktor',
          phone: 'Telefon',
          platformEntityLine: '"Woody" platformasi (Zettacode MCHJ)',
        );
    }
  }
}

/// Hardcoded Woody / Zettacode MCHJ bank values (legal entity — not translated).
String _platformRequisitesBody(_PdfLabels l) {
  return '${l.platformEntityLine}\n'
      '${l.address}: Toshkent viloyati, Zangiota tumani, Boz-su, O\'rikzor mahallasi, Nurobod MFY, Sharof Rashidov ko\'chasi, 69-uy\n'
      '${l.bank}: Milliy bankning Bektemir filiali\n'
      '${l.account}: 2020 8000 5074 8592 8003\n'
      'MFO: 00450\n'
      'INN: 313 110 418\n'
      '${l.director}: ELDOR TURG‘UNOV BAXODIR O‘G‘LI\n';
}

/// Builds and opens the OS share sheet for a formal A4 PDF of the accepted
/// (or about-to-accept) ommaviy oferta, with two-column party requisites.
Future<void> generateAndShareContractPdf({
  required String sellerName,
  required String sellerPhone,
  required String contractText,
  String languageCode = 'uz',
  String fileName = 'woody_ommaviy_oferta.pdf',
}) async {
  final labels = _PdfLabels.forLang(languageCode);
  final plain = _stripMarkdown(contractText);
  final doc = pw.Document();

  final regularData = await rootBundle.load(
    'assets/google_fonts/Inter-Regular.ttf',
  );
  final boldData = await rootBundle.load(
    'assets/google_fonts/Inter-Bold.ttf',
  );
  final regular = pw.Font.ttf(regularData);
  final bold = pw.Font.ttf(boldData);

  final theme = pw.ThemeData.withFont(base: regular, bold: bold);
  final name = sellerName.trim().isEmpty ? '—' : sellerName.trim();
  final phone = sellerPhone.trim().isEmpty ? '—' : sellerPhone.trim();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(48, 48, 48, 56),
      theme: theme,
      build: (context) => [
        pw.Text(
          labels.title,
          style: pw.TextStyle(font: bold, fontSize: 16),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          plain,
          style: pw.TextStyle(font: regular, fontSize: 10, lineSpacing: 2),
          textAlign: pw.TextAlign.justify,
        ),
        pw.SizedBox(height: 28),
        pw.Divider(thickness: 0.6),
        pw.SizedBox(height: 12),
        pw.Text(
          labels.partiesHeading,
          style: pw.TextStyle(font: bold, fontSize: 11),
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    labels.platform,
                    style: pw.TextStyle(font: bold, fontSize: 10),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    _platformRequisitesBody(labels),
                    style: pw.TextStyle(
                      font: regular,
                      fontSize: 8.5,
                      lineSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    labels.seller,
                    style: pw.TextStyle(font: bold, fontSize: 10),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '${labels.seller}: $name\n'
                    '${labels.phone}: $phone',
                    style: pw.TextStyle(
                      font: regular,
                      fontSize: 8.5,
                      lineSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );

  final bytes = await doc.save();
  await Printing.sharePdf(bytes: bytes, filename: fileName);
}

String _stripMarkdown(String input) {
  return input.replaceAllMapped(
    RegExp(r'\*\*(.+?)\*\*', dotAll: true),
    (m) => m.group(1) ?? '',
  );
}
