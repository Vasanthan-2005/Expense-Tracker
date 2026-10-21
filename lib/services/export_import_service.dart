import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';

import '../core/database/database_helper.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/expense.dart';
import '../models/income.dart';
import 'pdf_statement_builder.dart';

class ExportImportService {
  /// Exports data to an Excel (.xlsx) file with optional year & month filtering.
  /// If [isReport] is true, generates a summary report sheet alongside transaction details.
  static Future<String?> exportToExcel({
    String? customFolderPath,
    int? targetYear,
    int? targetMonth,
    bool isReport = false,
  }) async {
    final db = DatabaseHelper.instance;
    var expenses = await db.getExpenses();
    if (targetYear != null) {
      if (targetMonth != null) {
        expenses = expenses.where((e) => e.date.year == targetYear && e.date.month == targetMonth).toList();
      } else {
        expenses = expenses.where((e) => e.date.year == targetYear).toList();
      }
    }

    final categories = await db.getCategories();
    final accounts = await db.getAccounts();

    final catMap = {for (var c in categories) c.id: c.name};
    final accMap = {for (var a in accounts) a.id: a.name};

    final excel = Excel.createExcel();
    final defaultSheetName = excel.getDefaultSheet() ?? 'Sheet1';

    double grandTotal = 0;
    final Map<String, double> catTotals = {};
    final Map<String, double> accTotals = {};

    for (final exp in expenses) {
      final catName = catMap[exp.categoryId] ?? 'Other';
      final accName = accMap[exp.accountId] ?? 'Default';
      grandTotal += exp.amountDouble;
      catTotals[catName] = (catTotals[catName] ?? 0) + exp.amountDouble;
      accTotals[accName] = (accTotals[accName] ?? 0) + exp.amountDouble;
    }

    if (isReport) {
      // Summary Report Sheet
      final summarySheet = excel['Expense Report'];
      final dateNow = DateTime.now().toIso8601String().split('T').first;
      final String periodText;
      if (targetYear != null && targetMonth != null) {
        periodText = '${_getMonthAbbr(targetMonth).toUpperCase()} $targetYear';
      } else if (targetYear != null) {
        periodText = 'YEAR $targetYear';
      } else {
        periodText = 'ALL TIME';
      }

      summarySheet.appendRow([TextCellValue('FINANCIAL EXPENSE REPORT SUMMARY')]);
      summarySheet.appendRow([TextCellValue('Period:'), TextCellValue(periodText)]);
      summarySheet.appendRow([TextCellValue('Generated Date:'), TextCellValue(dateNow)]);
      summarySheet.appendRow([TextCellValue('Total Transactions:'), IntCellValue(expenses.length)]);
      summarySheet.appendRow([TextCellValue('Grand Total (Rs.):'), DoubleCellValue(grandTotal)]);
      summarySheet.appendRow([TextCellValue('')]);

      summarySheet.appendRow([TextCellValue('CATEGORY BREAKDOWN')]);
      summarySheet.appendRow([TextCellValue('Category'), TextCellValue('Total Spent (Rs.)'), TextCellValue('Share (%)')]);
      final sortedCats = catTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in sortedCats) {
        final share = grandTotal > 0 ? (entry.value / grandTotal) * 100 : 0.0;
        summarySheet.appendRow([
          TextCellValue(entry.key),
          DoubleCellValue(entry.value),
          TextCellValue('${share.toStringAsFixed(1)}%'),
        ]);
      }
      summarySheet.appendRow([TextCellValue('')]);

      summarySheet.appendRow([TextCellValue('ACCOUNT BREAKDOWN')]);
      summarySheet.appendRow([TextCellValue('Account'), TextCellValue('Total Spent (Rs.)'), TextCellValue('Share (%)')]);
      final sortedAccs = accTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in sortedAccs) {
        final share = grandTotal > 0 ? (entry.value / grandTotal) * 100 : 0.0;
        summarySheet.appendRow([
          TextCellValue(entry.key),
          DoubleCellValue(entry.value),
          TextCellValue('${share.toStringAsFixed(1)}%'),
        ]);
      }

      // Detailed Transactions Sheet
      final txSheet = excel['Detailed Transactions'];
      txSheet.appendRow([
        TextCellValue('Date'),
        TextCellValue('Category'),
        TextCellValue('Expense'),
        TextCellValue('Amount'),
        TextCellValue('Account'),
      ]);
      for (final exp in expenses) {
        final dateStr = "${exp.date.year}-${exp.date.month.toString().padLeft(2, '0')}-${exp.date.day.toString().padLeft(2, '0')}";
        final catName = catMap[exp.categoryId] ?? 'Other';
        final accName = accMap[exp.accountId] ?? 'Default';
        txSheet.appendRow([
          TextCellValue(dateStr),
          TextCellValue(catName),
          TextCellValue(exp.note ?? ''),
          DoubleCellValue(exp.amountDouble),
          TextCellValue(accName),
        ]);
      }
      excel.delete(defaultSheetName);
    } else {
      // Expense List Sheet
      final listSheet = excel['Expense List'];
      listSheet.appendRow([
        TextCellValue('Date'),
        TextCellValue('Category'),
        TextCellValue('Expense'),
        TextCellValue('Amount'),
        TextCellValue('Account'),
      ]);

      for (final exp in expenses) {
        final dateStr = "${exp.date.year}-${exp.date.month.toString().padLeft(2, '0')}-${exp.date.day.toString().padLeft(2, '0')}";
        final catName = catMap[exp.categoryId] ?? 'Other';
        final accName = accMap[exp.accountId] ?? 'Default';

        listSheet.appendRow([
          TextCellValue(dateStr),
          TextCellValue(catName),
          TextCellValue(exp.note ?? ''),
          DoubleCellValue(exp.amountDouble),
          TextCellValue(accName),
        ]);
      }
      excel.delete(defaultSheetName);
    }

    final bytes = excel.encode();
    if (bytes == null) return null;

    final String prefix = isReport ? 'expense_report' : 'expenses';
    final String fileName;
    if (targetYear != null && targetMonth != null) {
      fileName = '${prefix}_${_getMonthAbbr(targetMonth)}_$targetYear.xlsx';
    } else if (targetYear != null) {
      fileName = '${prefix}_year_$targetYear.xlsx';
    } else {
      fileName = '${prefix}_all_time_${DateTime.now().year}.xlsx';
    }

    return await _saveAndPromptFile('xlsx', bytes, customFolderPath: customFolderPath, overrideFileName: fileName);
  }

  /// Exports data to a CSV (.csv) file.
  static Future<String?> exportToCsv({
    String? customFolderPath,
    int? targetYear,
    int? targetMonth,
  }) async {
    final db = DatabaseHelper.instance;
    var expenses = await db.getExpenses();
    if (targetYear != null) {
      if (targetMonth != null) {
        expenses = expenses.where((e) => e.date.year == targetYear && e.date.month == targetMonth).toList();
      } else {
        expenses = expenses.where((e) => e.date.year == targetYear).toList();
      }
    }

    final categories = await db.getCategories();
    final accounts = await db.getAccounts();

    final catMap = {for (var c in categories) c.id: c.name};
    final accMap = {for (var a in accounts) a.id: a.name};

    final buffer = StringBuffer();
    buffer.writeln('Date,Category,Expense,Amount,Account');

    for (final exp in expenses) {
      final dateStr = "${exp.date.year}-${exp.date.month.toString().padLeft(2, '0')}-${exp.date.day.toString().padLeft(2, '0')}";
      final catName = (catMap[exp.categoryId] ?? 'Other').replaceAll(',', ' ');
      final note = (exp.note ?? '').replaceAll(',', ' ');
      final accName = (accMap[exp.accountId] ?? 'Default').replaceAll(',', ' ');

      buffer.writeln('$dateStr,$catName,$note,${exp.amountDouble},$accName');
    }

    final bytes = utf8.encode(buffer.toString());
    final String fileName;
    if (targetYear != null && targetMonth != null) {
      fileName = 'exp_${_getMonthAbbr(targetMonth)}_$targetYear.csv';
    } else if (targetYear != null) {
      fileName = 'exp_year_$targetYear.csv';
    } else {
      fileName = 'exp_all_time_${DateTime.now().year}.csv';
    }

    return await _saveAndPromptFile('csv', bytes, customFolderPath: customFolderPath, overrideFileName: fileName);
  }

  /// Exports data to a valid PDF (.pdf) summary file.
  /// If [isReport] is true, generates a summary Financial Report PDF.
  /// If [isReport] is false, generates a detailed line-by-line Expense List PDF.
  static Future<String?> exportToPdf({
    String? customFolderPath,
    int? targetYear,
    int? targetMonth,
    bool isReport = true,
  }) async {
    final db = DatabaseHelper.instance;
    var expenses = await db.getExpenses();
    if (targetYear != null) {
      if (targetMonth != null) {
        expenses = expenses.where((e) => e.date.year == targetYear && e.date.month == targetMonth).toList();
      } else {
        expenses = expenses.where((e) => e.date.year == targetYear).toList();
      }
    }

    final categories = await db.getCategories();
    final accounts = await db.getAccounts();

    final catMap = {for (var c in categories) c.id: c.name};
    final accMap = {for (var a in accounts) a.id: a.name};

    double grandTotal = 0;
    final List<PdfStatementRecord> records = [];
    final Map<String, double> catTotals = {};
    final Map<String, double> accTotals = {};

    for (final exp in expenses) {
      final dateStr = "${exp.date.year}-${exp.date.month.toString().padLeft(2, '0')}-${exp.date.day.toString().padLeft(2, '0')}";
      final catName = catMap[exp.categoryId] ?? 'Other';
      final accName = accMap[exp.accountId] ?? 'Default';
      grandTotal += exp.amountDouble;
      catTotals[catName] = (catTotals[catName] ?? 0) + exp.amountDouble;
      accTotals[accName] = (accTotals[accName] ?? 0) + exp.amountDouble;

      records.add(PdfStatementRecord(
        date: dateStr,
        category: catName,
        note: exp.note ?? '',
        amount: exp.amountDouble.toStringAsFixed(2),
        account: accName,
        rawAmount: exp.amountDouble,
      ));
    }

    final dateNow = DateTime.now().toIso8601String().split('T').first;
    final String subtitleText;
    if (targetYear != null && targetMonth != null) {
      subtitleText = '${_getMonthAbbr(targetMonth).toUpperCase()} $targetYear';
    } else if (targetYear != null) {
      subtitleText = 'YEAR $targetYear';
    } else {
      subtitleText = 'ALL TIME';
    }

    final Uint8List pdfBytes;
    if (isReport) {
      pdfBytes = PdfStatementBuilder.buildExpenseReportPdf(
        records: records,
        grandTotalStr: grandTotal.toStringAsFixed(2),
        generatedDateStr: dateNow,
        titleSubtitle: subtitleText,
        categoryTotals: catTotals,
        accountTotals: accTotals,
      );
    } else {
      pdfBytes = PdfStatementBuilder.buildExpensePdf(
        records: records,
        grandTotalStr: grandTotal.toStringAsFixed(2),
        generatedDateStr: dateNow,
        titleSubtitle: subtitleText,
        bannerTitle: 'EXPENSE LIST STATEMENT',
      );
    }

    final String prefix = isReport ? 'expense_report' : 'expenses';
    final String fileName;
    if (targetYear != null && targetMonth != null) {
      fileName = '${prefix}_${_getMonthAbbr(targetMonth)}_$targetYear.pdf';
    } else if (targetYear != null) {
      fileName = '${prefix}_year_$targetYear.pdf';
    } else {
      fileName = '${prefix}_all_time_${DateTime.now().year}.pdf';
    }

    return await _saveAndPromptFile('pdf', pdfBytes, customFolderPath: customFolderPath, overrideFileName: fileName);
  }

  /// Exports all application data to a JSON file.
  static Future<String?> exportBackup({String? customFolderPath}) async {
    final data = await DatabaseHelper.instance.exportDataJson();
    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    final bytes = utf8.encode(jsonString);

    return await _saveAndPromptFile('json', bytes, customFolderPath: customFolderPath, overrideFileName: 'exp_backup_${DateTime.now().year}.json');
  }

  static String _getMonthAbbr(int month) {
    const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return 'mon';
  }

  /// Resolves the destination directory for exported files into Download/expense-reports.
  static Future<Directory> resolveExportDirectory([String? customFolderPath]) async {
    final rawFolder = (customFolderPath != null && customFolderPath.trim().isNotEmpty)
        ? customFolderPath.trim()
        : 'Download/expense-reports';

    // 1. If absolute path provided, use it directly
    final isAbsolute = rawFolder.startsWith('/') ||
        (rawFolder.length >= 2 && rawFolder[1] == ':') ||
        rawFolder.startsWith(r'\\');

    if (isAbsolute) {
      final dir = Directory(rawFolder);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }

    // 2. Relative path handling: strip redundant leading 'download/' or 'downloads/'
    String subPath = rawFolder;
    final lower = rawFolder.toLowerCase().replaceAll(r'\', '/');
    if (lower.startsWith('download/')) {
      subPath = rawFolder.substring(9);
    } else if (lower.startsWith('downloads/')) {
      subPath = rawFolder.substring(10);
    } else if (lower == 'download' || lower == 'downloads') {
      subPath = '';
    }

    // 3. Resolve base public Downloads folder
    Directory? baseDir;
    if (Platform.isAndroid) {
      final androidPublicDownloads = Directory('/storage/emulated/0/Download');
      if (await androidPublicDownloads.exists()) {
        baseDir = androidPublicDownloads;
      }
    }

    if (baseDir == null) {
      try {
        baseDir = await getDownloadsDirectory();
      } catch (_) {}
    }

    if (baseDir == null) {
      try {
        baseDir = await getApplicationDocumentsDirectory();
      } catch (_) {}
    }

    baseDir ??= Directory.systemTemp;

    final targetPath = (subPath.isEmpty || subPath.trim().isEmpty)
        ? baseDir.path
        : '${baseDir.path}/$subPath'.replaceAll(r'\', '/');

    final dir = Directory(targetPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<String?> _saveAndPromptFile(
    String extension,
    List<int> bytes, {
    String? customFolderPath,
    String? overrideFileName,
  }) async {
    if (kIsWeb) return null;

    final now = DateTime.now();
    final monthAbbr = _getMonthAbbr(now.month);
    final fileName = overrideFileName ?? 'expenses_${monthAbbr}_${now.year}.$extension';

    String? savedPath;

    // Save strictly to the single configured directory (Download/expense-reports)
    try {
      final exportDir = await resolveExportDirectory(customFolderPath);
      final outputPath = '${exportDir.path}/$fileName'.replaceAll(r'\', '/');
      final file = File(outputPath);
      await file.writeAsBytes(bytes, flush: true);
      savedPath = outputPath;
    } catch (e) {
      debugPrint('Export directory write failed ($e). Falling back to application documents directory.');
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        final fallbackDir = Directory('${docsDir.path}/expense-reports');
        if (!await fallbackDir.exists()) {
          await fallbackDir.create(recursive: true);
        }
        final outputPath = '${fallbackDir.path}/$fileName'.replaceAll(r'\', '/');
        final file = File(outputPath);
        await file.writeAsBytes(bytes, flush: true);
        savedPath = outputPath;
      } catch (fallbackErr) {
        debugPrint('Fallback export error: $fallbackErr');
      }
    }

    // Auto-open the exported data immediately upon export
    if (savedPath != null) {
      try {
        await OpenFilex.open(savedPath);
      } catch (openErr) {
        debugPrint('Auto-opening exported file error: $openErr');
      }
    }

    return savedPath;
  }

  /// Imports expenses and incomes from an Excel (.xlsx) or CSV (.csv) file.
  static Future<int> importExcelOrCsv({String? initialFolderPath}) async {
    String? initialDir = initialFolderPath;
    if (initialDir == null || initialDir.trim().isEmpty) {
      try {
        final dir = await resolveExportDirectory(initialFolderPath);
        initialDir = dir.path;
      } catch (_) {}
    }

    final pickedFiles = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      initialDirectory: initialDir,
    );

    if (pickedFiles.isEmpty) return 0;
    final platformFile = pickedFiles.first;

    final filePath = platformFile.path;
    if (filePath == null) return 0;

    List<int> bytes = [];
    try {
      final file = File(filePath);
      bytes = await file.readAsBytes();
    } catch (e) {
      debugPrint('Error reading file from path: $e');
    }

    if (bytes.isEmpty) {
      debugPrint('Unable to read picked file bytes.');
      return 0;
    }

    final db = DatabaseHelper.instance;
    await db.cleanupCorruptedImportData();

    final categories = await db.getCategories();
    final accounts = await db.getAccounts();
    final defaultAcc = await db.getDefaultAccount() ?? (accounts.isNotEmpty ? accounts.first : Account.defaultAccounts.first);
    final defaultCat = categories.isNotEmpty ? categories.first : Category.defaultCategories.first;

    final defaultAccId = defaultAcc.id ?? (accounts.isNotEmpty && accounts.first.id != null ? accounts.first.id : 1) ?? 1;
    final defaultCatId = defaultCat.id ?? (categories.isNotEmpty && categories.first.id != null ? categories.first.id : 1) ?? 1;

    int importedCount = 0;

    // 1. Attempt decoding as Excel (.xlsx / .xls)
    try {
      final excel = Excel.decodeBytes(bytes);
      for (final table in excel.tables.keys) {
        final sheet = excel.tables[table];
        if (sheet == null || sheet.rows.isEmpty) continue;

        // Search for header row in top 5 rows
        int headerRowIdx = -1;
        for (int r = 0; r < sheet.rows.length && r < 5; r++) {
          final rowStr = sheet.rows[r].map((cell) => _cleanCellString(cell).toLowerCase()).join(' ');
          if (rowStr.contains('date') || rowStr.contains('amount') || rowStr.contains('category') || rowStr.contains('expense')) {
            headerRowIdx = r;
            break;
          }
        }

        int dateIdx = 0;
        int categoryIdx = 1;
        int noteIdx = 2;
        int amountIdx = 3;
        int accountIdx = 4;
        int typeIdx = -1;

        if (headerRowIdx >= 0) {
          final headerRow = sheet.rows[headerRowIdx];
          final headers = headerRow.map((cell) => _cleanCellString(cell).toLowerCase()).toList();

          int dIdx = headers.indexWhere((h) => h.contains('date'));
          int aIdx = headers.indexWhere((h) => h == 'amount' || h.contains('amount') || h.contains('cost') || h.contains('price') || h.contains('val'));
          int cIdx = headers.indexWhere((h) => h.contains('category') || h.contains('cat'));
          int nIdx = headers.indexWhere((h) => h == 'expense' || h.contains('expense') || h.contains('note') || h.contains('desc') || h.contains('title') || h.contains('item') || h.contains('name') || h.contains('particular'));
          int accIdx = headers.indexWhere((h) => h.contains('account') || h.contains('acc'));
          int tIdx = headers.indexWhere((h) => h.contains('type'));

          if (dIdx >= 0) dateIdx = dIdx;
          if (cIdx >= 0) categoryIdx = cIdx;
          if (nIdx >= 0) noteIdx = nIdx;
          if (aIdx >= 0) amountIdx = aIdx;
          if (accIdx >= 0) accountIdx = accIdx;
          if (tIdx >= 0) typeIdx = tIdx;
        }

        int startRowIndex = headerRowIdx >= 0 ? headerRowIdx + 1 : 0;

        for (int i = startRowIndex; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          if (row.isEmpty) continue;

          String getCellVal(int idx) {
            if (idx >= 0 && idx < row.length) {
              final cell = row[idx];
              if (cell == null) return '';
              return _cleanCellString(cell);
            }
            return '';
          }

          String amountStr = getCellVal(amountIdx);
          double? doubleAmount = _parseAmount(amountStr, amountIdx, dateIdx);

          if (doubleAmount == null || doubleAmount <= 0) {
            for (int c = 0; c < row.length; c++) {
              if (c == dateIdx) continue;
              final candidate = _parseAmount(getCellVal(c), c, dateIdx);
              if (candidate != null && candidate > 0) {
                doubleAmount = candidate;
                break;
              }
            }
          }

          if (doubleAmount == null || doubleAmount <= 0) continue;

          final noteStr = getCellVal(noteIdx);
          final note = noteStr.isNotEmpty ? noteStr : 'Imported Expense';
          final type = getCellVal(typeIdx).toLowerCase();
          final dateStr = getCellVal(dateIdx);
          final accountStr = getCellVal(accountIdx);

          DateTime date = _parseFlexibleDate(dateStr);

          int catId = await _resolveOrCreateCategoryId(
            getCellVal(categoryIdx),
            categories,
            defaultCatId,
          );

          int accId = defaultAccId;
          if (accountStr.isNotEmpty) {
            final matchedAcc = accounts.firstWhere(
              (a) => a.name.toLowerCase() == accountStr.toLowerCase(),
              orElse: () => defaultAcc,
            );
            accId = matchedAcc.id ?? defaultAccId;
          }

          final now = DateTime.now();
          if (type.contains('inc')) {
            await db.insertIncome(Income(
              amountMinorUnits: Income.doubleToMinorUnits(doubleAmount),
              accountId: accId,
              sourceOrNote: note,
              date: date,
              timeString: '12:00',
              createdAt: now,
              updatedAt: now,
            ));
          } else {
            await db.insertExpense(Expense(
              amountMinorUnits: Expense.doubleToMinorUnits(doubleAmount),
              categoryId: catId,
              accountId: accId,
              note: note,
              date: date,
              timeString: '12:00',
              createdAt: now,
              updatedAt: now,
            ));
          }
          importedCount++;
        }
      }
    } catch (e) {
      debugPrint('Excel decoding exception, trying CSV text decoder: $e');
    }

    if (importedCount == 0) {
      importedCount = await _decodeXlsxViaXml(
        bytes,
        db,
        categories,
        defaultAccId,
        defaultCatId,
      );
    }

    if (importedCount > 0) return importedCount;

    // 2. Fallback: Attempt decoding as CSV / TSV text
    try {
      final content = utf8.decode(bytes, allowMalformed: true);
      final lines = const LineSplitter().convert(content);
      if (lines.isEmpty) return 0;

      int headerRowIdx = -1;
      for (int r = 0; r < lines.length && r < 5; r++) {
        final lineLower = lines[r].toLowerCase();
        if (lineLower.contains('date') || lineLower.contains('amount') || lineLower.contains('category') || lineLower.contains('expense')) {
          headerRowIdx = r;
          break;
        }
      }

      final checkIdx = headerRowIdx >= 0 ? headerRowIdx : 0;
      String delimiter = ',';
      final sampleLine = lines[checkIdx];
      if (sampleLine.contains('\t')) {
        delimiter = '\t';
      } else if (sampleLine.contains(';')) {
        delimiter = ';';
      }

      int dateIdx = 0;
      int categoryIdx = 1;
      int noteIdx = 2;
      int amountIdx = 3;
      int typeIdx = -1;

      if (headerRowIdx >= 0) {
        final headers = lines[headerRowIdx].split(delimiter).map((e) => e.trim().toLowerCase()).toList();

        int dIdx = headers.indexWhere((h) => h.contains('date'));
        int aIdx = headers.indexWhere((h) => h == 'amount' || h.contains('amount') || h.contains('cost') || h.contains('price') || h.contains('val'));
        int cIdx = headers.indexWhere((h) => h.contains('category') || h.contains('cat'));
        int nIdx = headers.indexWhere((h) => h == 'expense' || h.contains('expense') || h.contains('note') || h.contains('desc') || h.contains('title') || h.contains('item') || h.contains('name') || h.contains('particular'));
        int tIdx = headers.indexWhere((h) => h.contains('type'));

        if (dIdx >= 0) dateIdx = dIdx;
        if (cIdx >= 0) categoryIdx = cIdx;
        if (nIdx >= 0) noteIdx = nIdx;
        if (aIdx >= 0) amountIdx = aIdx;
        if (tIdx >= 0) typeIdx = tIdx;
      }

      int startRowIndex = headerRowIdx >= 0 ? headerRowIdx + 1 : 0;

      for (int i = startRowIndex; i < lines.length; i++) {
        final row = lines[i].split(delimiter).map((e) => e.trim()).toList();
        if (row.isEmpty || row.every((c) => c.isEmpty)) continue;

        String getCsvVal(int idx) => (idx >= 0 && idx < row.length) ? row[idx] : '';

        String amountStr = getCsvVal(amountIdx);
        double? doubleAmount = _parseAmount(amountStr, amountIdx, dateIdx);

        if (doubleAmount == null || doubleAmount <= 0) {
          for (int c = 0; c < row.length; c++) {
            if (c == dateIdx) continue;
            final candidate = _parseAmount(getCsvVal(c), c, dateIdx);
            if (candidate != null && candidate > 0) {
              doubleAmount = candidate;
              break;
            }
          }
        }

        if (doubleAmount == null || doubleAmount <= 0) continue;

        final noteStr = getCsvVal(noteIdx);
        final note = noteStr.isNotEmpty ? noteStr : 'Imported Expense';
        final type = getCsvVal(typeIdx).toLowerCase();
        final dateStr = getCsvVal(dateIdx);

        DateTime date = _parseFlexibleDate(dateStr);

        int catId = await _resolveOrCreateCategoryId(
          getCsvVal(categoryIdx),
          categories,
          defaultCatId,
        );

        final now = DateTime.now();
        if (type.contains('inc')) {
          await db.insertIncome(Income(
            amountMinorUnits: Income.doubleToMinorUnits(doubleAmount),
            accountId: defaultAccId,
            sourceOrNote: note,
            date: date,
            timeString: '12:00',
            createdAt: now,
            updatedAt: now,
          ));
        } else {
          await db.insertExpense(Expense(
            amountMinorUnits: Expense.doubleToMinorUnits(doubleAmount),
            categoryId: catId,
            accountId: defaultAccId,
            note: note,
            date: date,
            timeString: '12:00',
            createdAt: now,
            updatedAt: now,
          ));
        }
        importedCount++;
      }
    } catch (e) {
      debugPrint('CSV decoding exception: $e');
    }

    return importedCount;
  }

  static double? _parseAmount(String val, int colIndex, int dateColIndex) {
    if (colIndex == dateColIndex) return null;
    final clean = val.trim();
    if (clean.isEmpty) return null;

    if (RegExp(r'\d{1,4}[/.-]\d{1,2}[/.-]\d{1,4}').hasMatch(clean)) {
      return null;
    }

    String sanitized = clean.replaceAll(RegExp(r'[₹$€£\s]'), '').trim();

    if (sanitized.contains(',') && sanitized.contains('.')) {
      if (sanitized.lastIndexOf(',') > sanitized.lastIndexOf('.')) {
        sanitized = sanitized.replaceAll('.', '').replaceAll(',', '.');
      } else {
        sanitized = sanitized.replaceAll(',', '');
      }
    } else if (sanitized.contains(',')) {
      final parts = sanitized.split(',');
      if (parts.length == 2 && parts[1].length <= 2) {
        sanitized = sanitized.replaceAll(',', '.');
      } else {
        sanitized = sanitized.replaceAll(',', '');
      }
    }

    final double? parsed = double.tryParse(sanitized);

    if (parsed != null && parsed > 0 && parsed <= 10000000) {
      return parsed;
    }
    return null;
  }

  static String _cleanCellString(dynamic raw) {
    if (raw == null) return '';

    dynamic val = raw;
    if (raw is Data) {
      val = raw.value;
    }
    if (val == null) return '';

    if (val is num) return val.toString();
    if (val is bool) return val ? 'true' : 'false';

    if (val is IntCellValue) return val.value.toString();
    if (val is DoubleCellValue) return val.value.toString();
    if (val is DateCellValue) {
      return "${val.year.toString().padLeft(4, '0')}-${val.month.toString().padLeft(2, '0')}-${val.day.toString().padLeft(2, '0')}";
    }
    if (val is DateTimeCellValue) {
      return "${val.year.toString().padLeft(4, '0')}-${val.month.toString().padLeft(2, '0')}-${val.day.toString().padLeft(2, '0')}";
    }
    if (val is TextCellValue) {
      final dynamic textVal = val.value;
      if (textVal == null) return '';
      if (textVal is String) return textVal.trim();
      try {
        final dynamic t = (textVal as dynamic).text;
        if (t != null && t is String) return t.trim();
      } catch (_) {}
      String s = textVal.toString().trim();
      if (s.startsWith('TextSpan:')) {
        s = s.substring('TextSpan:'.length).trim();
      }
      final match = RegExp(r'(?:value:\s*|text:\s*|<|\()([^\)\,\}>]+)').firstMatch(s);
      if (match != null && match.group(1) != null) {
        s = match.group(1)!;
      }
      return s.replaceAll('"', '').replaceAll("'", '').trim();
    }
    if (val is BoolCellValue) return val.value ? 'true' : 'false';

    String s = val.toString().trim();
    final match = RegExp(r'(?:value:\s*|text:\s*|\()([^\)\,\}]+)').firstMatch(s);
    if (match != null && match.group(1) != null) {
      s = match.group(1)!;
    }
    return s.replaceAll('"', '').replaceAll("'", '').trim();
  }

  static DateTime _parseFlexibleDate(String rawDate) {
    if (rawDate.isEmpty) return DateTime.now();

    final parsed = DateTime.tryParse(rawDate);
    if (parsed != null) return parsed;

    final clean = rawDate.replaceAll(RegExp(r'[^\d/.-]'), '').trim();

    // Support Excel serial date numbers (e.g. 45658 -> 2025-01-01)
    final numVal = double.tryParse(clean);
    if (numVal != null && numVal > 30000 && numVal < 100000) {
      final epoch = DateTime(1899, 12, 30);
      final days = numVal.floor();
      final millis = ((numVal - days) * 86400000).round();
      return epoch.add(Duration(days: days, milliseconds: millis));
    }

    final parts = clean.split(RegExp(r'[/.-]'));

    if (parts.length == 3) {
      int? p1 = int.tryParse(parts[0]);
      int? p2 = int.tryParse(parts[1]);
      int? p3 = int.tryParse(parts[2]);

      if (p1 != null && p2 != null && p3 != null) {
        if (p3 >= 1000) {
          int month = p2 <= 12 ? p2 : p1;
          int day = p2 <= 12 ? p1 : p2;
          return DateTime(p3, month.clamp(1, 12), day.clamp(1, 31));
        } else if (p1 >= 1000) {
          return DateTime(p1, p2.clamp(1, 12), p3.clamp(1, 31));
        } else if (p3 < 100) {
          int year = 2000 + p3;
          int month = p2 <= 12 ? p2 : p1;
          int day = p2 <= 12 ? p1 : p2;
          return DateTime(year, month.clamp(1, 12), day.clamp(1, 31));
        }
      }
    }
    return DateTime.now();
  }

  static Future<int> _decodeXlsxViaXml(
    List<int> bytes,
    DatabaseHelper db,
    List<Category> categories,
    int defaultAccId,
    int defaultCatId,
  ) async {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final sheetFiles = archive.files.where((f) => f.name.startsWith('xl/worksheets/sheet') && f.name.endsWith('.xml')).toList();
      if (sheetFiles.isEmpty) return 0;

      // Extract shared strings if available
      List<String> sharedStrings = [];
      final sharedFile = archive.findFile('xl/sharedStrings.xml');
      if (sharedFile != null) {
        final sXml = utf8.decode(sharedFile.content as List<int>, allowMalformed: true);
        final sDoc = XmlDocument.parse(sXml);
        for (final si in sDoc.findAllElements('si')) {
          final t = si.findAllElements('t').map((e) => e.innerText).join();
          sharedStrings.add(t);
        }
      }

      int importedCount = 0;

      for (final sheetFile in sheetFiles) {
        final xmlStr = utf8.decode(sheetFile.content as List<int>, allowMalformed: true);
        final document = XmlDocument.parse(xmlStr);
        final xmlRows = document.findAllElements('row');
        if (xmlRows.isEmpty) continue;

        final List<List<String>> rows = [];
        for (final rowElem in xmlRows) {
          final cells = rowElem.findElements('c');
          final rowVals = <String>[];
          for (final c in cells) {
            final tAttr = c.getAttribute('t');
            final vElem = c.findElements('v').firstOrNull?.innerText ?? '';
            final inlineTElem = c.findAllElements('t').firstOrNull?.innerText ?? '';

            String cellVal = '';
            if (tAttr == 's' && vElem.isNotEmpty) {
              final idx = int.tryParse(vElem);
              if (idx != null && idx >= 0 && idx < sharedStrings.length) {
                cellVal = sharedStrings[idx];
              } else {
                cellVal = vElem;
              }
            } else if (tAttr == 'inlineStr' || inlineTElem.isNotEmpty) {
              cellVal = inlineTElem;
            } else {
              cellVal = vElem;
            }
            rowVals.add(cellVal);
          }
          if (rowVals.any((v) => v.isNotEmpty)) {
            rows.add(rowVals);
          }
        }

        if (rows.isEmpty) continue;

        int headerRowIdx = -1;
        for (int r = 0; r < rows.length && r < 5; r++) {
          final rowStr = rows[r].map((e) => e.toLowerCase()).join(' ');
          if (rowStr.contains('date') || rowStr.contains('amount') || rowStr.contains('category') || rowStr.contains('expense')) {
            headerRowIdx = r;
            break;
          }
        }

        int dateIdx = 0;
        int categoryIdx = 1;
        int noteIdx = 2;
        int amountIdx = 3;
        int typeIdx = -1;

        if (headerRowIdx >= 0) {
          final headers = rows[headerRowIdx].map((e) => e.toLowerCase()).toList();

          int dIdx = headers.indexWhere((h) => h.contains('date'));
          int aIdx = headers.indexWhere((h) => h == 'amount' || h.contains('amount') || h.contains('cost') || h.contains('price') || h.contains('val'));
          int cIdx = headers.indexWhere((h) => h.contains('category') || h.contains('cat'));
          int nIdx = headers.indexWhere((h) => h == 'expense' || h.contains('expense') || h.contains('note') || h.contains('desc') || h.contains('title') || h.contains('item') || h.contains('name') || h.contains('particular'));
          int tIdx = headers.indexWhere((h) => h.contains('type'));

          if (dIdx >= 0) dateIdx = dIdx;
          if (cIdx >= 0) categoryIdx = cIdx;
          if (nIdx >= 0) noteIdx = nIdx;
          if (aIdx >= 0) amountIdx = aIdx;
          if (tIdx >= 0) typeIdx = tIdx;
        }

        int startRowIndex = headerRowIdx >= 0 ? headerRowIdx + 1 : 0;

        for (int i = startRowIndex; i < rows.length; i++) {
          final row = rows[i];
          if (row.isEmpty) continue;

          String getCellVal(int idx) => (idx >= 0 && idx < row.length) ? row[idx] : '';

          String amountStr = getCellVal(amountIdx);
          double? doubleAmount = _parseAmount(amountStr, amountIdx, dateIdx);

          if (doubleAmount == null || doubleAmount <= 0) {
            for (int c = 0; c < row.length; c++) {
              if (c == dateIdx) continue;
              final candidate = _parseAmount(getCellVal(c), c, dateIdx);
              if (candidate != null && candidate > 0) {
                doubleAmount = candidate;
                break;
              }
            }
          }

          if (doubleAmount == null || doubleAmount <= 0) continue;

          final noteStr = getCellVal(noteIdx);
          final note = noteStr.isNotEmpty ? noteStr : 'Imported Expense';
          final type = getCellVal(typeIdx).toLowerCase();
          final dateStr = getCellVal(dateIdx);

          DateTime date = _parseFlexibleDate(dateStr);

          int catId = await _resolveOrCreateCategoryId(
            getCellVal(categoryIdx),
            categories,
            defaultCatId,
          );

          final now = DateTime.now();
          if (type.contains('inc')) {
            await db.insertIncome(Income(
              amountMinorUnits: Income.doubleToMinorUnits(doubleAmount),
              accountId: defaultAccId,
              sourceOrNote: note,
              date: date,
              timeString: '12:00',
              createdAt: now,
              updatedAt: now,
            ));
          } else {
            await db.insertExpense(Expense(
              amountMinorUnits: Expense.doubleToMinorUnits(doubleAmount),
              categoryId: catId,
              accountId: defaultAccId,
              note: note,
              date: date,
              timeString: '12:00',
              createdAt: now,
              updatedAt: now,
            ));
          }
          importedCount++;
        }
      }

      return importedCount;
    } catch (e) {
      debugPrint('XML fallback XLSX decoding exception: $e');
    }
    return 0;
  }

  static Future<int> _resolveOrCreateCategoryId(String rawCatName, List<Category> categories, int fallbackCatId) async {
    final trimmed = rawCatName.replaceAll(RegExp(r'[^\w\s&/-]'), '').trim();
    if (trimmed.isEmpty) return fallbackCatId;

    final normalized = trimmed.toLowerCase();

    for (final cat in categories) {
      final id = cat.id;
      if (id != null && cat.name.toLowerCase() == normalized) {
        return id;
      }
    }

    for (final cat in categories) {
      final id = cat.id;
      if (id != null && (cat.name.toLowerCase().contains(normalized) || normalized.contains(cat.name.toLowerCase()))) {
        return id;
      }
    }

    try {
      final db = DatabaseHelper.instance;
      final newCat = Category(
        name: trimmed,
        iconCodePoint: 0xe57f,
        iconFontFamily: 'MaterialIcons',
        colorValue: 0xFF6366F1,
        isDefault: false,
        createdAt: DateTime.now(),
      );
      final newId = await db.insertCategory(newCat);
      categories.add(Category(
        id: newId,
        name: trimmed,
        iconCodePoint: 0xe57f,
        iconFontFamily: 'MaterialIcons',
        colorValue: 0xFF6366F1,
        isDefault: false,
        createdAt: DateTime.now(),
      ));
      return newId;
    } catch (e) {
      debugPrint('Error auto-creating category: $e');
    }

    return fallbackCatId;
  }
}
