import 'package:book_Verse/books/detailScreen/viewPdf.dart';
import 'package:flutter/material.dart';

class PDFListScreen2 extends StatelessWidget {
  final List<Map<String, dynamic>> pdfs;

  const PDFListScreen2({super.key, required this.pdfs});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available PDFs'),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: theme.dividerColor.withOpacity(0.1),
            height: 1.0,
          ),
        ),
      ),
      body: pdfs.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: pdfs.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) => _buildPDFItem(context, pdfs[index]),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.picture_as_pdf_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No PDFs Available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This book has no PDF versions yet',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPDFItem(BuildContext context, Map<String, dynamic> pdf) {
    final theme = Theme.of(context);
    final quality = pdf['quality'] as String? ?? 'Standard';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.dividerColor.withOpacity(0.2),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openPDF(context, pdf),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.picture_as_pdf, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      pdf['name'] ?? 'Unnamed PDF',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _buildQualityBadge(quality),
                ],
              ),
              if (pdf['description'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  pdf['description'],
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQualityBadge(String quality) {
    Color badgeColor;
    switch (quality.toLowerCase()) {
      case 'high':
        badgeColor = Colors.green;
        break;
      case 'medium':
        badgeColor = Colors.orange;
        break;
      default:
        badgeColor = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: badgeColor.withOpacity(0.2),
        ),
      ),
      child: Text(
        quality,
        style: TextStyle(
          fontSize: 12,
          color: badgeColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _openPDF(BuildContext context, Map<String, dynamic> pdf) {
    final url = pdf['url'] as String?;
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF URL not found'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PDFViewerScreen2(pdfUrl: url),
      ),
    );
  }
}
