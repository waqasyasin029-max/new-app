import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../data/models.dart';
import '../state/app_state.dart';

/// Builds a one-month expense report as a PDF (always English, fully offline)
/// and opens the Android share sheet so the user can save or send it.
class ReportPdfService {
  ReportPdfService._();

  static const _orange = PdfColor.fromInt(0xFFEE6F2B);
  static const _ink = PdfColor.fromInt(0xFF16161A);
  static const _muted = PdfColor.fromInt(0xFF5E5E69);
  static const _line = PdfColor.fromInt(0xFFE9E9ED);
  static const _soft = PdfColor.fromInt(0xFFF8F8FA);
  static const _green = PdfColor.fromInt(0xFF15803D);
  static const _red = PdfColor.fromInt(0xFFC62828);

  /// Last step reached; shown in the error message to help find problems.
  static String stage = '';

  static final _numFmt = NumberFormat('#,##0');

  static String _money(num v) => 'Rs ${_numFmt.format(v.round())}';

  /// The PDF font only has Latin letters, so anything else (for example Urdu
  /// typed in a description) is replaced by a question mark instead of
  /// breaking the page.
  static String _clean(String s) {
    final b = StringBuffer();
    for (final r in s.runes) {
      final ok = (r >= 0x20 && r <= 0x24F) || (r >= 0x2010 && r <= 0x2027);
      b.write(ok ? String.fromCharCode(r) : '?');
    }
    return b.toString();
  }

  /// Creates the PDF for [month] and opens it in the phone's PDF viewer (which
  /// has its own share button). With no viewer installed it shows the share
  /// sheet instead.
  static Future<void> openMonth(AppState s, DateTime month) async {
    final file = await build(s, month);
    stage = 'open';
    final r = await OpenFilex.open(file.path, type: 'application/pdf');
    if (r.type != ResultType.done) {
      stage = 'share';
      await _share(file, month);
    }
  }

  static Future<void> _share(File file, DateTime month) async {
    final label = DateFormat('MMMM yyyy').format(month);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Kharcha report - $label',
      ),
    );
  }

  /// Creates the PDF for [month] and shows the share sheet.
  static Future<void> shareMonth(AppState s, DateTime month) async {
    final file = await build(s, month);
    stage = 'share';
    await _share(file, month);
  }

  static Future<File> build(AppState s, DateTime month) async {
    stage = 'data';
    final from = DateTime(month.year, month.month, 1);
    final to = DateTime(month.year, month.month + 1, 0);

    final salary = (await s.incomes.salaryFor(from)).amount;
    final extras = await s.incomes.extras(from);
    final otherIncome = extras.fold<double>(0, (a, e) => a + e.amount);
    final spent = await s.expenses.total(from, to);
    final cats = await s.expenses.categoryTotals(from, to);
    final daily = await s.expenses.dailyTotals(from, to);
    // list() is newest first; the report reads oldest to newest.
    final items = (await s.expenses.list(from: from, to: to)).reversed.toList();

    final income = salary + otherIncome;
    final left = income - spent;
    final now = DateTime.now();
    final isCurrent = now.year == month.year && now.month == month.month;
    final elapsed = isCurrent ? now.day : to.day;
    final perDay = elapsed > 0 ? spent / elapsed : 0.0;

    final topEntry = daily.entries.isEmpty
        ? null
        : daily.entries.reduce((a, b) => b.value > a.value ? b : a);
    final big = items.isEmpty
        ? null
        : items.reduce((a, b) => b.amount > a.amount ? b : a);

    stage = 'fonts';
    pw.Font regular;
    pw.Font bold;
    try {
      regular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Manrope-Regular.ttf'),
      );
      bold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Manrope-Bold.ttf'),
      );
    } catch (_) {
      // Built-in PDF fonts: always available, Latin letters only.
      regular = pw.Font.helvetica();
      bold = pw.Font.helveticaBold();
    }
    stage = 'layout';
    final doc = pw.Document(
      title: 'Kharcha report - ${DateFormat('MMMM yyyy').format(month)}',
      author: 'Kharcha Tracker',
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    pw.TextStyle t(
      double size, {
      bool b = false,
      PdfColor color = _ink,
    }) => pw.TextStyle(
      fontSize: size,
      fontWeight: b ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: color,
    );

    pw.Widget box(String label, String value, {PdfColor color = _ink}) =>
        pw.Expanded(
          child: pw.Container(
            margin: pw.EdgeInsets.only(right: 8),
            padding: pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: _soft,
              border: pw.Border.all(color: _line, width: 0.8),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(label, style: t(9, color: _muted)),
                pw.SizedBox(height: 4),
                pw.Text(value, style: t(13, b: true, color: color)),
              ],
            ),
          ),
        );

    pw.Widget cell(
      String text, {
      bool header = false,
      bool right = false,
      PdfColor color = _ink,
    }) => pw.Padding(
      padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
        style: header ? t(9, b: true, color: _muted) : t(9.5, color: color),
      ),
    );

    pw.Widget section(String title) => pw.Padding(
      padding: pw.EdgeInsets.only(top: 18, bottom: 8),
      child: pw.Text(title, style: t(14, b: true)),
    );

    final tableBorder = pw.TableBorder(
      horizontalInside: pw.BorderSide(color: _line, width: 0.6),
      bottom: pw.BorderSide(color: _line, width: 0.6),
    );
    final headDeco = pw.BoxDecoration(
      color: _soft,
      border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.8)),
    );

    final name = s.userName.trim();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
        footer: (ctx) => pw.Padding(
          padding: pw.EdgeInsets.only(top: 10),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Kharcha Tracker', style: t(8.5, color: _muted)),
              pw.Text(
                'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: t(8.5, color: _muted),
              ),
            ],
          ),
        ),
        build: (ctx) => [
          pw.Container(
            padding: pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              color: _orange,
              borderRadius: pw.BorderRadius.circular(14),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Monthly expense report',
                  style: t(11, color: PdfColors.white),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  DateFormat('MMMM yyyy').format(month),
                  style: t(24, b: true, color: PdfColors.white),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  '${name.isEmpty ? '' : 'Prepared for ${_clean(name)}  |  '}'
                  'Created ${DateFormat('d MMM yyyy').format(now)}',
                  style: t(9.5, color: PdfColors.white),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Row(
            children: [
              box('Monthly budget', _money(salary)),
              box('Other income', _money(otherIncome)),
              box('Spent', _money(spent), color: _red),
              box(
                left >= 0 ? 'Left' : 'Over budget',
                _money(left.abs()),
                color: left >= 0 ? _green : _red,
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            '${items.length} ${items.length == 1 ? 'expense' : 'expenses'}'
            '  |  Average ${_money(perDay)} per day'
            '${topEntry == null ? '' : '  |  Highest day: ${DateFormat('d MMM').format(DateTime.parse(topEntry.key))} (${_money(topEntry.value)})'}',
            style: t(9.5, color: _muted),
          ),
          if (big != null)
            pw.Padding(
              padding: pw.EdgeInsets.only(top: 3),
              child: pw.Text(
                'Largest expense: ${_clean(big.description.isEmpty ? (big.categoryName ?? '') : big.description)}'
                ' (${_money(big.amount)}, ${DateFormat('d MMM').format(big.date)})',
                style: t(9.5, color: _muted),
              ),
            ),
          section('Spending by category'),
          if (cats.isEmpty)
            pw.Text('No expenses recorded this month.', style: t(10, color: _muted))
          else
            pw.Table(
              border: tableBorder,
              columnWidths: {
                0: pw.FlexColumnWidth(3),
                1: pw.FixedColumnWidth(44),
                2: pw.FixedColumnWidth(80),
                3: pw.FixedColumnWidth(48),
              },
              children: [
                pw.TableRow(
                  decoration: headDeco,
                  children: [
                    cell('Category', header: true),
                    cell('Count', header: true, right: true),
                    cell('Amount', header: true, right: true),
                    cell('Share', header: true, right: true),
                  ],
                ),
                for (final c in cats)
                  pw.TableRow(
                    children: [
                      cell(_clean(c.name)),
                      cell('${c.count}', right: true),
                      cell(_money(c.total), right: true),
                      cell(
                        spent > 0
                            ? '${(c.total / spent * 100).toStringAsFixed(0)}%'
                            : '-',
                        right: true,
                      ),
                    ],
                  ),
              ],
            ),
          if (items.isNotEmpty) ...[
            section('All expenses'),
            pw.Table(
              border: tableBorder,
              columnWidths: {
                0: pw.FixedColumnWidth(48),
                1: pw.FlexColumnWidth(3),
                2: pw.FlexColumnWidth(2),
                3: pw.FlexColumnWidth(2),
                4: pw.FixedColumnWidth(70),
              },
              children: [
                pw.TableRow(
                  repeat: true,
                  decoration: headDeco,
                  children: [
                    cell('Date', header: true),
                    cell('Description', header: true),
                    cell('Category', header: true),
                    cell('Account', header: true),
                    cell('Amount', header: true, right: true),
                  ],
                ),
                for (final e in items)
                  pw.TableRow(
                    children: [
                      cell(DateFormat('d MMM').format(e.date)),
                      cell(
                        _clean(
                          e.description.isEmpty
                              ? (e.categoryName ?? '')
                              : e.description,
                        ),
                      ),
                      cell(_clean(e.categoryName ?? '')),
                      cell(_clean(e.accountName ?? '')),
                      cell(_money(e.amount), right: true),
                    ],
                  ),
                pw.TableRow(
                  decoration: headDeco,
                  children: [
                    cell(''),
                    cell('Total', header: true),
                    cell(''),
                    cell(''),
                    pw.Padding(
                      padding: pw.EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 5,
                      ),
                      child: pw.Text(
                        _money(spent),
                        textAlign: pw.TextAlign.right,
                        style: t(9.5, b: true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );

    stage = 'save';
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/Kharcha_Report_${DateFormat('yyyy-MM').format(month)}.pdf',
    );
    stage = 'render';
    final bytes = await doc.save();
    stage = 'write';
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
