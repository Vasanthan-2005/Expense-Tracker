import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/services/pdf_statement_builder.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('PdfStatementBuilder Suite', () {
    test('1. Expense List PDF generates valid single-page PDF with executive header and stat cards', () {
      final records = List.generate(
        8,
        (i) => PdfStatementRecord(
          date: '2026-10-0${i + 1}',
          category: 'Category $i',
          note: 'Note for expense #$i',
          amount: '${(i + 1) * 250}.00',
          account: 'HDFC Bank',
          rawAmount: (i + 1) * 250.0,
        ),
      );

      final pdfBytes = PdfStatementBuilder.buildExpensePdf(
        records: records,
        grandTotalStr: '9000.00',
        generatedDateStr: '2026-10-19',
        titleSubtitle: 'OCTOBER 2026',
      );

      expect(pdfBytes, isNotEmpty);
      final pdfContent = utf8.decode(pdfBytes, allowMalformed: true);

      // Verify PDF structure
      expect(pdfContent.startsWith('%PDF-1.4'), isTrue);
      expect(pdfContent.contains('%%EOF'), isTrue);
      expect(pdfContent.contains('/Type /Catalog'), isTrue);
      expect(pdfContent.contains('/Type /Pages'), isTrue);

      // Verify Branding & Content
      expect(pdfContent.contains('EXPENSE TRACKER PRO'), isTrue);
      expect(pdfContent.contains('TOTAL EXPENDITURE'), isTrue);
      expect(pdfContent.contains('TRANSACTIONS LOGGED'), isTrue);
      expect(pdfContent.contains('STATEMENT GRAND TOTAL'), isTrue);
      expect(pdfContent.contains('Rs. 9000.00'), isTrue);
      expect(pdfContent.contains('Page 1 of 1'), isTrue);
    });

    test('2. Expense List PDF handles multi-page pagination with running headers', () {
      final records = List.generate(
        60,
        (i) => PdfStatementRecord(
          date: '2026-10-${(i % 28 + 1).toString().padLeft(2, '0')}',
          category: 'Cat ${i % 5}',
          note: 'Transaction $i',
          amount: '150.00',
          account: 'Cash',
          rawAmount: 150.0,
        ),
      );

      final pdfBytes = PdfStatementBuilder.buildExpensePdf(
        records: records,
        grandTotalStr: '9000.00',
        generatedDateStr: '2026-10-19',
        titleSubtitle: 'OCTOBER 2026',
      );

      expect(pdfBytes, isNotEmpty);
      final pdfContent = utf8.decode(pdfBytes, allowMalformed: true);

      // Multi-page checks: 60 records > 22 => page 1 has 22, page 2 has 28, page 3 has 10
      expect(pdfContent.contains('/Count 3'), isTrue);
      expect(pdfContent.contains('Page 1 of 3'), isTrue);
      expect(pdfContent.contains('Page 2 of 3'), isTrue);
      expect(pdfContent.contains('Page 3 of 3'), isTrue);
      expect(pdfContent.contains('STATEMENT GRAND TOTAL'), isTrue);
    });

    test('3. Expense Report PDF generates detailed executive analytics report with visual ratio bars', () {
      final records = [
        const PdfStatementRecord(date: '2026-10-01', category: 'Groceries', note: 'Supermarket', amount: '3500.00', account: 'Salary Account', rawAmount: 3500.0),
        const PdfStatementRecord(date: '2026-10-02', category: 'Utilities', note: 'Electricity Bill', amount: '1800.00', account: 'HDFC Bank', rawAmount: 1800.0),
        const PdfStatementRecord(date: '2026-10-05', category: 'Dining Out', note: 'Weekend Dinner', amount: '2200.00', account: 'Cash', rawAmount: 2200.0),
      ];

      final pdfBytes = PdfStatementBuilder.buildExpenseReportPdf(
        records: records,
        grandTotalStr: '7500.00',
        generatedDateStr: '2026-10-19',
        titleSubtitle: 'OCTOBER 2026',
        categoryTotals: {'Groceries': 3500.0, 'Dining Out': 2200.0, 'Utilities': 1800.0},
        accountTotals: {'Salary Account': 3500.0, 'Cash': 2200.0, 'HDFC Bank': 1800.0},
      );

      expect(pdfBytes, isNotEmpty);
      final pdfContent = utf8.decode(pdfBytes, allowMalformed: true);

      expect(pdfContent.startsWith('%PDF-1.4'), isTrue);
      expect(pdfContent.contains('%%EOF'), isTrue);
      expect(pdfContent.contains('EXPENSE TRACKER PRO'), isTrue);
      expect(pdfContent.contains('FINANCIAL EXPENDITURE & ANALYTICS AUDIT REPORT'), isTrue);
      expect(pdfContent.contains('TOTAL SPENT'), isTrue);
      expect(pdfContent.contains('TOTAL ENTRIES'), isTrue);
      expect(pdfContent.contains('DAILY AVERAGE'), isTrue);
      expect(pdfContent.contains('TOP CATEGORY'), isTrue);
      expect(pdfContent.contains('Groceries'), isTrue);
      expect(pdfContent.contains('1. CATEGORY SPENDING ALLOCATION & SHARE RATIO'), isTrue);
      expect(pdfContent.contains('2. ACCOUNT & PAYMENT CHANNEL DISTRIBUTION'), isTrue);
      expect(pdfContent.contains('EXECUTIVE AUDIT SUMMARY'), isTrue);
    });

    test('4. Expense Report PDF expands to 2-page detailed report when entries > 10', () {
      final records = List.generate(
        25,
        (i) => PdfStatementRecord(
          date: '2026-10-${(i % 28 + 1).toString().padLeft(2, '0')}',
          category: 'Category ${i % 4}',
          note: 'Item $i',
          amount: '${(i + 1) * 300}.00',
          account: 'Account ${i % 2}',
          rawAmount: (i + 1) * 300.0,
        ),
      );

      final pdfBytes = PdfStatementBuilder.buildExpenseReportPdf(
        records: records,
        grandTotalStr: '97500.00',
        generatedDateStr: '2026-10-19',
        titleSubtitle: 'OCTOBER 2026',
        categoryTotals: {'Category 0': 25000.0, 'Category 1': 24000.0, 'Category 2': 24500.0, 'Category 3': 24000.0},
        accountTotals: {'Account 0': 50000.0, 'Account 1': 47500.0},
      );

      expect(pdfBytes, isNotEmpty);
      final pdfContent = utf8.decode(pdfBytes, allowMalformed: true);

      expect(pdfContent.contains('/Count 2'), isTrue);
      expect(pdfContent.contains('Page 1 of 2'), isTrue);
      expect(pdfContent.contains('Page 2 of 2'), isTrue);
      expect(pdfContent.contains('3. HIGHEST IMPACT EXPENDITURES'), isTrue);
      expect(pdfContent.contains('CONFIDENTIAL FINANCIAL AUDIT CONCLUSION'), isTrue);
    });
  });
}
