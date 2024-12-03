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
  List<Map<String, dynamic>> _recommendedBooks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRecommendations();
  }

  // Process book data for display
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

  void _updateState(List<Map<String, dynamic>> books, bool loading) {
    setState(() {
      _recommendedBooks = books;
      _isLoading = loading;
    });
  }

  // Get fallback recommendations
  Future<List<Map<String, dynamic>>> _getFallbackBooks() async {
    try {
      final snapshot = await _firestore
          .collection('books')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      return snapshot.docs
          .map((doc) => _processBookData(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error getting fallback books: $e');
      return [];
    }
  }

  // Calculate similarity between user profile and book
  double _calculateSimilarity(
      Map<String, double> profile, Map<String, dynamic> book) {
    double similarity = 0.0;
    double profileNorm = 0.0;
    double bookNorm = 0.0;

    // Calculate writer similarity
    final writer = book['writer']?.toString().toLowerCase() ?? '';
    final writerKey = 'writer_$writer';
    final writerValue = 4.0;
    similarity += (profile[writerKey] ?? 0.0) * writerValue;
    profileNorm += (profile[writerKey] ?? 0.0) * (profile[writerKey] ?? 0.0);
    bookNorm += writerValue * writerValue;

    // Calculate genre similarity
    final genres = (book['genre'] as List<dynamic>? ?? [])
        .map((g) => g.toString().toLowerCase());
    for (var genre in genres) {
      final genreKey = 'genre_$genre';
      final genreValue = 2.5;
      similarity += (profile[genreKey] ?? 0.0) * genreValue;
      profileNorm += (profile[genreKey] ?? 0.0) * (profile[genreKey] ?? 0.0);
      bookNorm += genreValue * genreValue;
    }

    // Calculate course similarity
    final course = book['course']?.toString().toLowerCase() ?? '';
    if (course.isNotEmpty) {
      final courseKey = 'course_$course';
      final courseValue = 2.0;
      similarity += (profile[courseKey] ?? 0.0) * courseValue;
      profileNorm += (profile[courseKey] ?? 0.0) * (profile[courseKey] ?? 0.0);
      bookNorm += courseValue * courseValue;
    }

    // Avoid division by zero
    if (profileNorm == 0 || bookNorm == 0) return 0.0;

    return similarity / (sqrt(profileNorm) * sqrt(bookNorm));
  }

  // Add book features to profile with weight
  void _addToProfile(Map<String, double> profile, Map<String, dynamic> bookData,
      double weight) {
    final writer = bookData['writer']?.toString().toLowerCase() ?? '';
    final genres = (bookData['genre'] as List<dynamic>? ?? [])
        .map((g) => g.toString().toLowerCase());
    final course = bookData['course']?.toString().toLowerCase() ?? '';

    // Add weighted features
    if (writer.isNotEmpty)
      profile['writer_$writer'] =
          (profile['writer_$writer'] ?? 0.0) + 4.0 * weight;
    for (var genre in genres) {
      profile['genre_$genre'] = (profile['genre_$genre'] ?? 0.0) + 2.5 * weight;
    }
    if (course.isNotEmpty) {
      profile['course_$course'] =
          (profile['course_$course'] ?? 0.0) + 2.0 * weight;
    }
  }

  // Get recommended books based on user profile
  Future<List<Map<String, dynamic>>> _getRecommendedBooks(
      Map<String, double> userProfile) async {
    final allBooks = await _firestore.collection('books').limit(200).get();
    final scoredBooks = <MapEntry<double, Map<String, dynamic>>>[];
    final selectedAuthors = <String>{};

    for (var doc in allBooks.docs) {
      final bookData = doc.data();
      final similarity = _calculateSimilarity(userProfile, bookData);

      if (similarity > 0.1) {
        final author = bookData['writer']?.toString().toLowerCase() ?? '';
        final diversityFactor = selectedAuthors.contains(author) ? 0.7 : 1.0;

        scoredBooks.add(MapEntry(
          similarity * diversityFactor,
          _processBookData(bookData, doc.id),
        ));
        selectedAuthors.add(author);
      }
    }

    scoredBooks.sort((a, b) => b.key.compareTo(a.key));
    return scoredBooks.take(10).map((e) => e.value).toList();
  }

  // Create user profile from search history and bookmarks
  Future<Map<String, double>> _createUserProfile(String userId) async {
    Map<String, double> profile = {};
    final now = DateTime.now();

    // Get search history
    final searches = await _firestore
        .collection('searchedBooks')
        .where('userId', isEqualTo: userId)
        .orderBy('searchedAt', descending: true)
        .limit(10)
        .get();

    // Get bookmarks
    final bookmarks = await _firestore
        .collection('bookmarks')
        .where('userId', isEqualTo: userId)
        .get();

    // Process search history with time decay
    for (var doc in searches.docs) {
      final bookData = doc.data();
      final searchedAt = (bookData['searchedAt'] as Timestamp).toDate();
      final daysDifference = now.difference(searchedAt).inDays;
      final timeDecay = exp(-0.1 * daysDifference);

      _addToProfile(profile, bookData, timeDecay);
    }

    // Process bookmarks with higher weight
    for (var doc in bookmarks.docs) {
      final bookId = doc.data()['bookId'] as String?;
      if (bookId != null) {
        final bookDoc = await _firestore.collection('books').doc(bookId).get();
        if (bookDoc.exists) {
          _addToProfile(
              profile, bookDoc.data()!, 1.5); // Bookmarks get 1.5x weight
        }
      }
    }

    return profile;
  }

  // Main recommendation function
  Future<void> _fetchRecommendations() async {
    try {
      setState(() => _isLoading = true);
      final userId = FirebaseAuth.instance.currentUser?.uid;

      if (userId == null) {
        print('No user logged in');
        return _updateState(await _getFallbackBooks(), false);
      }

      // Get user profile data
      final userProfile = await _createUserProfile(userId);

      // Get recommendations based on profile
      final recommendations = await _getRecommendedBooks(userProfile);

      _updateState(recommendations, false);
    } catch (e) {
      print('Error in recommendations: $e');
      _updateState(await _getFallbackBooks(), false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TSectionHeading(
          title: 'Popular Books',
          fontSize: 25,
          onPressed: _fetchRecommendations,
        ),
        const SizedBox(height: 10),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_recommendedBooks.isEmpty)
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
              itemCount: _recommendedBooks.length,
              itemBuilder: (context, index, realIndex) {
                final book = _recommendedBooks[index];
                final imageUrl = book['imageUrl'];
                final title = book['title'];
                final writer = book['writer'];

                return GestureDetector(
                  onTap: () => _navigateToDetailPage(book),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: 200,
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
                enableInfiniteScroll: _recommendedBooks.length > 1,
                autoPlay: _recommendedBooks.length > 1,
                autoPlayInterval: const Duration(seconds: 3),
                autoPlayAnimationDuration: const Duration(milliseconds: 800),
                autoPlayCurve: Curves.fastOutSlowIn,
              ),
            ),
          ),
      ],
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
          genre: (book['genre'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
        ),
      ),
    );
  }
}