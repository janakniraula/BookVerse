import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'course_book_detail_screen.dart';

class AuthorRecommendations extends StatelessWidget {
  final String writer;
  final String currentBookTitle;

  const AuthorRecommendations({
    super.key,
    required this.writer,
    required this.currentBookTitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Text(
              'More by ${writer.split(' ')[0]}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: 280,
            child: FutureBuilder<List<QueryDocumentSnapshot>>(
              future: _getRecommendations(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildErrorState(theme);
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingState();
                }

                final books = snapshot.data ?? [];
                
                if (books.isEmpty) {
                  return _buildEmptyState(theme);
                }

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: books.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemBuilder: (context, index) {
                    final book = books[index].data() as Map<String, dynamic>;
                    return _buildBookCard(context, book, isDark);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<List<QueryDocumentSnapshot>> _getRecommendations() async {
    try {
      final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('books')
          .where('writer', isEqualTo: writer)
          .get();

      final seen = <String>{};
      return querySnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final title = data['title'] as String;
        if (title == currentBookTitle || seen.contains(title)) {
          return false;
        }
        seen.add(title);
        return true;
      }).take(5).toList();
    } catch (e) {
      debugPrint('Error fetching recommendations: $e');
      return [];
    }
  }

  Widget _buildBookCard(BuildContext context, Map<String, dynamic> book, bool isDark) {
    final theme = Theme.of(context);
    final isCourseBook = book['course'] != null && book['course'].toString().isNotEmpty;
    
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: GestureDetector(
        onTap: () => _navigateToBook(context, book),
        child: SizedBox(
          width: 160,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'book-${book['title']}',
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      book['imageUrl'] ?? '',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: isDark ? Colors.grey[850] : Colors.grey[200],
                        child: Icon(
                          Icons.broken_image,
                          size: 40,
                          color: isDark ? Colors.grey[700] : Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: 20,
                  maxHeight: 40,
                ),
                child: Text(
                  book['title'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              if (isCourseBook)
                _buildCourseTag(book['course'], isDark)
              else if (book['genre'] != null && (book['genre'] as List).isNotEmpty)
                _buildGenreTag((book['genre'] as List).first.toString(), isDark),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourseTag(String course, bool isDark) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: isDark ? Colors.grey[900] : Colors.grey[100],
      borderRadius: BorderRadius.circular(4),
      border: Border.all(
        color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.school,
          size: 10,
          color: isDark ? Colors.white60 : Colors.black54,
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            course,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildGenreTag(String genre, bool isDark) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: isDark ? Colors.grey[900] : Colors.grey[100],
      borderRadius: BorderRadius.circular(4),
      border: Border.all(
        color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.local_offer,
          size: 10,
          color: isDark ? Colors.white60 : Colors.black54,
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            genre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load recommendations',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.book_outlined,
              size: 48,
              color: theme.disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              'No other books found by this author',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.disabledColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToBook(BuildContext context, Map<String, dynamic> book) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    FirebaseFirestore.instance
        .collection('books')
        .where('title', isEqualTo: book['title'])
        .get()
        .then((snapshot) {
      Navigator.pop(context);
      if (snapshot.docs.isNotEmpty) {
        final completeBookData = snapshot.docs.first.data();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CourseBookDetailScreen(
              title: completeBookData['title'] ?? '',
              writer: completeBookData['writer'] ?? '',
              imageUrl: completeBookData['imageUrl'] ?? '',
              course: completeBookData['course'] ?? '',
              summary: completeBookData['summary'] ?? '',
              genre: (completeBookData['genre'] as List<dynamic>?) ?? [],
            ),
          ),
        );
      }
    }).catchError((error) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error loading book details'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }
}
