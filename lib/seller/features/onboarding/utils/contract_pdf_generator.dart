import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../constants/seller_contract_oferta.dart';

/// Builds and opens the OS share sheet for a formal A4 GPD-style PDF of the
/// accepted (or about-to-accept) vositachilik shartnomasi.
Future<void> generateAndShareContractPdf({
  required String sellerName,
  required String sellerPhone,
  required String contractText,
  required String contractNumber,
  required String dateLabel,
  String sellerAddress = '',
  String languageCode = 'uz',
  String fileName = 'woody_vositachilik_shartnomasi.pdf',
}) async {
  final labels = OfertaGpdLabels.forLang(languageCode);
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
  final sellerBlock = buildSellerRequisitesBlock(
    labels: labels,
    sellerName: sellerName,
    sellerPhone: sellerPhone,
    sellerAddress: sellerAddress,
  );
  final platformBlock = buildPlatformRequisitesBlock(labels);

  final bodyStyle = pw.TextStyle(font: regular, fontSize: 10, lineSpacing: 2);
  final boldStyle = pw.TextStyle(font: bold, fontSize: 10, lineSpacing: 2);
  final smallStyle = pw.TextStyle(font: regular, fontSize: 8.5, lineSpacing: 1.4);
  final smallBold = pw.TextStyle(font: bold, fontSize: 8.5, lineSpacing: 1.4);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(48, 48, 48, 56),
      theme: theme,
      build: (context) => [
        // ── Part 1: City / title / date header ──────────────────────────
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Text(labels.city, style: boldStyle),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    '${labels.contractTitle} $contractNumber',
                    style: boldStyle,
                    textAlign: pw.TextAlign.right,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '${labels.datePrefix} $dateLabel',
                    style: bodyStyle,
                    textAlign: pw.TextAlign.right,
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 20),

        // ── Part 2: Body ────────────────────────────────────────────────
        pw.Text(
          plain,
          style: bodyStyle,
          textAlign: pw.TextAlign.justify,
        ),
        pw.SizedBox(height: 24),

        // ── Part 3: Requisites table ────────────────────────────────────
        pw.Text(
          labels.requisitesHeading,
          style: pw.TextStyle(font: bold, fontSize: 11),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(width: 0.7, color: PdfColors.black),
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    labels.platformColumnTitle,
                    style: smallBold,
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    labels.sellerColumnTitle,
                    style: smallBold,
                  ),
                ),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(platformBlock, style: smallStyle),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(sellerBlock, style: smallStyle),
                ),
              ],
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
