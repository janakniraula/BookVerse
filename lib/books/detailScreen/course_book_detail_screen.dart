import 'package:book_Verse/books/detailScreen/pdflistscreen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/home/screens/user/mark/provider.dart';

class CourseBookDetailScreen extends StatefulWidget {
  final String title;
  final String writer;
  final String imageUrl;
  final String course;
  final String summary;
  final List<dynamic> genre;

  const CourseBookDetailScreen({
    super.key,
    required this.title,
    required this.writer,
    required this.imageUrl,
    required this.course,
    required this.summary,
    this.genre = const [],
  });

  @override
  State<CourseBookDetailScreen> createState() => _CourseBookDetailScreenState();
}

class _CourseBookDetailScreenState extends State<CourseBookDetailScreen> {
  bool isBookmarked = false;
  bool isOutOfStock = false;
  late String userId;
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  Future<void> _initializeData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _mounted) {
      userId = user.uid;
      await Future.wait([
        _checkIfBookmarked(),
        _checkAvailability(),
      ]);
    }
  }

  Future<void> _checkIfBookmarked() async {
    if (!_mounted) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('bookmarks')
        .where('title', isEqualTo: widget.title)
        .where('userId', isEqualTo: userId)
        .get();

    if (_mounted) setState(() => isBookmarked = snapshot.docs.isNotEmpty);
  }

  Future<void> _checkAvailability() async {
    if (!_mounted) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('books')
        .where('title', isEqualTo: widget.title)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty && _mounted) {
      setState(() => isOutOfStock = (snapshot.docs.first.data()['numberOfCopies'] ?? 0) <= 0);
    }
  }

  Future<void> _toggleBookmark() async {
    if (isOutOfStock) {
      _showSnackBar('This book is out of stock and cannot be added.');
      return;
    }

    final bookData = {
      'title': widget.title,
      'writer': widget.writer,
      'imageUrl': widget.imageUrl,
      'course': widget.course,
      'summary': widget.summary,
      'userId': userId,
    };

    isBookmarked ? await _removeBookmark(bookData) : await _addBookmark(bookData);
  }

  Future<void> _addBookmark(Map<String, dynamic> bookData) async {
    if (!_mounted) return;
    try {
      final bookSnapshot = await FirebaseFirestore.instance
          .collection('books')
          .where('title', isEqualTo: widget.title)
          .limit(1)
          .get();

      if (!_mounted) return;
      if (bookSnapshot.docs.isEmpty) {
        _showSnackBar('Book not found');
        return;
      }

      final bookId = bookSnapshot.docs.first.id;
      final bookDataWithId = {
        ...bookData,
        'bookId': bookId,
        'timestamp': FieldValue.serverTimestamp(),
      };

      final docRef = await FirebaseFirestore.instance.collection('bookmarks').add(bookDataWithId);
      
      if (!_mounted) return;
      Provider.of<BookmarkProvider>(context, listen: false).addBookmark({
        ...bookDataWithId,
        'id': docRef.id,
      });
      
      setState(() => isBookmarked = true);
      _showSnackBar('${widget.title} Added');
    } catch (error) {
      _showSnackBar('Failed to Add: $error');
    }
  }

  Future<void> _removeBookmark(Map<String, dynamic> bookData) async {
    if (!_mounted) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bookmarks')
          .where('title', isEqualTo: widget.title)
          .where('userId', isEqualTo: userId)
          .get();

      if (!_mounted) return;
      if (snapshot.docs.isNotEmpty) {
        final docId = snapshot.docs.first.id;
        await FirebaseFirestore.instance.collection('bookmarks').doc(docId).delete();
        
        if (!_mounted) return;
        Provider.of<BookmarkProvider>(context, listen: false).removeBookmark({
          ...bookData,
          'id': docId,
        });
        
        setState(() => isBookmarked = false);
        _showSnackBar('${widget.title} removed');
      }
    } catch (error) {
      _showSnackBar('Failed to remove: $error');
    }
  }

  Future<void> _viewPDFs() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('books')
        .where('title', isEqualTo: widget.title)
        .limit(1)
        .get();

    if (!snapshot.docs.isEmpty && snapshot.docs.first.data()['pdfs'] != null) {
      final pdfs = List<Map<String, dynamic>>.from(snapshot.docs.first.data()['pdfs']);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PDFListScreen2(pdfs: pdfs)),
      );
    } else {
      _showNoPDFsDialog();
    }
  }

  void _showSnackBar(String message) {
    if (_mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _showNoPDFsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No PDFs Found'),
        content: const Text('No PDFs are available for this book.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(isDark),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroSection(size, isDark),
            _buildDetailsSection(isDark),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) => AppBar(
    elevation: 0,
    backgroundColor: Colors.transparent,
    leading: _buildCircularButton(
      Icons.arrow_back_ios,
      isDark,
      () => Navigator.pop(context),
    ),
    actions: [
      _buildCircularButton(
        isBookmarked ? Icons.bookmark : Icons.bookmark_border,
        isDark,
        _toggleBookmark,
        color: isBookmarked ? Colors.red : null,
      ),
      _buildCircularButton(
        Icons.picture_as_pdf,
        isDark,
        _viewPDFs,
      ),
      const SizedBox(width: 8),
    ],
  );

  Widget _buildCircularButton(IconData icon, bool isDark, VoidCallback onPressed, {Color? color}) {
    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900]!.withOpacity(0.5) : Colors.white.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: color ?? (isDark ? Colors.white : Colors.black),
          size: 20,
        ),
      ),
      onPressed: onPressed,
    );
  }

  Widget _buildHeroSection(Size size, bool isDark) => Stack(
    children: [
      _buildBackgroundImage(size, isDark),
      _buildGradientOverlay(size, isDark),
      _buildBookInfo(isDark),
    ],
  );

  Widget _buildBackgroundImage(Size size, bool isDark) => Container(
    height: size.height * 0.45,
    decoration: BoxDecoration(
      color: isDark ? Colors.grey[900] : Colors.grey[100],
      image: DecorationImage(
        image: NetworkImage(widget.imageUrl),
        fit: BoxFit.cover,
        opacity: 0.3,
      ),
    ),
  );

  Widget _buildGradientOverlay(Size size, bool isDark) => Container(
    height: size.height * 0.45,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          isDark ? Colors.black : Colors.white,
        ],
      ),
    ),
  );

  Widget _buildBookInfo(bool isDark) => Positioned(
    bottom: 0,
    left: 0,
    right: 0,
    child: Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildBookCover(),
          const SizedBox(width: 20),
          _buildTitleAuthor(isDark),
        ],
      ),
    ),
  );

  Widget _buildBookCover() => Hero(
    tag: 'book-${widget.title}',
    child: Container(
      width: 180,
      height: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          widget.imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image, size: 40),
          ),
        ),
      ),
    ),
  );

  Widget _buildTitleAuthor(bool isDark) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          widget.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'by ${widget.writer}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.grey,
          ),
        ),
      ],
    ),
  );

  Widget _buildDetailsSection(bool isDark) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.genre.isNotEmpty || widget.course.isNotEmpty) ...[
          _buildTags(isDark),
          const SizedBox(height: 24),
        ],
        _buildSummarySection(isDark),
        if (isOutOfStock) ...[
          const SizedBox(height: 24),
          _buildOutOfStockWarning(),
        ],
      ],
    ),
  );

  Widget _buildTags(bool isDark) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        if (widget.genre.isNotEmpty) ...[
          ...widget.genre.map((g) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildTag(
              context, 
              g.toString(),
              Icons.local_library,
              isDark
            ),
          )).toList(),
        ]
        else if (widget.course.isNotEmpty)
          _buildTag(
            context, 
            widget.course,
            Icons.school,
            isDark
          ),
      ],
    ),
  );

  Widget _buildSummarySection(bool isDark) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'About the Book',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        widget.summary,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          height: 1.6,
          color: isDark ? Colors.grey[300] : Colors.grey[800],
        ),
      ),
    ],
  );

  Widget _buildOutOfStockWarning() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.red.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.red.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.error_outline, 
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'This book is currently out of stock',
            style: TextStyle(
              color: Colors.red[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildTag(BuildContext context, String text, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
