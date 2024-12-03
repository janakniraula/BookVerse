import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:math';

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

  // Add new helper methods for cosine similarity
  double _calculateCosineSimilarity(Map<String, double> vector1, Map<String, double> vector2) {
    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;
    
    // Calculate dot product and norms
    Set<String> allKeys = {...vector1.keys, ...vector2.keys};
    for (String key in allKeys) {
      double val1 = vector1[key] ?? 0.0;
      double val2 = vector2[key] ?? 0.0;
      dotProduct += val1 * val2;
      norm1 += val1 * val1;
      norm2 += val2 * val2;
    }
    
    // Avoid division by zero
    if (norm1 == 0 || norm2 == 0) return 0.0;
    
    return dotProduct / (sqrt(norm1) * sqrt(norm2));
  }

  Map<String, double> _createBookVector(Map<String, dynamic> book) {
    Map<String, double> vector = {};
    
    // Extract and process features
    String writer = (book['writer'] ?? '').toString().toLowerCase();
    List<String> genres = (book['genre'] as List<dynamic>? ?? [])
        .map((g) => g.toString().toLowerCase())
        .toList();
    String course = (book['course'] ?? '').toString().toLowerCase();
    
    // Add writer feature with higher weight
    vector['writer_$writer'] = 3.0;
    
    // Add genre features
    for (String genre in genres) {
      vector['genre_$genre'] = 1.0;
    }
    
    // Add course feature
    if (course.isNotEmpty) {
      vector['course_$course'] = 2.0;
    }
    
    return vector;
  }

  // Update the recommendation system
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

      // Get all books for comparison
      final allBooksSnapshot = await _firestore
          .collection('books')
          .limit(100) // Limit for performance
          .get();

      // Create user profile vector based on search history
      Map<String, double> userProfile = {};
      final searchedBooks = searchedBooksSnapshot.docs;
      
      for (var doc in searchedBooks) {
        final bookVector = _createBookVector(doc.data());
        // Combine vectors with decay factor based on search order
        double decayFactor = 1.0;
        bookVector.forEach((key, value) {
          userProfile[key] = (userProfile[key] ?? 0.0) + value * decayFactor;
          decayFactor *= 0.8; // Decay factor for older searches
        });
      }

      // Calculate similarity scores for all books
      List<MapEntry<double, Map<String, dynamic>>> scoredBooks = [];
      
      for (var doc in allBooksSnapshot.docs) {
        final bookData = doc.data();
        final bookVector = _createBookVector(bookData);
        final similarity = _calculateCosineSimilarity(userProfile, bookVector);
        
        if (similarity > 0) { // Only include books with some similarity
          scoredBooks.add(MapEntry(
            similarity,
            _processBookData(bookData, doc.id),
          ));
        }
      }

      // Sort by similarity score and take top results
      scoredBooks.sort((a, b) => b.key.compareTo(a.key));
      return scoredBooks.take(10).map((e) => e.value).toList();
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
            height: 320,
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
                    width: 200,
                    // Add constraints to prevent overflow
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: 220,
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
                                    errorBuilder: (context, error, stackTrace) {
                                      print('Image Error: $error');
                                      return _buildPlaceholder();
                                    },
                                  )
                                : _buildPlaceholder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Flexible(
                          child: Text(
                            writer,
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
              },
              options: CarouselOptions(
                height: 320,
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