import 'dart:convert';
import 'dart:typed_data';

class PdfStatementRecord {
  final String date;
  final String category;
  final String note;
  final String amount;
  final String account;

  const PdfStatementRecord({
    required this.date,
    required this.category,
    required this.note,
    required this.amount,
    required this.account,
  });
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

  /// Builds a colorful, professional PDF 1.4 binary document Uint8List with crisp grid tables
  static Uint8List buildExpensePdf({
    required List<PdfStatementRecord> records,
    required String grandTotalStr,
    required String generatedDateStr,
    String? titleSubtitle,
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

    // PDF Header
    writeString('%PDF-1.4\n');

    const int itemsPerPage = 22;
    final int totalPages = (records.length / itemsPerPage).ceil().clamp(1, 999);

    // Object 1: Catalog
    markObject(1);
    writeString('<< /Type /Catalog /Pages 2 0 R >>\nendobj\n');

    // Object 2: Pages Parent
    final List<int> pageObjIds = [];
    for (int i = 0; i < totalPages; i++) {
      pageObjIds.add(5 + i * 2);
    }
    final kidsStr = pageObjIds.map((id) => '$id 0 R').join(' ');
    markObject(2);
    writeString('<< /Type /Pages /Kids [$kidsStr] /Count $totalPages >>\nendobj\n');

    // Object 3: Font Helvetica
    markObject(3);
    writeString('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n');

    // Object 4: Font Helvetica-Bold
    markObject(4);
    writeString('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>\nendobj\n');

    // Build Pages & Content Streams
    for (int pageIdx = 0; pageIdx < totalPages; pageIdx++) {
      final pageObjId = 5 + pageIdx * 2;
      final contentObjId = 6 + pageIdx * 2;

      markObject(pageObjId);
      writeString('<< /Type /Page /Parent 2 0 R /Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> /MediaBox [0 0 595.28 841.89] /Contents $contentObjId 0 R >>\nendobj\n');

      final streamBuf = StringBuffer();

      // 1. Top Indigo Banner Block (Full-width header)
      streamBuf.writeln('0.18 0.22 0.48 rg'); // Fill Color: Indigo (#2E387B)
      streamBuf.writeln('35 760 525 55 re f');

      // Banner Header Text (White Text)
      streamBuf.writeln('BT');
      streamBuf.writeln('1 1 1 rg'); // White text
      streamBuf.writeln('/F2 16 Tf');
      streamBuf.writeln('50 793 Td');
      streamBuf.writeln('(${_cleanText('EXPENSE TRACKER STATEMENT')}) Tj');

      final subTitleText = titleSubtitle != null ? ' Period: $titleSubtitle   |  ' : ' ';
      streamBuf.writeln('/F1 9 Tf');
      streamBuf.writeln('0 -16 Td');
      streamBuf.writeln('(${_cleanText('Date: $generatedDateStr   |  $subTitleText Records: ${records.length}   |   Page ${pageIdx + 1} of $totalPages')}) Tj');
      streamBuf.writeln('ET');

      // 2. Table Header Bar (Dark Teal-Indigo accent)
      const double headerY = 732;
      streamBuf.writeln('0.24 0.28 0.54 rg'); // Header fill color
      streamBuf.writeln('35 $headerY 525 22 re f');
      streamBuf.writeln('0.15 0.18 0.35 RG'); // Outer border
      streamBuf.writeln('1.0 w');
      streamBuf.writeln('35 $headerY 525 22 re s');

      // Table Column Dividers in Header
      for (final x in [110, 210, 355, 455]) {
        streamBuf.writeln('$x $headerY m $x ${headerY + 22} l s');
      }

      // Table Header Text Elements (Placed in exact X columns)
      streamBuf.writeln('BT');
      streamBuf.writeln('1 1 1 rg'); // White bold text
      streamBuf.writeln('/F2 9 Tf');

      streamBuf.writeln('40 ${headerY + 7} Td (Date) Tj');
      streamBuf.writeln('115 ${headerY + 7} Td (Category) Tj');
      streamBuf.writeln('215 ${headerY + 7} Td (Expense Note) Tj');
      streamBuf.writeln('385 ${headerY + 7} Td (Amount [Rs]) Tj');
      streamBuf.writeln('460 ${headerY + 7} Td (Account) Tj');
      streamBuf.writeln('ET');

      // 3. Table Data Rows
      final startIndex = pageIdx * itemsPerPage;
      final endIndex = (startIndex + itemsPerPage).clamp(0, records.length);
      final pageRecords = records.sublist(startIndex, endIndex);

      double yPos = 711;

      for (int rIdx = 0; rIdx < pageRecords.length; rIdx++) {
        final rec = pageRecords[rIdx];
        const double rowHeight = 20;

        // Alternating row background shading
        if (rIdx % 2 == 0) {
          streamBuf.writeln('0.96 0.97 1.0 rg'); // Soft tinted blue fill
          streamBuf.writeln('35 ${yPos - 3} 525 $rowHeight re f');
        }

        // Draw Row Bounding Box & Cell Borders
        streamBuf.writeln('0.85 0.88 0.93 RG'); // Light gray grid borders
        streamBuf.writeln('0.5 w');
        streamBuf.writeln('35 ${yPos - 3} 525 $rowHeight re s');

        // Draw Vertical Column Dividers for Row
        for (final x in [110, 210, 355, 455]) {
          streamBuf.writeln('$x ${yPos - 3} m $x ${yPos - 3 + rowHeight} l s');
        }

        // Row Cell Content
        final dateText = _truncate(rec.date, 10);
        final catText = _truncate(rec.category, 14);
        final noteText = _truncate(rec.note, 24);
        final amtText = _truncate(rec.amount, 12);
        final accText = _truncate(rec.account, 14);

        // Render Date
        streamBuf.writeln('BT 0.15 0.15 0.20 rg /F1 9 Tf 40 $yPos Td ($dateText) Tj ET');
        // Render Category
        streamBuf.writeln('BT 0.15 0.15 0.20 rg /F1 9 Tf 115 $yPos Td ($catText) Tj ET');
        // Render Note
        streamBuf.writeln('BT 0.15 0.15 0.20 rg /F1 9 Tf 215 $yPos Td ($noteText) Tj ET');
        // Render Amount (Right Aligned in Col 3, X=355..455)
        streamBuf.writeln('BT 0.10 0.10 0.15 rg /F2 9 Tf 365 $yPos Td ($amtText) Tj ET');
        // Render Account
        streamBuf.writeln('BT 0.15 0.15 0.20 rg /F1 9 Tf 460 $yPos Td ($accText) Tj ET');

        yPos -= rowHeight;
      }

      // 4. Grand Total Summary Card at end of last page
      if (pageIdx == totalPages - 1) {
        final totalY = yPos - 12;
        // Total Box Background & Border
        streamBuf.writeln('0.92 0.94 1.0 rg'); // Soft blue fill
        streamBuf.writeln('35 ${totalY - 5} 525 28 re f');
        streamBuf.writeln('0.18 0.22 0.48 RG'); // Indigo border
        streamBuf.writeln('1.2 w');
        streamBuf.writeln('35 ${totalY - 5} 525 28 re s');

        // Total Box Text
        streamBuf.writeln('BT');
        streamBuf.writeln('0.12 0.16 0.38 rg'); // Dark Indigo bold text
        streamBuf.writeln('/F2 11 Tf');
        streamBuf.writeln('48 ${totalY + 4} Td');
        streamBuf.writeln('(${_cleanText('GRAND TOTAL STATEMENT AMOUNT:  Rs. $grandTotalStr')}) Tj');
        streamBuf.writeln('ET');
      }

      final streamBytes = utf8.encode(streamBuf.toString());

      // Content Stream Object
      markObject(contentObjId);
      writeString('<< /Length ${streamBytes.length} >>\nstream\n');
      writeBytes(streamBytes);
      writeString('\nendstream\nendobj\n');
    }

    // XRef Table
    final totalObjects = 5 + totalPages * 2;
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
