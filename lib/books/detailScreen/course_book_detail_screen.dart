import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/home/screens/user/mark/provider.dart';
import 'authorbasedrecommendation.dart';
import 'genre_book_detail_screen.dart';
import 'pdflistscreen.dart';

class CourseBookDetailScreen extends StatefulWidget {
  final String title;
  final String writer;
  final String imageUrl;
  final String course;
  final String summary;
  final dynamic genre;

  const CourseBookDetailScreen({
    super.key,
    required this.title,
    required this.writer,
    required this.imageUrl,
    required this.course,
    required this.summary,
    this.genre,
  });

  @override
  State<CourseBookDetailScreen> createState() => _CourseBookDetailScreenState();
}

class _CourseBookDetailScreenState extends State<CourseBookDetailScreen> {
  bool isBookmarked = false;
  bool isOutOfStock = false;
  bool _isExpandedSummary = false;
  late String userId;
  bool _mounted = true;
  List<String> _genres = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
    _processGenres();
  }

  void _processGenres() {
    if (widget.genre == null) {
      _genres = [];
      return;
    }

    try {
      if (widget.genre is List) {
        _genres = List<String>.from(widget.genre.map((g) => g.toString()));
      } else if (widget.genre is String) {
        _genres = [widget.genre.toString()];
      } else {
        _genres = [];
      }
    } catch (e) {
      _genres = [];
    }
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
      setState(() => isOutOfStock =
          (snapshot.docs.first.data()['numberOfCopies'] ?? 0) <= 0);
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
      'genre': _genres,
      'userId': userId,
    };

    isBookmarked
        ? await _removeBookmark(bookData)
        : await _addBookmark(bookData);
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

      final docRef = await FirebaseFirestore.instance
          .collection('bookmarks')
          .add(bookDataWithId);

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
        await FirebaseFirestore.instance
            .collection('bookmarks')
            .doc(docId)
            .delete();

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

    if (!mounted) return;

    if (snapshot.docs.isNotEmpty) {
      final bookData = snapshot.docs.first.data();
      final pdfs = bookData['pdfs'] as List<dynamic>?;

      if (pdfs != null && pdfs.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PDFListScreen2(pdfs: List<Map<String, dynamic>>.from(pdfs)),
          ),
        );
      } else {
        _showNoPDFDialog();
      }
    } else {
      _showErrorDialog('Could not find the book information.');
    }
  }

  void _showSnackBar(String message) {
    if (!_mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showNoPDFDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No PDF Available'),
        content:
            const Text('This book does not have any PDF versions available.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _navigateToBookDetails(Map<String, dynamic> book) {
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CourseBookDetailScreen(
          title: book['title'] ?? '',
          writer: book['writer'] ?? '',
          imageUrl: book['imageUrl'] ?? '',
          course: book['course'] ?? '',
          summary: book['summary'] ?? '',
          genre: book['genre'] ?? [],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isCourseBook =
        widget.course.isNotEmpty && widget.course != 'Unknown Course';

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(isDark),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroSection(size, isDark),
            if (isCourseBook) _buildCourseSection(isDark),
            if (!isCourseBook && _genres.isNotEmpty) _buildGenreTags(isDark),
            if (isOutOfStock) _buildOutOfStockBanner(theme),
            _buildSummarySection(isDark),
            AuthorBasedRecommendation(
              writer: widget.writer,
              currentBookTitle: widget.title,
              course: widget.course,
              genres: _genres,
            ),
            const SizedBox(height: 24),
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

  Widget _buildCircularButton(
      IconData icon, bool isDark, VoidCallback onPressed,
      {Color? color}) {
    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.grey[900]!.withOpacity(0.5)
              : Colors.white.withOpacity(0.5),
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
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
            ),
          ],
        ),
      );

  Widget _buildCourseSection(bool isDark) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Course',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.school,
                    size: 18,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.course,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildGenreTags(bool isDark) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Genres',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _genres
                  .map((genre) => _buildGenreChip(genre, isDark))
                  .toList(),
            ),
          ],
        ),
      );

  Widget _buildGenreChip(String genre, bool isDark) => InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GenreBookDetailScreen(genre: genre),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_offer,
                size: 16,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
              const SizedBox(width: 6),
              Text(
                genre,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
              ),
            ],
          ),
        ),
      );

  Widget _buildOutOfStockBanner(ThemeData theme) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.error.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: theme.colorScheme.error,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Out of Stock',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This book is currently unavailable',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildSummarySection(bool isDark) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About this book',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () =>
                  setState(() => _isExpandedSummary = !_isExpandedSummary),
              child: AnimatedCrossFade(
                firstChild: Text(
                  widget.summary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white60 : Colors.black54,
                        height: 1.5,
                      ),
                ),
                secondChild: Text(
                  widget.summary,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white60 : Colors.black54,
                        height: 1.5,
                      ),
                ),
                crossFadeState: _isExpandedSummary
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  setState(() => _isExpandedSummary = !_isExpandedSummary),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isExpandedSummary ? 'Show Less' : 'Read More',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Icon(
                    _isExpandedSummary
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
