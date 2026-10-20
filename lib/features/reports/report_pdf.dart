import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/farm_store.dart';
import '../sales/receipt_pdf.dart';

const _green = PdfColor.fromInt(0xFF2F5D1E);
const _tint = PdfColor.fromInt(0xFFE6F2D6);
const _muted = PdfColor.fromInt(0xFF6B7066);

/// A printable farm performance report for the chosen period.
Future<Uint8List> buildFarmReport(FarmStore store, DateRange range, String periodLabel) async {
  final doc = pw.Document(theme: await pdfTheme(), title: 'Farm report');
  final logo = await pdfLogo();
  final farm = store.farm;
  final revenue = store.revenueIn(range);
  final costs = store.expenseTotalIn(range);
  final profit = revenue - costs;
  final byProduct = store.revenueByProduct(range);
  final byCat = store.expensesByCategory(range);

  pw.Widget kpi(String label, String value, {PdfColor color = _green}) => pw.Expanded(
    child: pw.Container(
      margin: const pw.EdgeInsets.only(right: 8),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(color: _tint, borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: _muted)),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: color),
          ),
        ],
      ),
    ),
  );

  pw.Widget table(List<String> headers, List<List<String>> rows) => pw.TableHelper.fromTextArray(
    headers: headers,
    data: rows,
    headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9.5),
    headerDecoration: const pw.BoxDecoration(color: _green),
    cellStyle: const pw.TextStyle(fontSize: 9.5),
    cellAlignments: {for (var i = 1; i < headers.length; i++) i: pw.Alignment.centerRight},
    oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF6F5EF)),
    border: null,
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  );

  pw.Widget heading(String t) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 18, bottom: 8),
    child: pw.Text(
      t,
      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _green),
    ),
  );

  final customers =
      store.customers
          .map((c) => (c, store.salesOf(c.id).where((s) => range.contains(s.date)).fold<double>(0, (a, s) => a + s.total)))
          .where((e) => e.$2 > 0)
          .toList()
        ..sort((a, b) => b.$2.compareTo(a.$2));

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (ctx) =>
          ctx.pageNumber == 1 ? pw.SizedBox() : pw.Text('${farm?.name ?? 'Farm'} · $periodLabel', style: const pw.TextStyle(fontSize: 8, color: _muted)),
      footer: (ctx) => pw.Row(
        children: [
          pw.Text('Generated ${Fmt.dateTime(DateTime.now())} with Shamba.', style: const pw.TextStyle(fontSize: 8, color: _muted)),
          pw.Spacer(),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: _muted)),
        ],
      ),
      build: (_) => [
        pw.Row(
          children: [
            if (logo != null) pw.Image(logo, width: 46),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    farm?.name ?? 'My Farm',
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _green),
                  ),
                  pw.Text('${farm?.location ?? ''}  ·  Farm report: $periodLabel', style: const pw.TextStyle(fontSize: 10, color: _muted)),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 18),
        pw.Row(
          children: [
            kpi('Sales', Fmt.money(revenue)),
            kpi('Costs', Fmt.money(costs), color: PdfColors.orange800),
            kpi(profit >= 0 ? 'Profit' : 'Loss', Fmt.money(profit.abs()), color: profit >= 0 ? _green : PdfColors.red700),
            kpi('Owed to you', Fmt.money(store.totalOwed), color: PdfColors.red700),
          ],
        ),
        heading('Sales by product'),
        table(
          ['Product', 'Amount', 'Share'],
          [
            for (final e in (byProduct.entries.toList()..sort((a, b) => b.value.compareTo(a.value))))
              [e.key.label, Fmt.money(e.value), revenue == 0 ? '-' : '${(e.value / revenue * 100).round()}%'],
          ],
        ),
        heading('Expenses by category'),
        table(
          ['Category', 'Amount', 'Share'],
          [
            for (final e in (byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value))))
              [e.key.label, Fmt.money(e.value), costs == 0 ? '-' : '${(e.value / costs * 100).round()}%'],
          ],
        ),
        heading('Livestock'),
        table(
          ['Measure', 'Value'],
          [
            ['Active pigs', '${store.activePigs.length}'],
            for (final e in store.pigsByStage.entries) ['  ${e.key.label}', '${e.value}'],
            ['Birds alive', Fmt.number(store.totalBirds)],
            for (final t in BirdType.values) ['  ${t.label}', Fmt.number(store.birdsOfType(t))],
            ['Good eggs collected', Fmt.number(store.eggsInRange(range))],
            ['Eggs broken', Fmt.number(store.brokenInRange(range))],
            ['Bird deaths', Fmt.number(store.deathsInRange(range))],
            ['Feed used', Fmt.kg(store.feedUsedIn(range).round())],
          ],
        ),
        if (customers.isNotEmpty) ...[
          heading('Top customers'),
          table(
            ['Customer', 'Bought', 'Owes'],
            [
              for (final (c, v) in customers.take(10)) [c.name, Fmt.money(v), Fmt.money(store.balanceOf(c.id))],
            ],
          ),
        ],
        heading('Sales register'),
        table(
          ['Receipt', 'Date', 'Item', 'Buyer', 'Total', 'Balance'],
          [
            for (final s in store.salesIn(range).take(200))
              [
                s.receiptLabel,
                Fmt.dateShort(s.date),
                '${s.quantityLabel} ${s.product.label}',
                s.customerName.isEmpty ? 'Walk-in' : s.customerName,
                Fmt.money(s.total),
                Fmt.money(s.balance),
              ],
          ],
        ),
      ],
    ),
  );
  return doc.save();
}
