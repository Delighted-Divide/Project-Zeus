import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class PDFViewerScreen extends StatefulWidget {
  final String url;
  final String title;

  const PDFViewerScreen({super.key, required this.url, required this.title});

  @override
  State<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
  File? _pdfFile;
  bool _isLoading = true;
  String _errorMessage = '';
  int _totalPages = 0;
  int _currentPage = 0;
  bool _isReady = false;
  PDFViewController? _pdfViewController;

  @override
  void initState() {
    super.initState();
    _loadPDF();
  }

  // Download and prepare the PDF file
  Future<void> _loadPDF() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Create a temporary file name
      final filename = widget.title.replaceAll(' ', '_');
      final extension = widget.url.endsWith('.pdf') ? '' : '.pdf';
      final tempPath = await _getTempPath('$filename$extension');

      // Check if file already exists
      final file = File(tempPath);
      if (await file.exists()) {
        setState(() {
          _pdfFile = file;
          _isLoading = false;
        });
        return;
      }

      // Download PDF
      final response = await http.get(Uri.parse(widget.url));

      // Save to temporary file
      await file.writeAsBytes(response.bodyBytes);

      setState(() {
        _pdfFile = file;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load PDF: $e';
      });
      print('Error loading PDF: $e');
    }
  }

  // Get a path in the temp directory for the PDF file
  Future<String> _getTempPath(String filename) async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/$filename';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFFFFA07A), // Salmon color to match chat
        actions: [
          if (_isReady && _totalPages > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  'Page ${_currentPage + 1} of $_totalPages',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage.isNotEmpty
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 60,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadPDF,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
              : PDFView(
                filePath: _pdfFile!.path,
                enableSwipe: true,
                swipeHorizontal: true,
                autoSpacing: true,
                pageFling: true,
                pageSnap: true,
                defaultPage: 0,
                fitPolicy: FitPolicy.BOTH,
                preventLinkNavigation: false,
                onRender: (pages) {
                  setState(() {
                    _totalPages = pages!;
                    _isReady = true;
                  });
                },
                onError: (error) {
                  setState(() {
                    _errorMessage = error.toString();
                  });
                  print('Error rendering PDF: $error');
                },
                onPageError: (page, error) {
                  print('Error on page $page: $error');
                },
                onViewCreated: (PDFViewController pdfViewController) {
                  _pdfViewController = pdfViewController;
                },
                onPageChanged: (int? page, int? total) {
                  if (page != null) {
                    setState(() {
                      _currentPage = page;
                    });
                  }
                },
              ),
      floatingActionButton:
          _isReady && _totalPages > 1
              ? Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_currentPage > 0)
                    FloatingActionButton(
                      heroTag: 'prevPage',
                      backgroundColor: const Color(0xFF4CAF50),
                      child: const Icon(Icons.arrow_back),
                      onPressed: () {
                        if (_pdfViewController != null && _currentPage > 0) {
                          _pdfViewController!.setPage(_currentPage - 1);
                        }
                      },
                    ),
                  const SizedBox(width: 16),
                  if (_currentPage < _totalPages - 1)
                    FloatingActionButton(
                      heroTag: 'nextPage',
                      backgroundColor: const Color(0xFF4CAF50),
                      child: const Icon(Icons.arrow_forward),
                      onPressed: () {
                        if (_pdfViewController != null &&
                            _currentPage < _totalPages - 1) {
                          _pdfViewController!.setPage(_currentPage + 1);
                        }
                      },
                    ),
                ],
              )
              : null,
    );
  }
}
