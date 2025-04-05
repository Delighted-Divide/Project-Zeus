import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Service for handling PDF operations
class PdfService {
  final Logger _logger = Logger();

  /// Select and load a PDF file
  Future<Map<String, dynamic>?> pickPdfFile() async {
    _logger.i('Opening file picker for PDF selection');

    try {
      // Open file picker
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        if (file.path != null) {
          _logger.i('PDF selected: ${file.name}');

          final pdfFile = File(file.path!);

          // Load the PDF document to get page count
          final pdfBytes = await pdfFile.readAsBytes();
          final document = PdfDocument(inputBytes: pdfBytes);
          final pageCount = document.pages.count;
          document.dispose();

          _logger.i('PDF loaded successfully with $pageCount pages');

          return {'file': pdfFile, 'name': file.name, 'pageCount': pageCount};
        } else if (file.bytes != null) {
          // Handle in-memory file for web platform
          _logger.i('PDF selected (web): ${file.name}');

          // Save bytes to temporary file for processing
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/${file.name}');
          await tempFile.writeAsBytes(file.bytes!);

          // Load the PDF document to get page count
          final document = PdfDocument(inputBytes: file.bytes!);
          final pageCount = document.pages.count;
          document.dispose();

          _logger.i('PDF loaded successfully with $pageCount pages');

          return {'file': tempFile, 'name': file.name, 'pageCount': pageCount};
        }
      } else {
        _logger.i('No PDF file selected');
      }

      return null;
    } catch (e) {
      _logger.e('Error picking PDF file', error: e);
      rethrow;
    }
  }

  /// Extract text from PDF using SyncFusion library
  Future<String> extractTextFromPdf(File pdfFile, RangeValues pageRange) async {
    _logger.i('Extracting text from PDF using SyncFusion');

    try {
      // Load the PDF document
      final bytes = await pdfFile.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);

      // Extract text from selected pages
      final startPage = pageRange.start.toInt();
      final endPage = pageRange.end.toInt();

      // Create PDF text extractor
      final extractor = PdfTextExtractor(document);

      // Extract text from specific pages
      String extractedText = '';
      for (int i = startPage; i <= endPage; i++) {
        // Page numbers in SyncFusion are 0-based
        final pageText = extractor.extractText(
          startPageIndex: i - 1,
          endPageIndex: i - 1,
        );
        extractedText += 'Page $i:\n$pageText\n\n';
      }

      // Dispose the document
      document.dispose();

      _logger.i(
        'Successfully extracted ${extractedText.length} characters from PDF',
      );
      return extractedText;
    } catch (e) {
      _logger.e('Error extracting text from PDF', error: e);
      throw Exception('Failed to extract text from PDF: $e');
    }
  }
}
