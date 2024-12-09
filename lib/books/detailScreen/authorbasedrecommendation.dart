import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'course_book_detail_screen.dart';
import 'book_filter_widget.dart';

// Widget to display book recommendations by the same author
class AuthorBasedRecommendation extends StatefulWidget {
  final String writer;
  final String currentBookTitle;
  final String course;
  final List<String> genres;

  const AuthorBasedRecommendation({
    super.key,
    required this.writer,
    required this.currentBookTitle,
    required this.course,
    required this.genres,
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
  String? _selectedAuthor;
  List<String> _selectedGenres = [];
  List<Map<String, dynamic>> _allBooks = [];
  bool _showingCourseBooks = false;
  bool _showingGenreBooks = false;

  @override
  void initState() {
    super.initState();
    _fetchRecommendedBooks();
  }

  Future<void> _fetchRecommendedBooks() async {
    try {
      if (widget.course.isNotEmpty) {
        setState(() => _isLoading = true);
        // If it's a course book, fetch other books from the same course
        await _fetchCourseBooks();
      } else {
        // First check if author has any other books without showing loading
        final authorSnapshot = await _firestore
            .collection('books')
            .where('writer', isEqualTo: widget.writer)
            .get();

        final authorBooks = authorSnapshot.docs
            .where((doc) => doc['title'] != widget.currentBookTitle)
            .toList();

        if (authorBooks.isNotEmpty) {
          // Only show loading and fetch author books if there are any
          setState(() => _isLoading = true);
          _allBooks = authorBooks
              .map((doc) => _processBookData(doc.data(), doc.id))
              .toList();
          
          setState(() {
            _recommendedBooks = List.from(_allBooks);
            _isLoading = false;
          });
        } else {
          // Directly fetch genre-based recommendations
          setState(() => _isLoading = true);
          await _fetchGenreBooks();
        }
      }
    } catch (e) {
      print('Error fetching recommendations: $e');
      if (mounted) {
        setState(() {
          _allBooks = [];
          _recommendedBooks = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchCourseBooks() async {
    final snapshot = await _firestore
        .collection('books')
        .where('course', isEqualTo: widget.course)
        .get();

    if (mounted) {
      _allBooks = snapshot.docs
          .map((doc) => _processBookData(doc.data(), doc.id))
          .where((book) => book['title'] != widget.currentBookTitle)
          .toList();
      
      setState(() {
        _recommendedBooks = List.from(_allBooks);
        _showingCourseBooks = true;
      });
    }
  }

  Future<void> _fetchGenreBooks() async {
    if (widget.genres.isEmpty) return;

    final snapshot = await _firestore
        .collection('books')
        .where('genre', arrayContainsAny: widget.genres)
        .limit(10)
        .get();

    if (mounted) {
      _allBooks = snapshot.docs
          .map((doc) => _processBookData(doc.data(), doc.id))
          .where((book) => book['title'] != widget.currentBookTitle)
          .toList();
      
      setState(() {
        _recommendedBooks = List.from(_allBooks);
        _showingGenreBooks = true;
      });
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
        if (_recommendedBooks.isNotEmpty || _isLoading) // Only show header if there are books or loading
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getHeaderText(),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: _showFilterBottomSheet,
                ),
              ],
            ),
          ),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_recommendedBooks.isNotEmpty)
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
            const SizedBox(height: 4),
            // Genre tags
            if (book['genre'] != null && (book['genre'] as List).isNotEmpty)
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: (book['genre'] as List)
                    .take(2) // Show only first 2 genres to avoid overflow
                    .map<Widget>((genre) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            genre.toString(),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ))
                    .toList(),
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

  void _showFilterBottomSheet() {
    // Only get available genres since we're not filtering by author anymore
    final availableGenres = _allBooks
        .expand((book) => (book['genre'] as List? ?? []))
        .map((genre) => genre.toString())
        .toSet()
        .toList()
      ..sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: BookFilterWidget(
          currentAuthor: widget.writer, // Pass current author instead of list
          availableGenres: availableGenres,
          selectedGenres: _selectedGenres,
          onFilterChanged: _applyFilters,
        ),
      ),
    );
  }

  void _applyFilters(String? author, List<String> genres) async {
    try {
      setState(() => _isLoading = true);

      if (genres.isNotEmpty) {
        // Fetch all books that contain any of the selected genres
        final snapshot = await _firestore
            .collection('books')
            .where('genre', arrayContainsAny: genres)
            .get();

        if (mounted) {
          setState(() {
            _selectedGenres = genres;
            _recommendedBooks = snapshot.docs
                .map((doc) => _processBookData(doc.data(), doc.id))
                .where((book) => book['title'] != widget.currentBookTitle)
                .toList();
          });
        }
      } else {
        // If no genres selected, show only the current author's books
        setState(() {
          _selectedGenres = [];
          _recommendedBooks = List.from(_allBooks);
        });
      }
    } catch (e) {
      print('Error applying filters: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Helper method to get the appropriate header text based on filters
  String _getHeaderText() {
    if (_selectedGenres.isNotEmpty) {
      return 'Books in ${_selectedGenres.join(", ")}';
    } else if (_showingCourseBooks) {
      return 'More from ${widget.course}';
    } else if (_showingGenreBooks) {
      return 'Similar Books';
    } else {
      return 'More by ${widget.writer}';
    }
  }
}
