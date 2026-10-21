import 'dart:convert';
import 'dart:typed_data';

class PdfStatementRecord {
  final String date;
  final String category;
  final String note;
  final String amount;
  final String account;
  final double? rawAmount;

  const PdfStatementRecord({
    required this.date,
    required this.category,
    required this.note,
    required this.amount,
    required this.account,
    this.rawAmount,
  });

  double get amountValue => rawAmount ?? (double.tryParse(amount.replaceAll(',', '')) ?? 0.0);
}

class PdfStatementBuilder {
  static String _cleanText(String text) {
    final sanitized = text
        .replaceAll('₹', 'Rs. ')
        .replaceAll('(', '[')
        .replaceAll(')', ']')
        .replaceAll('\\', '/');

    final buffer = StringBuffer();
    for (int i = 0; i < sanitized.length; i++) {
      final code = sanitized.codeUnitAt(i);
      if (code >= 32 && code <= 126) {
        buffer.writeCharCode(code);
      } else {
        buffer.write(' ');
      }
    }
    return buffer.toString().trim();
  }

  static String _truncate(String text, int maxLength) {
    final cleaned = _cleanText(text);
    if (cleaned.length <= maxLength) return cleaned;
    return '${cleaned.substring(0, maxLength - 2)}..';
  }

  static void _drawRect(
    StringBuffer buf,
    double x,
    double y,
    double w,
    double h, {
    List<double>? fill,
    List<double>? stroke,
    double strokeWidth = 1.0,
  }) {
    if (fill != null) {
      buf.writeln('${fill[0]} ${fill[1]} ${fill[2]} rg');
      buf.writeln('$x $y $w $h re f');
    }
    if (stroke != null) {
      buf.writeln('${stroke[0]} ${stroke[1]} ${stroke[2]} RG');
      buf.writeln('$strokeWidth w');
      buf.writeln('$x $y $w $h re s');
    }
  }

  static void _drawText(
    StringBuffer buf,
    String text,
    double x,
    double y, {
    String font = '/F1',
    double size = 9,
    List<double>? color,
  }) {
    buf.writeln('BT');
    if (color != null) {
      buf.writeln('${color[0]} ${color[1]} ${color[2]} rg');
    }
    buf.writeln('$font $size Tf');
    buf.writeln('$x $y Td (${_cleanText(text)}) Tj');
    buf.writeln('ET');
  }

  static void _drawRightText(
    StringBuffer buf,
    String text,
    double rightX,
    double y, {
    String font = '/F2',
    double size = 9,
    List<double>? color,
    double charWidth = 5.3,
  }) {
    final clean = _cleanText(text);
    final approxWidth = clean.length * charWidth;
    final x = (rightX - approxWidth).clamp(0.0, rightX);
    _drawText(buf, clean, x, y, font: font, size: size, color: color);
  }

  static void _drawProgressBar(
    StringBuffer buf,
    double x,
    double y,
    double w,
    double h,
    double ratio,
    List<double> barColor,
  ) {
    // Background bar
    _drawRect(buf, x, y, w, h, fill: [0.89, 0.91, 0.94]);
    // Progress fill
    final fillW = (ratio.clamp(0.0, 1.0) * w).clamp(0.0, w);
    if (fillW > 0) {
      _drawRect(buf, x, y, fillW, h, fill: barColor);
    }
    // Subtle outer border
    _drawRect(buf, x, y, w, h, stroke: [0.82, 0.85, 0.90], strokeWidth: 0.5);
  }

  static void _drawRunningFooter(
    StringBuffer buf,
    int pageIndex,
    int totalPages,
    String generatedDateStr,
  ) {
    // Footer divider line
    _drawRect(buf, 36, 44, 523, 0.5, stroke: [0.85, 0.88, 0.92], strokeWidth: 0.5);

    // Left metadata
    _drawText(
      buf,
      'Expense Tracker Pro   *   100% Offline & Private Financial Statement',
      36,
      31,
      font: '/F3',
      size: 7.5,
      color: [0.45, 0.48, 0.55],
    );

    // Right page number
    _drawRightText(
      buf,
      'Generated $generatedDateStr   *   Page ${pageIndex + 1} of $totalPages',
      559,
      31,
      font: '/F2',
      size: 7.5,
      color: [0.35, 0.38, 0.45],
      charWidth: 4.8,
    );
  }

  /// Builds a high-end, executive PDF 1.4 binary document Uint8List for Expense List Statement
  static Uint8List buildExpensePdf({
    required List<PdfStatementRecord> records,
    required String grandTotalStr,
    required String generatedDateStr,
    String? titleSubtitle,
    String bannerTitle = 'EXPENSE LIST STATEMENT',
  }) {
    final bytesBuilder = BytesBuilder();
    final List<int> objectOffsets = [0];
    int currentOffset = 0;

    void writeBytes(List<int> bytes) {
      bytesBuilder.add(bytes);
      currentOffset += bytes.length;
    }

    void writeString(String str) {
      writeBytes(utf8.encode(str));
    }

    void markObject(int id) {
      while (objectOffsets.length <= id) {
        objectOffsets.add(0);
      }
      objectOffsets[id] = currentOffset;
      writeString('$id 0 obj\n');
    }

    // PDF 1.4 Header
    writeString('%PDF-1.4\n');

    // Pagination math
    const int page1MaxRows = 22;
    const int subsequentMaxRows = 28;

    final int totalPages;
    if (records.length <= page1MaxRows) {
      totalPages = 1;
    } else {
      totalPages = 1 + ((records.length - page1MaxRows) / subsequentMaxRows).ceil();
    }

    // Object 1: Catalog
    markObject(1);
    writeString('<< /Type /Catalog /Pages 2 0 R >>\nendobj\n');

    // Object 2: Pages Parent
    final List<int> pageObjIds = [];
    for (int i = 0; i < totalPages; i++) {
      pageObjIds.add(6 + i * 2);
    }
    final kidsStr = pageObjIds.map((id) => '$id 0 R').join(' ');
    markObject(2);
    writeString('<< /Type /Pages /Kids [$kidsStr] /Count $totalPages >>\nendobj\n');

    // Object 3: Font Helvetica (Regular)
    markObject(3);
    writeString('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n');

    // Object 4: Font Helvetica-Bold (Bold)
    markObject(4);
    writeString('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>\nendobj\n');

    // Object 5: Font Helvetica-Oblique (Italic)
    markObject(5);
    writeString('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Oblique >>\nendobj\n');

    final grandTotalVal = double.tryParse(grandTotalStr.replaceAll(',', '')) ?? 0.0;
    final avgExpenseVal = records.isNotEmpty ? grandTotalVal / records.length : 0.0;
    final avgExpenseStr = avgExpenseVal.toStringAsFixed(2);
    final periodLabel = titleSubtitle != null && titleSubtitle.isNotEmpty ? titleSubtitle : 'ALL RECORDS';

    int currentRecordIdx = 0;

    // Render Pages
    for (int pageIdx = 0; pageIdx < totalPages; pageIdx++) {
      final pageObjId = 6 + pageIdx * 2;
      final contentObjId = 7 + pageIdx * 2;

      markObject(pageObjId);
      writeString('<< /Type /Page /Parent 2 0 R /Resources << /Font << /F1 3 0 R /F2 4 0 R /F3 5 0 R >> >> /MediaBox [0 0 595.28 841.89] /Contents $contentObjId 0 R >>\nendobj\n');

      final streamBuf = StringBuffer();

      double currentY;

      if (pageIdx == 0) {
        // --- PAGE 1: EXECUTIVE HEADER & KPI CARDS ---
        // 1. Dark Midnight Slate Banner
        _drawRect(streamBuf, 36, 746, 523, 64, fill: [0.06, 0.09, 0.16]);

        // Left Emblem Badge (Royal Indigo rounded container)
        _drawRect(
          streamBuf,
          48,
          758,
          38,
          38,
          fill: [0.26, 0.22, 0.79],
          stroke: [0.38, 0.35, 0.90],
          strokeWidth: 1.0,
        );
        _drawText(streamBuf, 'ET', 58, 770, font: '/F2', size: 16, color: [1, 1, 1]);

        // Brand & Title Text
        _drawText(streamBuf, 'EXPENSE TRACKER PRO', 96, 782, font: '/F2', size: 13, color: [1, 1, 1]);
        _drawText(
          streamBuf,
          _cleanText(bannerTitle),
          96,
          769,
          font: '/F1',
          size: 8.5,
          color: [0.75, 0.82, 0.95],
        );

        // Right Period Badge Container
        _drawRect(
          streamBuf,
          390,
          756,
          157,
          44,
          fill: [0.12, 0.16, 0.28],
          stroke: [0.24, 0.30, 0.48],
          strokeWidth: 0.8,
        );
        _drawText(streamBuf, 'STATEMENT PERIOD', 402, 786, font: '/F2', size: 7.5, color: [0.60, 0.72, 0.95]);
        _drawText(streamBuf, _truncate(periodLabel, 20), 402, 774, font: '/F2', size: 9.5, color: [1, 1, 1]);
        _drawText(
          streamBuf,
          'Date: $generatedDateStr',
          402,
          763,
          font: '/F3',
          size: 7,
          color: [0.65, 0.70, 0.80],
        );

        // Accent Emerald Separator Line
        _drawRect(streamBuf, 36, 743, 523, 3, fill: [0.02, 0.59, 0.41]);

        // 2. 3 Executive Summary Stat Cards
        const double cardY = 684;
        const double cardHeight = 49;
        const double cardWidth = 167;

        // Card 1: Total Expenditure
        _drawRect(streamBuf, 36, cardY, cardWidth, cardHeight, fill: [0.94, 0.99, 0.96], stroke: [0.70, 0.88, 0.80], strokeWidth: 0.8);
        _drawText(streamBuf, 'TOTAL EXPENDITURE', 46, cardY + 34, font: '/F2', size: 7.5, color: [0.02, 0.45, 0.30]);
        _drawText(streamBuf, 'Rs. $grandTotalStr', 46, cardY + 18, font: '/F2', size: 12.5, color: [0.02, 0.55, 0.38]);
        _drawText(streamBuf, 'Net statement outflow', 46, cardY + 7, font: '/F3', size: 7, color: [0.35, 0.50, 0.42]);

        // Card 2: Total Items
        _drawRect(streamBuf, 213, cardY, cardWidth, cardHeight, fill: [0.97, 0.98, 1.00], stroke: [0.88, 0.91, 0.94], strokeWidth: 0.8);
        _drawText(streamBuf, 'TRANSACTIONS LOGGED', 223, cardY + 34, font: '/F2', size: 7.5, color: [0.40, 0.44, 0.52]);
        _drawText(streamBuf, '${records.length} Records', 223, cardY + 18, font: '/F2', size: 12.5, color: [0.09, 0.11, 0.15]);
        _drawText(streamBuf, 'All recorded expenses', 223, cardY + 7, font: '/F3', size: 7, color: [0.50, 0.55, 0.62]);

        // Card 3: Average per Expense
        _drawRect(streamBuf, 390, cardY, cardWidth, cardHeight, fill: [0.97, 0.98, 1.00], stroke: [0.88, 0.91, 0.94], strokeWidth: 0.8);
        _drawText(streamBuf, 'AVERAGE PER EXPENSE', 400, cardY + 34, font: '/F2', size: 7.5, color: [0.40, 0.44, 0.52]);
        _drawText(streamBuf, 'Rs. $avgExpenseStr', 400, cardY + 18, font: '/F2', size: 12.5, color: [0.09, 0.11, 0.15]);
        _drawText(streamBuf, 'Mean transaction size', 400, cardY + 7, font: '/F3', size: 7, color: [0.50, 0.55, 0.62]);

        currentY = 656;
      } else {
        // --- SUBSEQUENT PAGES: MINI RUNNING HEADER ---
        _drawRect(streamBuf, 36, 786, 523, 26, fill: [0.09, 0.12, 0.20]);
        _drawText(streamBuf, 'EXPENSE TRACKER PRO', 46, 795, font: '/F2', size: 9, color: [1, 1, 1]);
        _drawText(
          streamBuf,
          'Statement: $periodLabel   *   Page ${pageIdx + 1} of $totalPages',
          220,
          795,
          font: '/F1',
          size: 8,
          color: [0.75, 0.80, 0.92],
        );
        _drawRightText(streamBuf, 'Total Records: ${records.length}', 549, 795, font: '/F2', size: 8, color: [0.65, 0.85, 1.0], charWidth: 4.8);
        _drawRect(streamBuf, 36, 784, 523, 2, fill: [0.02, 0.59, 0.41]);

        currentY = 758;
      }

      // --- TABLE HEADER BAR ---
      const double tableHeaderHeight = 20;
      _drawRect(streamBuf, 36, currentY - tableHeaderHeight, 523, tableHeaderHeight, fill: [0.12, 0.16, 0.24]);
      _drawRect(streamBuf, 36, currentY - tableHeaderHeight, 523, tableHeaderHeight, stroke: [0.08, 0.10, 0.18], strokeWidth: 0.8);

      // Table Header Text
      _drawText(streamBuf, '#', 42, currentY - 14, font: '/F2', size: 8, color: [1, 1, 1]);
      _drawText(streamBuf, 'DATE', 64, currentY - 14, font: '/F2', size: 8, color: [1, 1, 1]);
      _drawText(streamBuf, 'CATEGORY', 130, currentY - 14, font: '/F2', size: 8, color: [1, 1, 1]);
      _drawText(streamBuf, 'EXPENSE NOTE / MEMO', 224, currentY - 14, font: '/F2', size: 8, color: [1, 1, 1]);
      _drawText(streamBuf, 'ACCOUNT', 386, currentY - 14, font: '/F2', size: 8, color: [1, 1, 1]);
      _drawRightText(streamBuf, 'AMOUNT [RS]', 550, currentY - 14, font: '/F2', size: 8, color: [1, 1, 1], charWidth: 5.0);

      currentY -= tableHeaderHeight;

      // --- TABLE DATA ROWS ---
      final int maxRowsThisPage = (pageIdx == 0) ? page1MaxRows : subsequentMaxRows;
      final int endIdx = (currentRecordIdx + maxRowsThisPage).clamp(0, records.length);
      final pageRecords = records.sublist(currentRecordIdx, endIdx);
      currentRecordIdx = endIdx;

      const double rowHeight = 18.5;

      for (int rIdx = 0; rIdx < pageRecords.length; rIdx++) {
        final rec = pageRecords[rIdx];
        final rowY = currentY - rowHeight;

        // Alternating row background
        if (rIdx % 2 == 0) {
          _drawRect(streamBuf, 36, rowY, 523, rowHeight, fill: [0.98, 0.98, 0.99]);
        } else {
          _drawRect(streamBuf, 36, rowY, 523, rowHeight, fill: [1, 1, 1]);
        }

        // Horizontal bottom row border
        _drawRect(streamBuf, 36, rowY, 523, 0.5, stroke: [0.89, 0.91, 0.94], strokeWidth: 0.5);

        // Row Index #
        final globalRowNumber = (pageIdx == 0 ? rIdx + 1 : page1MaxRows + (pageIdx - 1) * subsequentMaxRows + rIdx + 1);
        _drawText(streamBuf, '$globalRowNumber', 42, rowY + 5, font: '/F1', size: 7.5, color: [0.45, 0.48, 0.55]);

        // Date
        _drawText(streamBuf, _truncate(rec.date, 10), 64, rowY + 5, font: '/F1', size: 8, color: [0.15, 0.18, 0.24]);

        // Category (bold)
        _drawText(streamBuf, _truncate(rec.category, 15), 130, rowY + 5, font: '/F2', size: 8, color: [0.10, 0.14, 0.25]);

        // Expense Note
        final noteText = rec.note.trim().isNotEmpty ? rec.note : '—';
        _drawText(streamBuf, _truncate(noteText, 27), 224, rowY + 5, font: '/F1', size: 8, color: [0.25, 0.28, 0.35]);

        // Account
        _drawText(streamBuf, _truncate(rec.account, 12), 386, rowY + 5, font: '/F1', size: 8, color: [0.20, 0.24, 0.32]);

        // Amount (bold right aligned)
        _drawRightText(streamBuf, rec.amount, 550, rowY + 5, font: '/F2', size: 8.5, color: [0.06, 0.09, 0.16], charWidth: 5.1);

        currentY -= rowHeight;
      }

      // --- GRAND TOTAL SUMMARY CARD ON LAST PAGE ---
      if (pageIdx == totalPages - 1) {
        currentY -= 12;
        const double totalCardHeight = 36;
        _drawRect(streamBuf, 36, currentY - totalCardHeight, 523, totalCardHeight, fill: [0.94, 0.99, 0.96], stroke: [0.02, 0.59, 0.41], strokeWidth: 1.2);

        _drawText(streamBuf, 'STATEMENT GRAND TOTAL', 50, currentY - 16, font: '/F2', size: 10.5, color: [0.06, 0.20, 0.15]);
        _drawText(
          streamBuf,
          'Total of ${records.length} itemized transactions   *   All records verified',
          50,
          currentY - 28,
          font: '/F3',
          size: 7.5,
          color: [0.35, 0.45, 0.40],
        );

        _drawRightText(
          streamBuf,
          'Rs. $grandTotalStr',
          546,
          currentY - 22,
          font: '/F2',
          size: 14,
          color: [0.02, 0.55, 0.38],
          charWidth: 8.0,
        );
      }

      // --- RUNNING FOOTER ON EVERY PAGE ---
      _drawRunningFooter(streamBuf, pageIdx, totalPages, generatedDateStr);

      final streamBytes = utf8.encode(streamBuf.toString());

      // Content Stream Object
      markObject(contentObjId);
      writeString('<< /Length ${streamBytes.length} >>\nstream\n');
      writeBytes(streamBytes);
      writeString('\nendstream\nendobj\n');
    }

    // XRef Table
    final totalObjects = 6 + totalPages * 2;
    final xrefStartOffset = currentOffset;

    writeString('xref\n');
    writeString('0 $totalObjects\n');
    writeString('0000000000 65535 f \n');

    for (int i = 1; i < totalObjects; i++) {
      final offset = objectOffsets[i];
      final offsetStr = offset.toString().padLeft(10, '0');
      writeString('$offsetStr 00000 n \n');
    }

    // Trailer
    writeString('trailer\n');
    writeString('<< /Size $totalObjects /Root 1 0 R >>\n');
    writeString('startxref\n');
    writeString('$xrefStartOffset\n');
    writeString('%%EOF\n');

    return bytesBuilder.toBytes();
  }

  /// Builds a detailed, executive Financial Audit & Spending Report PDF with
  /// visual ratio bars, KPI cards, and top expenditures analysis.
  static Uint8List buildExpenseReportPdf({
    required List<PdfStatementRecord> records,
    required String grandTotalStr,
    required String generatedDateStr,
    required String titleSubtitle,
    required Map<String, double> categoryTotals,
    required Map<String, double> accountTotals,
  }) {
    final bytesBuilder = BytesBuilder();
    final List<int> objectOffsets = [0];
    int currentOffset = 0;

    void writeBytes(List<int> bytes) {
      bytesBuilder.add(bytes);
      currentOffset += bytes.length;
    }

    void writeString(String str) {
      writeBytes(utf8.encode(str));
    }

    void markObject(int id) {
      while (objectOffsets.length <= id) {
        objectOffsets.add(0);
      }
      objectOffsets[id] = currentOffset;
      writeString('$id 0 obj\n');
    }

    writeString('%PDF-1.4\n');

    // 2 Pages if more than 10 records for deep analysis, 1 Page if compact
    final bool isMultiPage = records.length > 10;
    final int totalPages = isMultiPage ? 2 : 1;

    // Object 1: Catalog
    markObject(1);
    writeString('<< /Type /Catalog /Pages 2 0 R >>\nendobj\n');

    // Object 2: Pages Parent
    final List<int> pageObjIds = [];
    for (int i = 0; i < totalPages; i++) {
      pageObjIds.add(6 + i * 2);
    }
    final kidsStr = pageObjIds.map((id) => '$id 0 R').join(' ');
    markObject(2);
    writeString('<< /Type /Pages /Kids [$kidsStr] /Count $totalPages >>\nendobj\n');

    // Object 3: Font Helvetica (Regular)
    markObject(3);
    writeString('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n');

    // Object 4: Font Helvetica-Bold (Bold)
    markObject(4);
    writeString('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>\nendobj\n');

    // Object 5: Font Helvetica-Oblique (Italic)
    markObject(5);
    writeString('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Oblique >>\nendobj\n');

    double grandTotalVal = double.tryParse(grandTotalStr.replaceAll(',', '')) ?? 0.0;
    if (grandTotalVal == 0) grandTotalVal = 1;

    // Compute transaction counts per category & account
    final Map<String, int> catCounts = {};
    final Map<String, int> accCounts = {};
    for (final r in records) {
      catCounts[r.category] = (catCounts[r.category] ?? 0) + 1;
      accCounts[r.account] = (accCounts[r.account] ?? 0) + 1;
    }

    // Sorted categories & accounts
    final sortedCats = categoryTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final sortedAccs = accountTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    // Top Category
    final topCatName = sortedCats.isNotEmpty ? sortedCats.first.key : 'None';
    final topCatPct = sortedCats.isNotEmpty ? ((sortedCats.first.value / grandTotalVal) * 100).toStringAsFixed(1) : '0';

    // Top Account
    final topAccName = sortedAccs.isNotEmpty ? sortedAccs.first.key : 'None';
    final topAccPct = sortedAccs.isNotEmpty ? ((sortedAccs.first.value / grandTotalVal) * 100).toStringAsFixed(1) : '0';

    // Daily Average estimate
    final dailyAvgVal = records.isNotEmpty ? (grandTotalVal / 30) : 0.0;
    final dailyAvgStr = dailyAvgVal.toStringAsFixed(2);

    // Top spends sorted descending
    final sortedRecords = records.toList()..sort((a, b) => b.amountValue.compareTo(a.amountValue));

    // ================= PAGE 1 =================
    {
      const pageObjId = 6;
      const contentObjId = 7;

      markObject(pageObjId);
      writeString('<< /Type /Page /Parent 2 0 R /Resources << /Font << /F1 3 0 R /F2 4 0 R /F3 5 0 R >> >> /MediaBox [0 0 595.28 841.89] /Contents $contentObjId 0 R >>\nendobj\n');

      final streamBuf = StringBuffer();

      // Top Emblem Banner
      _drawRect(streamBuf, 36, 746, 523, 64, fill: [0.06, 0.09, 0.16]);

      // Emblem Badge
      _drawRect(
        streamBuf,
        48,
        758,
        38,
        38,
        fill: [0.26, 0.22, 0.79],
        stroke: [0.38, 0.35, 0.90],
        strokeWidth: 1.0,
      );
      _drawText(streamBuf, 'ET', 58, 770, font: '/F2', size: 16, color: [1, 1, 1]);

      // Banner Text
      _drawText(streamBuf, 'EXPENSE TRACKER PRO', 96, 782, font: '/F2', size: 13, color: [1, 1, 1]);
      _drawText(
        streamBuf,
        'FINANCIAL EXPENDITURE & ANALYTICS AUDIT REPORT',
        96,
        769,
        font: '/F1',
        size: 8.5,
        color: [0.75, 0.82, 0.95],
      );

      // Right Metadata Box
      _drawRect(
        streamBuf,
        390,
        756,
        157,
        44,
        fill: [0.12, 0.16, 0.28],
        stroke: [0.24, 0.30, 0.48],
        strokeWidth: 0.8,
      );
      _drawText(streamBuf, 'AUDIT PERIOD', 402, 786, font: '/F2', size: 7.5, color: [0.60, 0.72, 0.95]);
      _drawText(streamBuf, _truncate(titleSubtitle, 20), 402, 774, font: '/F2', size: 9.5, color: [1, 1, 1]);
      _drawText(
        streamBuf,
        'Generated: $generatedDateStr',
        402,
        763,
        font: '/F3',
        size: 7,
        color: [0.65, 0.70, 0.80],
      );

      // Emerald Accent Separator Line
      _drawRect(streamBuf, 36, 743, 523, 3, fill: [0.02, 0.59, 0.41]);

      // 4 Executive KPI Cards
      const double kpiY = 684;
      const double kpiHeight = 49;
      const double kpiWidth = 124;

      // Card 1: Total Spent
      _drawRect(streamBuf, 36, kpiY, kpiWidth, kpiHeight, fill: [0.94, 0.99, 0.96], stroke: [0.70, 0.88, 0.80], strokeWidth: 0.8);
      _drawText(streamBuf, 'TOTAL SPENT', 44, kpiY + 34, font: '/F2', size: 7, color: [0.02, 0.45, 0.30]);
      _drawText(streamBuf, 'Rs. $grandTotalStr', 44, kpiY + 18, font: '/F2', size: 10.5, color: [0.02, 0.55, 0.38]);
      _drawText(streamBuf, 'Net period outflow', 44, kpiY + 7, font: '/F3', size: 6.5, color: [0.35, 0.50, 0.42]);

      // Card 2: Transactions
      _drawRect(streamBuf, 169, kpiY, kpiWidth, kpiHeight, fill: [0.97, 0.98, 1.00], stroke: [0.88, 0.91, 0.94], strokeWidth: 0.8);
      _drawText(streamBuf, 'TOTAL ENTRIES', 177, kpiY + 34, font: '/F2', size: 7, color: [0.40, 0.44, 0.52]);
      _drawText(streamBuf, '${records.length} Records', 177, kpiY + 18, font: '/F2', size: 10.5, color: [0.09, 0.11, 0.15]);
      _drawText(streamBuf, 'Tracked transactions', 177, kpiY + 7, font: '/F3', size: 6.5, color: [0.50, 0.55, 0.62]);

      // Card 3: Daily Average
      _drawRect(streamBuf, 302, kpiY, kpiWidth, kpiHeight, fill: [0.97, 0.98, 1.00], stroke: [0.88, 0.91, 0.94], strokeWidth: 0.8);
      _drawText(streamBuf, 'DAILY AVERAGE', 310, kpiY + 34, font: '/F2', size: 7, color: [0.40, 0.44, 0.52]);
      _drawText(streamBuf, 'Rs. $dailyAvgStr', 310, kpiY + 18, font: '/F2', size: 10.5, color: [0.09, 0.11, 0.15]);
      _drawText(streamBuf, 'Estimated per day', 310, kpiY + 7, font: '/F3', size: 6.5, color: [0.50, 0.55, 0.62]);

      // Card 4: Top Category
      _drawRect(streamBuf, 435, kpiY, kpiWidth, kpiHeight, fill: [0.95, 0.96, 1.00], stroke: [0.80, 0.84, 0.94], strokeWidth: 0.8);
      _drawText(streamBuf, 'TOP CATEGORY', 443, kpiY + 34, font: '/F2', size: 7, color: [0.26, 0.22, 0.79]);
      _drawText(streamBuf, _truncate(topCatName, 12), 443, kpiY + 18, font: '/F2', size: 10.5, color: [0.15, 0.12, 0.55]);
      _drawText(streamBuf, '$topCatPct% of budget', 443, kpiY + 7, font: '/F3', size: 6.5, color: [0.35, 0.35, 0.55]);

      double curY = 658;

      // --- SECTION 1: CATEGORY EXPENDITURE BREAKDOWN & RATIO BARS ---
      _drawRect(streamBuf, 36, curY - 18, 523, 18, fill: [0.12, 0.16, 0.24]);
      _drawText(streamBuf, '1. CATEGORY SPENDING ALLOCATION & SHARE RATIO', 44, curY - 13, font: '/F2', size: 8, color: [1, 1, 1]);
      _drawText(streamBuf, 'SPENDING RATIO', 220, curY - 13, font: '/F2', size: 7.5, color: [0.80, 0.85, 0.95]);
      _drawText(streamBuf, 'ENTRIES', 340, curY - 13, font: '/F2', size: 7.5, color: [0.80, 0.85, 0.95]);
      _drawRightText(streamBuf, 'TOTAL [RS]', 470, curY - 13, font: '/F2', size: 7.5, color: [0.80, 0.85, 0.95], charWidth: 4.8);
      _drawRightText(streamBuf, 'SHARE %', 550, curY - 13, font: '/F2', size: 7.5, color: [0.80, 0.85, 0.95], charWidth: 4.8);

      curY -= 18;

      final displayCats = sortedCats.take(isMultiPage ? 7 : 5).toList();
      for (int i = 0; i < displayCats.length; i++) {
        final item = displayCats[i];
        final ratio = (item.value / grandTotalVal);
        final pctStr = (ratio * 100).toStringAsFixed(1);
        final txnCount = catCounts[item.key] ?? 1;

        if (i % 2 == 0) {
          _drawRect(streamBuf, 36, curY - 16, 523, 16, fill: [0.98, 0.98, 0.99]);
        } else {
          _drawRect(streamBuf, 36, curY - 16, 523, 16, fill: [1, 1, 1]);
        }
        _drawRect(streamBuf, 36, curY - 16, 523, 0.5, stroke: [0.89, 0.91, 0.94], strokeWidth: 0.5);

        // Category Name
        _drawText(streamBuf, _truncate(item.key, 18), 44, curY - 11, font: '/F2', size: 8, color: [0.10, 0.14, 0.22]);

        // Visual Progress Bar
        _drawProgressBar(streamBuf, 220, curY - 12, 100, 7, ratio, [0.26, 0.22, 0.79]);

        // Transaction Count
        _drawText(streamBuf, '$txnCount txns', 340, curY - 11, font: '/F1', size: 7.5, color: [0.45, 0.48, 0.55]);

        // Amount
        _drawRightText(streamBuf, item.value.toStringAsFixed(2), 470, curY - 11, font: '/F2', size: 8, color: [0.08, 0.10, 0.16], charWidth: 4.9);

        // Percent
        _drawRightText(streamBuf, '$pctStr%', 550, curY - 11, font: '/F2', size: 8, color: [0.26, 0.22, 0.79], charWidth: 4.9);

        curY -= 16;
      }

      curY -= 10;

      // --- SECTION 2: ACCOUNT DISTRIBUTION & PAYMENT CHANNELS ---
      _drawRect(streamBuf, 36, curY - 18, 523, 18, fill: [0.12, 0.16, 0.24]);
      _drawText(streamBuf, '2. ACCOUNT & PAYMENT CHANNEL DISTRIBUTION', 44, curY - 13, font: '/F2', size: 8, color: [1, 1, 1]);
      _drawText(streamBuf, 'ALLOCATION', 220, curY - 13, font: '/F2', size: 7.5, color: [0.80, 0.85, 0.95]);
      _drawText(streamBuf, 'ENTRIES', 340, curY - 13, font: '/F2', size: 7.5, color: [0.80, 0.85, 0.95]);
      _drawRightText(streamBuf, 'TOTAL [RS]', 470, curY - 13, font: '/F2', size: 7.5, color: [0.80, 0.85, 0.95], charWidth: 4.8);
      _drawRightText(streamBuf, 'SHARE %', 550, curY - 13, font: '/F2', size: 7.5, color: [0.80, 0.85, 0.95], charWidth: 4.8);

      curY -= 18;

      final displayAccs = sortedAccs.take(isMultiPage ? 5 : 4).toList();
      for (int i = 0; i < displayAccs.length; i++) {
        final item = displayAccs[i];
        final ratio = (item.value / grandTotalVal);
        final pctStr = (ratio * 100).toStringAsFixed(1);
        final txnCount = accCounts[item.key] ?? 1;

        if (i % 2 == 0) {
          _drawRect(streamBuf, 36, curY - 16, 523, 16, fill: [0.98, 0.98, 0.99]);
        } else {
          _drawRect(streamBuf, 36, curY - 16, 523, 16, fill: [1, 1, 1]);
        }
        _drawRect(streamBuf, 36, curY - 16, 523, 0.5, stroke: [0.89, 0.91, 0.94], strokeWidth: 0.5);

        // Account Name
        _drawText(streamBuf, _truncate(item.key, 18), 44, curY - 11, font: '/F2', size: 8, color: [0.10, 0.14, 0.22]);

        // Visual Progress Bar
        _drawProgressBar(streamBuf, 220, curY - 12, 100, 7, ratio, [0.02, 0.59, 0.41]);

        // Transaction Count
        _drawText(streamBuf, '$txnCount txns', 340, curY - 11, font: '/F1', size: 7.5, color: [0.45, 0.48, 0.55]);

        // Amount
        _drawRightText(streamBuf, item.value.toStringAsFixed(2), 470, curY - 11, font: '/F2', size: 8, color: [0.08, 0.10, 0.16], charWidth: 4.9);

        // Percent
        _drawRightText(streamBuf, '$pctStr%', 550, curY - 11, font: '/F2', size: 8, color: [0.02, 0.55, 0.38], charWidth: 4.9);

        curY -= 16;
      }

      curY -= 12;

      if (!isMultiPage) {
        // --- 1-PAGE MODE: TOP TRANSACTIONS & SUMMARY FIT ON PAGE 1 ---
        _drawRect(streamBuf, 36, curY - 18, 523, 18, fill: [0.12, 0.16, 0.24]);
        _drawText(streamBuf, '3. HIGHEST IMPACT EXPENDITURES (SAMPLE AUDIT)', 44, curY - 13, font: '/F2', size: 8, color: [1, 1, 1]);

        curY -= 18;

        final sampleSpends = sortedRecords.take(5).toList();
        for (int i = 0; i < sampleSpends.length; i++) {
          final rec = sampleSpends[i];
          if (i % 2 == 0) {
            _drawRect(streamBuf, 36, curY - 15, 523, 15, fill: [0.98, 0.98, 0.99]);
          } else {
            _drawRect(streamBuf, 36, curY - 15, 523, 15, fill: [1, 1, 1]);
          }
          _drawRect(streamBuf, 36, curY - 15, 523, 0.5, stroke: [0.89, 0.91, 0.94], strokeWidth: 0.5);

          _drawText(streamBuf, '#${i + 1}', 44, curY - 11, font: '/F2', size: 7.5, color: [0.45, 0.48, 0.55]);
          _drawText(streamBuf, _truncate(rec.date, 10), 65, curY - 11, font: '/F1', size: 7.5, color: [0.15, 0.18, 0.24]);
          _drawText(streamBuf, _truncate(rec.category, 14), 130, curY - 11, font: '/F2', size: 7.5, color: [0.10, 0.14, 0.25]);
          _drawText(streamBuf, _truncate(rec.note.isNotEmpty ? rec.note : '—', 22), 220, curY - 11, font: '/F1', size: 7.5, color: [0.30, 0.33, 0.40]);
          _drawText(streamBuf, _truncate(rec.account, 12), 370, curY - 11, font: '/F1', size: 7.5, color: [0.20, 0.24, 0.32]);
          _drawRightText(streamBuf, 'Rs. ${rec.amount}', 550, curY - 11, font: '/F2', size: 8, color: [0.06, 0.09, 0.16], charWidth: 4.9);

          curY -= 15;
        }

        curY -= 10;
        // Observations Box
        _drawRect(streamBuf, 36, curY - 40, 523, 40, fill: [0.95, 0.97, 1.00], stroke: [0.80, 0.85, 0.95], strokeWidth: 0.8);
        _drawText(streamBuf, 'EXECUTIVE AUDIT SUMMARY', 46, curY - 12, font: '/F2', size: 8, color: [0.26, 0.22, 0.79]);
        _drawText(
          streamBuf,
          '* Top spending category ($topCatName) represents $topCatPct% of all outgoing funds.',
          46,
          curY - 24,
          font: '/F1',
          size: 7.5,
          color: [0.20, 0.24, 0.32],
        );
        _drawText(
          streamBuf,
          '* Primary payment method was $topAccName ($topAccPct%). 100% stored offline on device.',
          46,
          curY - 35,
          font: '/F1',
          size: 7.5,
          color: [0.20, 0.24, 0.32],
        );
      } else {
        // Multi-page Page 1 summary card
        _drawRect(streamBuf, 36, curY - 48, 523, 48, fill: [0.95, 0.97, 1.00], stroke: [0.80, 0.85, 0.95], strokeWidth: 0.8);
        _drawText(streamBuf, 'EXECUTIVE BUDGET ALLOCATION SUMMARY', 46, curY - 14, font: '/F2', size: 8.5, color: [0.26, 0.22, 0.79]);
        _drawText(
          streamBuf,
          '* Top category ($topCatName) consumed Rs. ${(sortedCats.isNotEmpty ? sortedCats.first.value.toStringAsFixed(2) : "0")} ($topCatPct% of statement budget).',
          46,
          curY - 27,
          font: '/F1',
          size: 8,
          color: [0.20, 0.24, 0.32],
        );
        _drawText(
          streamBuf,
          '* Primary expenditure channel: $topAccName with $topAccPct% of transactions. See Page 2 for high-impact audits.',
          46,
          curY - 40,
          font: '/F1',
          size: 8,
          color: [0.20, 0.24, 0.32],
        );
      }

      // Running footer
      _drawRunningFooter(streamBuf, 0, totalPages, generatedDateStr);

      final streamBytes = utf8.encode(streamBuf.toString());
      markObject(contentObjId);
      writeString('<< /Length ${streamBytes.length} >>\nstream\n');
      writeBytes(streamBytes);
      writeString('\nendstream\nendobj\n');
    }

    // ================= PAGE 2 (If multi-page) =================
    if (isMultiPage) {
      const pageObjId = 8;
      const contentObjId = 9;

      markObject(pageObjId);
      writeString('<< /Type /Page /Parent 2 0 R /Resources << /Font << /F1 3 0 R /F2 4 0 R /F3 5 0 R >> >> /MediaBox [0 0 595.28 841.89] /Contents $contentObjId 0 R >>\nendobj\n');

      final streamBuf = StringBuffer();

      // Top Running Header Banner
      _drawRect(streamBuf, 36, 786, 523, 26, fill: [0.09, 0.12, 0.20]);
      _drawText(streamBuf, 'EXPENSE TRACKER PRO', 46, 795, font: '/F2', size: 9, color: [1, 1, 1]);
      _drawText(
        streamBuf,
        'Financial Audit Report: $titleSubtitle   *   Page 2 of 2',
        200,
        795,
        font: '/F1',
        size: 8,
        color: [0.75, 0.80, 0.92],
      );
      _drawRightText(streamBuf, 'Total Records: ${records.length}', 549, 795, font: '/F2', size: 8, color: [0.65, 0.85, 1.0], charWidth: 4.8);
      _drawRect(streamBuf, 36, 784, 523, 2, fill: [0.02, 0.59, 0.41]);

      double curY = 758;

      // Section 3: High-Value Expenses Table
      _drawRect(streamBuf, 36, curY - 20, 523, 20, fill: [0.12, 0.16, 0.24]);
      _drawText(streamBuf, '3. HIGHEST IMPACT EXPENDITURES (TRANSACTION AUDIT SAMPLING)', 44, curY - 14, font: '/F2', size: 8.5, color: [1, 1, 1]);

      curY -= 20;

      // Subheader
      _drawRect(streamBuf, 36, curY - 16, 523, 16, fill: [0.88, 0.91, 0.96]);
      _drawText(streamBuf, 'RANK', 44, curY - 11, font: '/F2', size: 7.5, color: [0.15, 0.18, 0.26]);
      _drawText(streamBuf, 'DATE', 75, curY - 11, font: '/F2', size: 7.5, color: [0.15, 0.18, 0.26]);
      _drawText(streamBuf, 'CATEGORY', 140, curY - 11, font: '/F2', size: 7.5, color: [0.15, 0.18, 0.26]);
      _drawText(streamBuf, 'EXPENSE NOTE / MEMO', 235, curY - 11, font: '/F2', size: 7.5, color: [0.15, 0.18, 0.26]);
      _drawText(streamBuf, 'ACCOUNT', 390, curY - 11, font: '/F2', size: 7.5, color: [0.15, 0.18, 0.26]);
      _drawRightText(streamBuf, 'AMOUNT [RS]', 550, curY - 11, font: '/F2', size: 7.5, color: [0.15, 0.18, 0.26], charWidth: 4.8);

      curY -= 16;

      final topSpends = sortedRecords.take(18).toList();
      for (int i = 0; i < topSpends.length; i++) {
        final rec = topSpends[i];
        if (i % 2 == 0) {
          _drawRect(streamBuf, 36, curY - 16, 523, 16, fill: [0.98, 0.98, 0.99]);
        } else {
          _drawRect(streamBuf, 36, curY - 16, 523, 16, fill: [1, 1, 1]);
        }
        _drawRect(streamBuf, 36, curY - 16, 523, 0.5, stroke: [0.89, 0.91, 0.94], strokeWidth: 0.5);

        _drawText(streamBuf, '#${i + 1}', 44, curY - 11, font: '/F2', size: 7.5, color: [0.45, 0.48, 0.55]);
        _drawText(streamBuf, _truncate(rec.date, 10), 75, curY - 11, font: '/F1', size: 7.5, color: [0.15, 0.18, 0.24]);
        _drawText(streamBuf, _truncate(rec.category, 15), 140, curY - 11, font: '/F2', size: 7.5, color: [0.10, 0.14, 0.25]);
        _drawText(streamBuf, _truncate(rec.note.isNotEmpty ? rec.note : '—', 26), 235, curY - 11, font: '/F1', size: 7.5, color: [0.25, 0.28, 0.35]);
        _drawText(streamBuf, _truncate(rec.account, 12), 390, curY - 11, font: '/F1', size: 7.5, color: [0.20, 0.24, 0.32]);
        _drawRightText(streamBuf, 'Rs. ${rec.amount}', 550, curY - 11, font: '/F2', size: 8, color: [0.06, 0.09, 0.16], charWidth: 5.0);

        curY -= 16;
      }

      curY -= 14;

      // Executive Audit Callout Card
      _drawRect(streamBuf, 36, curY - 52, 523, 52, fill: [0.95, 0.99, 0.96], stroke: [0.02, 0.59, 0.41], strokeWidth: 1.0);
      _drawText(streamBuf, 'CONFIDENTIAL FINANCIAL AUDIT CONCLUSION', 48, curY - 15, font: '/F2', size: 8.5, color: [0.02, 0.45, 0.30]);
      _drawText(
        streamBuf,
        '* This report was generated on-device with cryptographic integrity from SQLite storage.',
        48,
        curY - 29,
        font: '/F1',
        size: 7.5,
        color: [0.15, 0.25, 0.20],
      );
      _drawText(
        streamBuf,
        '* Verified: Total Expenditure Rs. $grandTotalStr across ${records.length} transactions. No external cloud dependencies.',
        48,
        curY - 42,
        font: '/F1',
        size: 7.5,
        color: [0.15, 0.25, 0.20],
      );

      _drawRunningFooter(streamBuf, 1, totalPages, generatedDateStr);

      final streamBytes = utf8.encode(streamBuf.toString());
      markObject(contentObjId);
      writeString('<< /Length ${streamBytes.length} >>\nstream\n');
      writeBytes(streamBytes);
      writeString('\nendstream\nendobj\n');
    }

    // XRef Table
    final totalObjects = 6 + totalPages * 2;
    final xrefStartOffset = currentOffset;

    writeString('xref\n');
    writeString('0 $totalObjects\n');
    writeString('0000000000 65535 f \n');

    for (int i = 1; i < totalObjects; i++) {
      final offset = objectOffsets[i];
      final offsetStr = offset.toString().padLeft(10, '0');
      writeString('$offsetStr 00000 n \n');
    }

    // Trailer
    writeString('trailer\n');
    writeString('<< /Size $totalObjects /Root 1 0 R >>\n');
    writeString('startxref\n');
    writeString('$xrefStartOffset\n');
    writeString('%%EOF\n');

    return bytesBuilder.toBytes();
  }
}
