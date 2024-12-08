import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

enum PDFViewState {
  loading,
  loaded,
  error,
}

class PDFViewerScreen2 extends StatefulWidget {
  final String pdfUrl;

  const PDFViewerScreen2({super.key, required this.pdfUrl});

  @override
  State<PDFViewerScreen2> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen2> {
  PDFViewState _state = PDFViewState.loading;
  String? _errorMessage;
  String? _tempFilePath;
  PdfControllerPinch? _pdfController;
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  @override
  void dispose() {
    _mounted = false;
    _cleanupTempFile();
    super.dispose();
  }

  void _cleanupTempFile() {
    if (_tempFilePath != null) {
      File(_tempFilePath!).delete().catchError((_) {});
      _tempFilePath = null;
    }
  }

  Future<void> _loadPdf() async {
    if (!_mounted) return;
    
    try {
      setState(() {
        _state = PDFViewState.loading;
        _errorMessage = null;
      });

      // Check device support
      if (!await hasPdfSupport()) {
        throw 'PDF viewing is not supported on this device';
      }

      // Validate URL
      if (!await _isValidUrl()) {
        throw 'Invalid PDF URL or PDF not accessible';
      }

      // Download and open PDF
      await _downloadAndOpenPdf();

    } catch (e) {
      if (!_mounted) return;
      setState(() {
        _state = PDFViewState.error;
        _errorMessage = e.toString();
      });
    }
  }

  Future<bool> _isValidUrl() async {
    try {
      final response = await http.head(Uri.parse(widget.pdfUrl));
      return response.statusCode == 200 && 
             response.headers['content-type']?.toLowerCase().contains('pdf') == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _downloadAndOpenPdf() async {
    final response = await http.get(Uri.parse(widget.pdfUrl));
    if (!_mounted) return;

    if (response.statusCode != 200) {
      throw 'Failed to download PDF (Status: ${response.statusCode})';
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(response.bodyBytes);

    if (!_mounted) {
      file.delete().catchError((_) {});
      return;
    }

    _tempFilePath = file.path;
    _pdfController = PdfControllerPinch(
      document: PdfDocument.openFile(_tempFilePath!),
    );

    setState(() {
      _state = PDFViewState.loaded;
    });
  }

  Future<void> _downloadPdf() async {
    try {
      final response = await http.get(Uri.parse(widget.pdfUrl));
      if (!_mounted) return;

      if (response.statusCode != 200) {
        throw 'Download failed (Status: ${response.statusCode})';
      }

      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (!downloadsDir.existsSync()) {
        downloadsDir.createSync(recursive: true);
      }

      final fileName = 'BookVerse_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${downloadsDir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);

      if (!_mounted) return;
      _showSuccessMessage('PDF saved as $fileName');
    } catch (e) {
      if (!_mounted) return;
      _showErrorMessage('Download failed: $e');
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          onPressed: () {},
        ),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Loading PDF...',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Failed to load PDF',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadPdf,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfView() {
    return PdfViewPinch(
      controller: _pdfController!,
      onDocumentError: (error) {
        if (_mounted) {
          setState(() {
            _state = PDFViewState.error;
            _errorMessage = 'Error loading PDF: $error';
          });
        }
      },
      onPageChanged: (page) {
        if (_mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Viewer'),
        actions: [
          if (_state == PDFViewState.loaded)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _downloadPdf,
              tooltip: 'Download PDF',
            ),
        ],
      ),
      body: switch (_state) {
        PDFViewState.loading => _buildLoadingView(),
        PDFViewState.error => _buildErrorView(),
        PDFViewState.loaded => _buildPdfView(),
      },
    );
  }
}
