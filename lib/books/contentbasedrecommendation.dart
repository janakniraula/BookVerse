import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../common/widgets/texts/section_heading.dart';
import 'detailScreen/course_book_detail_screen.dart';

class ContentBasedAlgorithm extends StatefulWidget {
  const ContentBasedAlgorithm({super.key});

  @override
  State<ContentBasedAlgorithm> createState() => _ContentBasedAlgorithmState();
}

class _ContentBasedAlgorithmState extends State<ContentBasedAlgorithm> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _popularBooks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCombinedRecommendations();
  }

  Future<void> _fetchCombinedRecommendations() async {
    try {
      setState(() => _isLoading = true);
      final userId = FirebaseAuth.instance.currentUser?.uid;

      if (userId == null) {
        print('No user logged in.');
        _updateState([], false);
        return;
      }

      // Get recommendations from both systems
      final authorBasedBooks = await _fetchAuthorBasedRecommendations(userId);
      final recentBooks = await _getRecommendedBooks(userId);

      // Combine both lists and remove duplicates
      final Set<Map<String, dynamic>> combinedBooks = {};
      combinedBooks.addAll(authorBasedBooks);
      combinedBooks.addAll(recentBooks);

      if (combinedBooks.isEmpty) {
        final fallbackBooks = await _getFallbackBooks();
        _updateState(fallbackBooks, false);
        return;
      }

      _updateState(combinedBooks.toList(), false);
    } catch (e) {
      print('Error in recommendation system: $e');
      try {
        final fallbackBooks = await _getFallbackBooks();
        _updateState(fallbackBooks, false);
      } catch (fallbackError) {
        print('Error getting fallback books: $fallbackError');
        _updateState([], false);
      }
    }
  }

  // Original author-based recommendation system
  Future<List<Map<String, dynamic>>> _fetchAuthorBasedRecommendations(
      String userId) async {
    try {
      final searchedBooksSnapshot = await _firestore
          .collection('searchedBooks')
          .where('userId', isEqualTo: userId)
          .orderBy('searchedAt', descending: true)
          .limit(7)
          .get();

      if (searchedBooksSnapshot.docs.isEmpty) {
        return [];
      }

      final searchedBook = searchedBooksSnapshot.docs.first.data();
      final searchedAuthor = searchedBook['writer']?.trim();

      if (searchedAuthor == null || searchedAuthor.isEmpty) {
        return [];
      }

      final bookmarksByAuthorSnapshot = await _firestore
          .collection('bookmarks')
          .where('writer', isEqualTo: searchedAuthor)
          .get();

      final bookmarkedBookIds = bookmarksByAuthorSnapshot.docs
          .map((doc) => doc.data()['bookId'] as String?)
          .where((bookId) => bookId != null)
          .toSet();

      if (bookmarkedBookIds.isEmpty) {
        return [];
      }

      final recommendedBooks = await Future.wait(
        bookmarkedBookIds.map((bookId) async {
          final bookDoc =
              await _firestore.collection('books').doc(bookId).get();
          return bookDoc.exists ? bookDoc.data() as Map<String, dynamic> : null;
        }),
      );

      return recommendedBooks.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      print('Error in author-based recommendations: $e');
      return [];
    }
  }

  // New recommendation system based on user's search history
  Future<List<Map<String, dynamic>>> _getRecommendedBooks(String userId) async {
    try {
      // Get user's recent searches
      final searchedBooksSnapshot = await _firestore
          .collection('searchedBooks')
          .where('userId', isEqualTo: userId)
          .orderBy('searchedAt', descending: true)
          .limit(5)
          .get();

      if (searchedBooksSnapshot.docs.isEmpty) {
        print('No search history found');
        return [];
      }

      // Extract authors from searched books
      final searchedBooks = searchedBooksSnapshot.docs.map((doc) => doc.data());
      final preferredAuthors = searchedBooks
          .map((book) => book['writer']?.toString().trim())
          .where((author) => author != null && author.isNotEmpty)
          .toSet();

      if (preferredAuthors.isEmpty) {
        return [];
      }

      // Get recommendations based on preferred authors
      final recommendationsQuery = await _firestore
          .collection('books')
          .where('writer', whereIn: preferredAuthors.take(10).toList())
          .limit(10)
          .get();

      final Set<Map<String, dynamic>> recommendations = {};

      for (var doc in recommendationsQuery.docs) {
        recommendations.add(_processBookData(doc.data(), doc.id));
      }

      return recommendations.toList();
    } catch (e) {
      print('Error getting recommendations: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getFallbackBooks() async {
    try {
      // Get recent books as fallback
      final fallbackBooksSnapshot = await _firestore
          .collection('books')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      if (fallbackBooksSnapshot.docs.isEmpty) {
        // If no books with createdAt, just get any books
        final anyBooksSnapshot =
            await _firestore.collection('books').limit(10).get();

        return anyBooksSnapshot.docs
            .map((doc) => _processBookData(doc.data(), doc.id))
            .toList();
      }

      return fallbackBooksSnapshot.docs
          .map((doc) => _processBookData(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error getting fallback books: $e');
      return [];
    }
  }

  Map<String, dynamic> _processBookData(Map<String, dynamic> data, String id) {
    return {
      'id': id,
      'title': data['title'] ?? 'Unknown Title',
      'writer': data['writer'] ?? 'Unknown Author',
      'imageUrl': data['imageUrl'] ?? '',
      'course': data['course'] ?? '',
      'summary': data['summary'] ?? 'No summary available',
    };
  }

  void _updateState(List<Map<String, dynamic>> books, bool loading) {
    setState(() {
      _popularBooks = books;
      _isLoading = loading;
    });
  }

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
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 150,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(20),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TSectionHeading(
          title: '| Popular Books',
          fontSize: 25,
          onPressed: _fetchCombinedRecommendations,
        ),
        const SizedBox(height: 10),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_popularBooks.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                'No popular books found.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          )
        else
          SizedBox(
            height: 300,
            child: CarouselSlider.builder(
              itemCount: _popularBooks.length,
              itemBuilder: (context, index, realIndex) {
                final book = _popularBooks[index];
                final imageUrl = book['imageUrl'];
                final title = book['title'];
                final writer = book['writer'];

                return GestureDetector(
                  onTap: () => _navigateToDetailPage(book),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
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
                              borderRadius: BorderRadius.circular(20),
                              child: imageUrl.isNotEmpty
                                  ? Image.network(
                                      imageUrl,
                                      width: 150,
                                      height: 220,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        print('Image Error: $error');
                                        return _buildPlaceholder();
                                      },
                                    )
                                  : _buildPlaceholder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            writer,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              options: CarouselOptions(
                height: 300,
                viewportFraction: 0.5,
                enlargeCenterPage: true,
                enableInfiniteScroll: _popularBooks.length > 1,
                autoPlay: _popularBooks.length > 1,
                autoPlayInterval: const Duration(seconds: 3),
                autoPlayAnimationDuration: const Duration(milliseconds: 800),
                autoPlayCurve: Curves.fastOutSlowIn,
              ),
            ),
          ),
      ],
    );
  }
}
