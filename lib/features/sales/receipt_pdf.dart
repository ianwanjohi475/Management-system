import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/constants/assets.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';

const _green = PdfColor.fromInt(0xFFC8553D);
const _amber = PdfColor.fromInt(0xFFF5B700);
const _muted = PdfColor.fromInt(0xFF6B7066);

Future<pw.ThemeData> pdfTheme() async {
  final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Regular.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Poppins-SemiBold.ttf'));
  return pw.ThemeData.withFont(base: regular, bold: bold);
}

Future<pw.MemoryImage?> pdfLogo() async {
  try {
    final bytes = await rootBundle.load(Assets.logoMark);
    return pw.MemoryImage(bytes.buffer.asUint8List());
  } catch (_) {
    return null;
  }
}

Future<Uint8List> buildReceipt(Sale s, FarmProfile? farm, {String? flockName, List<String> pigTags = const []}) async {
  final doc = pw.Document(theme: await pdfTheme(), title: 'Receipt ${s.receiptLabel}');
  final logo = await pdfLogo();

  pw.Widget row(String l, String v, {bool bold = false, PdfColor? color}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(l, style: const pw.TextStyle(color: _muted, fontSize: 10)),
        ),
        pw.Text(
          v,
          style: pw.TextStyle(fontSize: bold ? 13 : 10.5, fontWeight: bold ? pw.FontWeight.bold : null, color: color),
        ),
      ],
    ),
  );

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.roll80.copyWith(marginLeft: 14, marginRight: 14, marginTop: 16, marginBottom: 16),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Center(child: logo != null ? pw.Image(logo, width: 44) : pw.SizedBox()),
          pw.SizedBox(height: 6),
          pw.Center(
            child: pw.Text(
              farm?.name ?? 'Shamba.',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _green),
            ),
          ),
          if ((farm?.location ?? '').isNotEmpty)
            pw.Center(
              child: pw.Text(farm!.location, style: const pw.TextStyle(fontSize: 9, color: _muted)),
            ),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text('SALES RECEIPT', style: pw.TextStyle(fontSize: 9, letterSpacing: 2, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Divider(color: _muted, borderStyle: pw.BorderStyle.dashed),
          row('Receipt no.', s.receiptLabel),
          row('Date', Fmt.dateTime(s.date)),
          if (s.customerName.isNotEmpty) row('Customer', s.customerName),
          if (s.customerPhone.isNotEmpty) row('Phone', s.customerPhone),
          pw.Divider(color: _muted, borderStyle: pw.BorderStyle.dashed),
          pw.Text(s.product.label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
          if (flockName != null) pw.Text('From $flockName', style: const pw.TextStyle(fontSize: 9, color: _muted)),
          if (pigTags.isNotEmpty) pw.Text('Tags: ${pigTags.join(', ')}', style: const pw.TextStyle(fontSize: 9, color: _muted)),
          row('${s.quantityLabel} × ${Fmt.money(s.unitPrice)}', Fmt.money(s.total)),
          if (s.weightKg != null) row('Live weight', Fmt.kg(s.weightKg!)),
          pw.Divider(color: _muted, borderStyle: pw.BorderStyle.dashed),
          row('TOTAL', Fmt.money(s.total), bold: true),
          for (final p in s.payments) row('Paid · ${p.method.label}${p.reference.isNotEmpty ? ' (${p.reference})' : ''}', Fmt.money(p.amount)),
          row('Balance', Fmt.money(s.balance), bold: true, color: s.balance > 0 ? PdfColors.red700 : _green),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: pw.BoxDecoration(color: s.balance > 0 ? _amber : _green, borderRadius: pw.BorderRadius.circular(10)),
              child: pw.Text(
                s.paymentStatus.label.toUpperCase(),
                style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Center(
            child: pw.Text('Thank you for your business!', style: const pw.TextStyle(fontSize: 9, color: _muted)),
          ),
          pw.Center(
            child: pw.Text('Made with Shamba.', style: const pw.TextStyle(fontSize: 7.5, color: _muted)),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}

/// Opens the share sheet with a PDF; turns plugin failures into friendly errors.
Future<void> sharePdf(Uint8List bytes, String filename) async {
  try {
    await Printing.sharePdf(bytes: bytes, filename: filename);
  } catch (e) {
    throw const PlatformFeatureException('Sharing is not available on this device.');
  }
}

Future<void> printPdf(Uint8List bytes, String name) async {
  try {
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
  } catch (e) {
    throw const PlatformFeatureException('No printer or print service is available.');
  }
}
