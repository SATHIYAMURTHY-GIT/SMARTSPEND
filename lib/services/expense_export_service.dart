import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../core/utils/formatters.dart';
import '../models/budget.dart';
import '../models/expense.dart';
import '../screens/reports/reports_screen.dart';

class ExpenseExportService {
  static const String csvHeader =
      'Date,Type,Amount,Category,Merchant,Description,Payment Method,Receipt URL';

  static const PdfColor purplePrimary = PdfColor.fromInt(0xFF7B2CBF);
  static const PdfColor purpleDark = PdfColor.fromInt(0xFF5A189A);
  static const PdfColor purpleLightBg = PdfColor.fromInt(0xFFF7F2FA);
  static const PdfColor purpleBorder = PdfColor.fromInt(0xFFE0D0F5);
  static const PdfColor purpleRowAlt = PdfColor.fromInt(0xFFFAF7FD);
  static const PdfColor textDark = PdfColor.fromInt(0xFF1E1B24);
  static const PdfColor textGray = PdfColor.fromInt(0xFF6B6575);
  static const PdfColor borderGray = PdfColor.fromInt(0xFFE8E4EE);
  static const PdfColor cardBg = PdfColor.fromInt(0xFFFBF9FD);
  static const PdfColor redDebit = PdfColor.fromInt(0xFFC62828);
  static const PdfColor greenCredit = PdfColor.fromInt(0xFF2E7D32);
  static const PdfColor orangeWarning = PdfColor.fromInt(0xFFE65100);

  static List<Expense> filterExpensesByRange(
    List<Expense> expenses,
    DateTimeRange range,
  ) {
    final start = DateTime(range.start.year, range.start.month, range.start.day);
    final end = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59, 999);

    return expenses.where((expense) {
      final date = expense.date;
      if (date == null) return false;
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList(growable: false);
  }

  static String generateCsv(List<Expense> expenses) {
    if (expenses.isEmpty) {
      return '';
    }

    final buffer = StringBuffer()..writeln(csvHeader);
    for (final expense in expenses) {
      final date = expense.date == null
          ? ''
          : DateFormat('yyyy-MM-dd').format(expense.date!);
      final type = expense.type == ExpenseType.debit ? 'Debit' : 'Credit';
      final row = [
        _csvEscape(date),
        _csvEscape(type),
        _csvEscape(formatAmountForExport(expense.amount)),
        _csvEscape(expense.category ?? ''),
        _csvEscape(expense.merchant ?? ''),
        _csvEscape(expense.description ?? ''),
        _csvEscape(expense.paymentMethod ?? ''),
        _csvEscape(expense.receiptUrl ?? ''),
      ].join(',');
      buffer.writeln(row);
    }

    return buffer.toString();
  }

  static Future<Uint8List?> _loadAssetBytes(String path) async {
    try {
      final data = await rootBundle.load(path);
      return data.buffer.asUint8List();
    } catch (_) {
      try {
        final file = File(path);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      } catch (_) {}
    }
    return null;
  }

  static Future<pw.ThemeData> _buildPdfTheme() async {
    pw.Font? regular;
    pw.Font? bold;

    final fontPairs = [
      ['assets/fonts/SegoeUI.ttf', 'assets/fonts/SegoeUI-Bold.ttf'],
      ['assets/fonts/Arial.ttf', 'assets/fonts/Arial-Bold.ttf'],
      ['assets/fonts/Roboto-Regular.ttf', 'assets/fonts/Roboto-Bold.ttf'],
    ];

    for (final pair in fontPairs) {
      try {
        final regBytes = await _loadAssetBytes(pair[0]);
        final boldBytes = await _loadAssetBytes(pair[1]);
        if (regBytes != null && boldBytes != null) {
          regular = pw.Font.ttf(regBytes.buffer.asByteData());
          bold = pw.Font.ttf(boldBytes.buffer.asByteData());
          break;
        }
      } catch (_) {}
    }

    if (regular != null && bold != null) {
      return pw.ThemeData.withFont(
        base: regular,
        bold: bold,
        italic: regular,
        boldItalic: bold,
      );
    }

    return pw.ThemeData.base();
  }

  static Future<pw.ImageProvider?> _loadLogoImage() async {
    final bytes = await _loadAssetBytes('assets/images/log.png');
    if (bytes != null && bytes.isNotEmpty) {
      return pw.MemoryImage(bytes);
    }
    return null;
  }

  static PdfColor _pdfCategoryColor(String category) {
    final color = categoryColorForKey(category);
    return PdfColor(color.r, color.g, color.b);
  }

  static String _calculateBudgetStatus(int totalDebit, MonthlyBudget? budget) {
    if (budget == null) return 'No Budget';
    final limit = budget.monthlyLimitMinorUnits;
    if (limit <= 0) return 'No Budget';
    if (totalDebit > limit) return 'Exceeded';
    if (totalDebit == limit) return 'Limit Reached';
    if (totalDebit >= (limit * 0.85).toInt()) return 'Approaching Limit';
    return 'On Track';
  }

  static PdfColor _budgetStatusColor(String status) {
    switch (status) {
      case 'Exceeded':
        return redDebit;
      case 'Limit Reached':
      case 'Approaching Limit':
        return orangeWarning;
      case 'On Track':
        return greenCredit;
      default:
        return textGray;
    }
  }

  static Future<Uint8List> generatePdfReport(
    List<Expense> expenses, {
    required DateTimeRange selectedRange,
    MonthlyBudget? budget,
  }) async {
    final filteredExpenses = filterExpensesByRange(expenses, selectedRange);
    final reportsData = ReportsData.fromExpenses(
      filteredExpenses,
      selectedRange: selectedRange,
    );

    final totalDebit = reportsData.totalDebitSpending;
    final totalCredits = reportsData.totalCredits;
    final budgetStatus = _calculateBudgetStatus(totalDebit, budget);
    final budgetStatusColor = _budgetStatusColor(budgetStatus);
    final budgetAmountLabel = budget != null
        ? formatMinorUnits(budget.monthlyLimitMinorUnits)
        : 'No budget';

    final logoImage = await _loadLogoImage();
    final themeData = await _buildPdfTheme();

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          theme: themeData,
          buildBackground: (pw.Context context) {
            if (logoImage == null) return pw.SizedBox.shrink();
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Center(
                child: pw.Opacity(
                  opacity: 0.06,
                  child: pw.Image(
                    logoImage,
                    width: 320,
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ),
            );
          },
        ),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (logoImage != null) ...[
                        pw.Image(
                          logoImage,
                          width: 42,
                          height: 42,
                          fit: pw.BoxFit.contain,
                        ),
                        pw.SizedBox(width: 10),
                      ],
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'SMARTSPEND',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: purplePrimary,
                            ),
                          ),
                          pw.Text(
                            'Financial Report',
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                          pw.Text(
                            'Expense Transfer & Management',
                            style: const pw.TextStyle(
                              fontSize: 7.5,
                              color: textGray,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Text(
                            'Period: ',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: textGray,
                            ),
                          ),
                          pw.Text(
                            '${DateFormat('dd MMM yyyy').format(selectedRange.start)} — ${DateFormat('dd MMM yyyy').format(selectedRange.end)}',
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 3),
                      pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Text(
                            'Generated On: ',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: textGray,
                            ),
                          ),
                          pw.Text(
                            DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
                            style: const pw.TextStyle(
                              fontSize: 8,
                              color: textDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Container(height: 2, color: purplePrimary),
              pw.SizedBox(height: 12),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Container(height: 0.6, color: purpleBorder),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'This is a computer-generated statement and does not require a signature.\nThank you for using SmartSpend Expense Transfer & Management.',
                    style: const pw.TextStyle(fontSize: 7, color: textGray),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: textGray,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // 4 Summary Cards
            pw.Row(
              children: [
                pw.Expanded(
                  child: _buildSummaryCard(
                    label: 'TOTAL DEBIT',
                    value: formatMinorUnits(totalDebit),
                    valueColor: redDebit,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildSummaryCard(
                    label: 'TOTAL CREDITS',
                    value: formatMinorUnits(totalCredits),
                    valueColor: greenCredit,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildSummaryCard(
                    label: 'MONTHLY BUDGET',
                    value: budgetAmountLabel,
                    valueColor: purplePrimary,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildSummaryCard(
                    label: 'BUDGET STATUS',
                    value: budgetStatus,
                    valueColor: budgetStatusColor,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // Category Breakdown Section
            pw.Text(
              'CATEGORY BREAKDOWN',
              style: pw.TextStyle(
                fontSize: 10.5,
                fontWeight: pw.FontWeight.bold,
                color: purplePrimary,
              ),
            ),
            pw.SizedBox(height: 6),
            if (reportsData.categoryBreakdown.isEmpty)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: cardBg,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  border: pw.Border.all(color: borderGray, width: 0.5),
                ),
                child: pw.Text(
                  'No debit categories for the selected period.',
                  style: const pw.TextStyle(fontSize: 8.5, color: textGray),
                ),
              )
            else
              pw.Table(
                columnWidths: const {
                  0: pw.FlexColumnWidth(1),
                  1: pw.FlexColumnWidth(1),
                },
                children: [
                  for (var i = 0; i < reportsData.categoryBreakdown.length; i += 2)
                    pw.TableRow(
                      children: [
                        _buildCategoryPill(reportsData.categoryBreakdown[i], totalDebit),
                        if (i + 1 < reportsData.categoryBreakdown.length)
                          _buildCategoryPill(reportsData.categoryBreakdown[i + 1], totalDebit)
                        else
                          pw.SizedBox.shrink(),
                      ],
                    ),
                ],
              ),
            pw.SizedBox(height: 16),

            // Transactions Section
            pw.Text(
              'TRANSACTIONS',
              style: pw.TextStyle(
                fontSize: 10.5,
                fontWeight: pw.FontWeight.bold,
                color: purplePrimary,
              ),
            ),
            pw.SizedBox(height: 6),
            if (filteredExpenses.isEmpty)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  color: cardBg,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  border: pw.Border.all(color: borderGray, width: 0.5),
                ),
                child: pw.Text(
                  'No transactions found for the selected period.',
                  style: const pw.TextStyle(fontSize: 9.5, color: textGray),
                ),
              )
            else
              pw.Table(
                border: const pw.TableBorder(
                  bottom: pw.BorderSide(color: borderGray, width: 0.5),
                  horizontalInside: pw.BorderSide(color: borderGray, width: 0.5),
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2.2),
                  1: pw.FlexColumnWidth(1.6),
                  2: pw.FlexColumnWidth(2.8),
                  3: pw.FlexColumnWidth(3.2),
                  4: pw.FlexColumnWidth(2.2),
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: purplePrimary,
                      borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(4)),
                    ),
                    children: [
                      _buildHeaderCell('Date'),
                      _buildHeaderCell('Type'),
                      _buildHeaderCell('Category'),
                      _buildHeaderCell('Merchant'),
                      _buildHeaderCell('Amount', alignRight: true),
                    ],
                  ),
                  // Table Rows
                  ...filteredExpenses.asMap().entries.map((entry) {
                    final index = entry.key;
                    final expense = entry.value;
                    final isDebit = expense.type == ExpenseType.debit;
                    final rowBg = index.isEven ? PdfColors.white : purpleRowAlt;
                    final categoryName = normalizeCategoryName(expense.category);
                    final dateStr = expense.date != null
                        ? DateFormat('dd MMM yyyy').format(expense.date!)
                        : '—';
                    final merchantStr = expense.merchant != null && expense.merchant!.trim().isNotEmpty
                        ? expense.merchant!.trim()
                        : (expense.description != null && expense.description!.trim().isNotEmpty
                            ? expense.description!.trim()
                            : '—');

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: rowBg),
                      children: [
                        _buildDataCell(dateStr),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: pw.Text(
                            isDebit ? 'Debit' : 'Credit',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: isDebit ? redDebit : greenCredit,
                            ),
                          ),
                        ),
                        _buildDataCell(categoryName.isNotEmpty ? categoryName : 'General'),
                        _buildDataCell(merchantStr),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: pw.Align(
                            alignment: pw.Alignment.centerRight,
                            child: pw.Text(
                              '${isDebit ? '-' : '+'}${formatMinorUnits(expense.amount)}',
                              style: pw.TextStyle(
                                fontSize: 8.5,
                                fontWeight: pw.FontWeight.bold,
                                color: isDebit ? redDebit : greenCredit,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
          ];
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildSummaryCard({
    required String label,
    required String value,
    PdfColor? valueColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: pw.BoxDecoration(
        color: purpleLightBg,
        border: pw.Border.all(color: purpleBorder, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 6.8,
              fontWeight: pw.FontWeight.bold,
              color: purplePrimary,
            ),
            maxLines: 1,
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: valueColor ?? textDark,
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildCategoryPill(CategoryBreakdownEntry entry, int totalDebit) {
    final percent = totalDebit <= 0
        ? '0.0%'
        : '${((entry.amount / totalDebit) * 100).toStringAsFixed(1)}%';

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2.5),
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: pw.BoxDecoration(
          color: cardBg,
          border: pw.Border.all(color: borderGray, width: 0.5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Row(
          children: [
            pw.Container(
              width: 7,
              height: 7,
              decoration: pw.BoxDecoration(
                color: _pdfCategoryColor(entry.name),
                shape: pw.BoxShape.circle,
              ),
            ),
            pw.SizedBox(width: 6),
            pw.Expanded(
              child: pw.Text(
                entry.name,
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: textDark,
                ),
                maxLines: 1,
              ),
            ),
            pw.Text(
              formatMinorUnits(entry.amount),
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: textDark,
              ),
            ),
            pw.SizedBox(width: 6),
            pw.Text(
              percent,
              style: const pw.TextStyle(
                fontSize: 7.5,
                color: textGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildHeaderCell(String text, {bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Align(
        alignment: alignRight ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
        ),
      ),
    );
  }

  static pw.Widget _buildDataCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: const pw.TextStyle(
          fontSize: 8,
          color: textDark,
        ),
        maxLines: 1,
      ),
    );
  }

  static String formatPdfAmount(int amount) {
    return formatMinorUnits(amount);
  }

  static String formatAmountForExport(int amount) {
    final abs = amount.abs();
    final rupees = abs ~/ 100;
    final paise = (abs % 100).toString().padLeft(2, '0');
    final sign = amount < 0 ? '-' : '';
    return '$sign₹$rupees.$paise';
  }

  static String _csvEscape(String value) {
    final normalized = value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final escaped = normalized.replaceAll('"', '""');
    final needsQuotes = escaped.contains(',') ||
        escaped.contains('"') ||
        escaped.contains('\n');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  static Future<void> exportToSharedFile(
    List<Expense> expenses, {
    String fileName = 'smartspend-expenses.csv',
  }) async {
    final csv = generateCsv(expenses);
    if (csv.trim().isEmpty) {
      debugPrint('SmartSpend export: no CSV content generated for ${expenses.length} expenses');
      return;
    }

    debugPrint('SmartSpend export: exporting ${expenses.length} expenses, csvLength=${csv.length}');

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    debugPrint('SmartSpend export: tempDir=${directory.path}, targetFile=${file.path}');

    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(csv, encoding: utf8, flush: true);

      final exists = await file.exists();
      final size = exists ? await file.length() : -1;
      debugPrint('SmartSpend export: fileExists=$exists, fileSize=$size, filePath=${file.path}');

      if (!exists) {
        throw StateError('Unable to create temporary CSV file for export.');
      }

      debugPrint('SmartSpend export: calling SharePlus.instance.share');
      final shareResult = await SharePlus.instance.share(
        ShareParams(
          text: 'SmartSpend expense export',
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: 'SmartSpend expense export',
        ),
      );
      debugPrint('SmartSpend export: share result status=${shareResult.status}');

      if (shareResult.status == ShareResultStatus.dismissed) {
        throw StateError('Share sheet was dismissed before the file could be exported.');
      }
    } catch (error, stackTrace) {
      debugPrint('SmartSpend export: exception=${error.runtimeType}: $error');
      debugPrintStack(stackTrace: stackTrace, label: 'SmartSpend export');
      rethrow;
    }
  }

  static Future<void> exportPdfToSharedFile(
    List<Expense> expenses, {
    required DateTimeRange selectedRange,
    MonthlyBudget? budget,
    String fileName = 'smartspend-financial-report.pdf',
  }) async {
    final pdfBytes = await generatePdfReport(
      expenses,
      selectedRange: selectedRange,
      budget: budget,
    );

    if (pdfBytes.isEmpty) {
      throw StateError('Unable to generate a PDF export for the selected range.');
    }

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(pdfBytes, flush: true);

    final exists = await file.exists();
    if (!exists) {
      throw StateError('Unable to create the temporary PDF report file.');
    }

    final shareResult = await SharePlus.instance.share(
      ShareParams(
        text: 'SmartSpend financial report',
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'SmartSpend financial report',
      ),
    );

    if (shareResult.status == ShareResultStatus.dismissed) {
      throw StateError('Share sheet was dismissed before the report could be exported.');
    }
  }
}
