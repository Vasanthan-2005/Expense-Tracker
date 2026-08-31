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
  static String _escapePdfText(String text) {
    final sanitized = text
        .replaceAll('₹', 'Rs. ')
        .replaceAll('(', '\\(')
        .replaceAll(')', '\\)')
        .replaceAll('\\', '\\\\');

    final buffer = StringBuffer();
    for (int i = 0; i < sanitized.length; i++) {
      final code = sanitized.codeUnitAt(i);
      if (code >= 32 && code <= 126) {
        buffer.writeCharCode(code);
      } else {
        buffer.write(' ');
      }
    }
    return buffer.toString();
  }

  /// Builds a colorful, professional PDF 1.4 binary document Uint8List
  static Uint8List buildExpensePdf({
    required List<PdfStatementRecord> records,
    required String grandTotalStr,
    required String generatedDateStr,
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

    const int itemsPerPage = 20;
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

      // 1. Vibrant Top Indigo Banner Block (Full-width header)
      streamBuf.writeln('0.18 0.22 0.48 rg'); // Fill Color: Indigo (#2E387B)
      streamBuf.writeln('40 765 515 55 re f');

      // Banner Header Text (White Text)
      streamBuf.writeln('BT');
      streamBuf.writeln('1 1 1 rg'); // White text
      streamBuf.writeln('/F2 16 Tf');
      streamBuf.writeln('55 798 Td');
      streamBuf.writeln('(${_escapePdfText('EXPENSE TRACKER STATEMENT')}) Tj');

      streamBuf.writeln('/F1 9 Tf');
      streamBuf.writeln('0 -16 Td');
      streamBuf.writeln('(${_escapePdfText('Generated Date: $generatedDateStr   |   Total Records: ${records.length}   |   Page ${pageIdx + 1} of $totalPages')}) Tj');
      streamBuf.writeln('ET');

      // 2. Table Header Bar (Dark Teal-Indigo accent)
      streamBuf.writeln('0.28 0.34 0.62 rg'); // Header fill color
      streamBuf.writeln('40 735 515 22 re f');

      // Table Header Text
      streamBuf.writeln('BT');
      streamBuf.writeln('1 1 1 rg'); // White text
      streamBuf.writeln('/F2 9 Tf');
      streamBuf.writeln('48 742 Td');
      final headerLine = 'Date         Category          Expense Note                                   Amount (Rs.)      Account';
      streamBuf.writeln('(${_escapePdfText(headerLine)}) Tj');
      streamBuf.writeln('ET');

      // 3. Table Rows
      final startIndex = pageIdx * itemsPerPage;
      final endIndex = (startIndex + itemsPerPage).clamp(0, records.length);
      final pageRecords = records.sublist(startIndex, endIndex);

      double yPos = 712;

      for (int rIdx = 0; rIdx < pageRecords.length; rIdx++) {
        final rec = pageRecords[rIdx];

        // Alternating row background shading
        if (rIdx % 2 == 0) {
          streamBuf.writeln('0.96 0.97 1.0 rg'); // Very soft tinted blue-gray
          streamBuf.writeln('40 ${yPos - 3} 515 18 re f');
        }

        // Fine bottom border line for row
        streamBuf.writeln('0.88 0.90 0.95 RG');
        streamBuf.writeln('0.5 w');
        streamBuf.writeln('40 ${yPos - 3} m 555 ${yPos - 3} l s');

        // Row text
        streamBuf.writeln('BT');
        streamBuf.writeln('0.15 0.15 0.20 rg'); // Dark slate text color
        streamBuf.writeln('/F1 9 Tf');
        streamBuf.writeln('48 $yPos Td');

        final datePad = rec.date.padRight(12);
        final catPad = rec.category.length > 15 ? '${rec.category.substring(0, 12)}...' : rec.category.padRight(15);
        final notePad = rec.note.length > 30 ? '${rec.note.substring(0, 27)}...' : rec.note.padRight(30);
        final amtPad = rec.amount.padLeft(14);
        final accPad = rec.account.length > 14 ? rec.account.substring(0, 14) : rec.account;

        final lineStr = '$datePad $catPad $notePad $amtPad       $accPad';
        streamBuf.writeln('(${_escapePdfText(lineStr)}) Tj');
        streamBuf.writeln('ET');

        yPos -= 19;
      }

      // 4. Grand Total Summary Card at end of last page
      if (pageIdx == totalPages - 1) {
        final totalY = yPos - 12;
        // Total Box Background & Border
        streamBuf.writeln('0.92 0.94 1.0 rg'); // Soft blue fill
        streamBuf.writeln('40 ${totalY - 5} 515 28 re f');
        streamBuf.writeln('0.18 0.22 0.48 RG'); // Indigo border
        streamBuf.writeln('1.2 w');
        streamBuf.writeln('40 ${totalY - 5} 515 28 re s');

        // Total Box Text
        streamBuf.writeln('BT');
        streamBuf.writeln('0.12 0.16 0.38 rg'); // Dark Indigo bold text
        streamBuf.writeln('/F2 11 Tf');
        streamBuf.writeln('52 ${totalY + 4} Td');
        streamBuf.writeln('(${_escapePdfText('GRAND TOTAL STATEMENT AMOUNT:  Rs. $grandTotalStr')}) Tj');
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
