import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class PdfService {
  final Logger _logger = Logger();

  Future<Map<String, dynamic>?> pickPdfFile() async {
    _logger.i('Opening file picker for PDF selection');

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null) {
        _logger.i('No PDF file selected');
        return null;
      }

      final file = result.files.first;

      if (file.path != null) {
        _logger.i('PDF selected (native): ${file.name}');
        final pdfFile = File(file.path!);
        final pdfBytes = await pdfFile.readAsBytes();
        final document = PdfDocument(inputBytes: pdfBytes);
        final pageCount = document.pages.count;
        document.dispose();

        return {'file': pdfFile, 'name': file.name, 'pageCount': pageCount};
      } else if (file.bytes != null) {
        _logger.i('PDF selected (web): ${file.name}');

        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/${file.name}');
        await tempFile.writeAsBytes(file.bytes!);

        final document = PdfDocument(inputBytes: file.bytes!);
        final pageCount = document.pages.count;
        document.dispose();

        return {'file': tempFile, 'name': file.name, 'pageCount': pageCount};
      }

      _logger.w('Invalid PDF file format');
      return null;
    } catch (e) {
      _logger.e('Error picking PDF file: $e');
      return null;
    }
  }

  Future<String> extractTextFromPdf(File pdfFile, RangeValues pageRange) async {
    _logger.i('Extracting text from PDF using SyncFusion');

    PdfDocument? document;
    try {
      final bytes = await pdfFile.readAsBytes();
      document = PdfDocument(inputBytes: bytes);

      final startPage = pageRange.start.toInt();
      final endPage = pageRange.end.toInt();
      final StringBuilder textBuilder = StringBuilder();

      for (int i = startPage; i <= endPage; i++) {
        final page = document.pages[i - 1];
        final text = PdfTextExtractor(
          document,
        ).extractText(startPageIndex: i - 1, endPageIndex: i - 1);
        textBuilder.append(text);
        textBuilder.append('\n\n');
      }

      _logger.i('Successfully extracted text from PDF');
      return textBuilder.toString();
    } catch (e) {
      _logger.e('Error extracting text from PDF: $e');
      return '';
    } finally {
      document?.dispose();
    }
  }
}

class StringBuilder {
  final StringBuffer _buffer = StringBuffer();

  void append(String str) {
    _buffer.write(str);
  }

  @override
  String toString() => _buffer.toString();
}
