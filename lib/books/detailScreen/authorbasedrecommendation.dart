import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'course_book_detail_screen.dart';

// Widget to display book recommendations by the same author
class AuthorBasedRecommendation extends StatefulWidget {
  final String writer;
  final String currentBookTitle;

  const AuthorBasedRecommendation({
    super.key,
    required this.writer,
    required this.currentBookTitle,
  });

  @override
  State<AuthorBasedRecommendation> createState() => _AuthorBasedRecommendationState();
}

class _AuthorBasedRecommendationState extends State<AuthorBasedRecommendation> {
  // Instance of Firestore for database operations
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // List to store recommended books by the same author
  List<Map<String, dynamic>> _recommendedBooks = [];
  // Loading state flag for UI feedback
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAuthorBooks();
  }

  // Fetches all books by the current author excluding the current book
  Future<void> _fetchAuthorBooks() async {
    try {
      // Query books collection for books by the same author
      final snapshot = await _firestore
          .collection('books')
          .where('writer', isEqualTo: widget.writer)
          .get();

      // Process and filter out the current book
      final books = snapshot.docs
          .map((doc) => _processBookData(doc.data(), doc.id))
          .where((book) => book['title'] != widget.currentBookTitle)
          .toList();

      if (mounted) {
        setState(() {
          _recommendedBooks = books;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching author books: $e');
      if (mounted) {
        setState(() {
          _recommendedBooks = [];
          _isLoading = false;
        });
      }
    }
  }

  // Standardizes and validates book data from Firestore
  Map<String, dynamic> _processBookData(Map<String, dynamic> data, String id) {
    return {
      'id': id,
      'title': data['title'] ?? 'Unknown Title',
      'writer': data['writer'] ?? 'Unknown Author',
      'imageUrl': data['imageUrl'] ?? '',
      'course': data['course'] ?? '',
      'summary': data['summary'] ?? 'No summary available',
      'genre': (data['genre'] as List<dynamic>?) ?? [],
    };
  }

  @override
  Widget build(BuildContext context) {
    // Hide widget if no recommendations and not loading
    if (_recommendedBooks.isEmpty && !_isLoading) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header showing author's first name
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Text(
            'More by ${widget.writer.split(' ')[0]}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (_isLoading)
          // Loading indicator while fetching books
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          )
        else
          // Horizontal scrollable list of book cards
          SizedBox(
            height: 320,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _recommendedBooks.length,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemBuilder: (context, index) {
                final book = _recommendedBooks[index];
                return _buildBookCard(book);
              },
            ),
          ),
      ],
    );
  }

  // Creates a card widget for displaying book information
  Widget _buildBookCard(Map<String, dynamic> book) {
    return GestureDetector(
      onTap: () => _navigateToDetailPage(book),
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        width: 180,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Book cover image with shadow and rounded corners
            Container(
              height: 240,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    spreadRadius: 1,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  book['imageUrl'],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildPlaceholder();
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Book title with ellipsis for overflow
            Text(
              book['title'],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            // Optional course information display
            if (book['course'].isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  book['course'],
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Displays a placeholder when book cover image fails to load
  Widget _buildPlaceholder() {
    return Container(
      width: 180,
      height: 240,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(
          Icons.book,
          size: 50,
          color: Colors.grey,
        ),
      ),
    );
  }

  // Navigates to the detail screen of the selected book
  void _navigateToDetailPage(Map<String, dynamic> book) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CourseBookDetailScreen(
          title: book['title'],
          writer: book['writer'],
          imageUrl: book['imageUrl'],
          course: book['course'],
          summary: book['summary'],
          genre: book['genre'],
        ),
      ),
    );
  }
} 