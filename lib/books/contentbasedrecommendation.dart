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

  // Standardizes book data format for consistency
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
    if (mounted) {
      setState(() {
        _recommendedBooks = books;
        _isLoading = loading;
      });
    }
  }

  // Fetches recent books as fallback recommendations
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

  // Calculates cosine similarity between user profile and book features
  double _calculateSimilarity(Map<String, double> profile, Map<String, dynamic> book) {
    final features = {
      'writer': {'weight': 4.0, 'value': book['writer']?.toString().toLowerCase() ?? ''},
      'genre': {'weight': 2.5, 'values': (book['genre'] as List<dynamic>?)?.map((g) => g.toString().toLowerCase()).toList() ?? []},
      'course': {'weight': 2.0, 'value': book['course']?.toString().toLowerCase() ?? ''}
    };

    double dotProduct = 0.0;
    double profileNorm = 0.0;
    double bookNorm = 0.0;

    // Calculate writer similarity
    final writerKey = 'writer_${features['writer']!['value']}';
    const writerWeight = 4.0;
    dotProduct += (profile[writerKey] ?? 0.0) * writerWeight;
    profileNorm += pow(profile[writerKey] ?? 0.0, 2);
    bookNorm += pow(writerWeight, 2);

    // Calculate genre similarity
    for (var genre in features['genre']!['values'] as List<String>) {
      final genreKey = 'genre_$genre';
      const genreWeight = 2.5;
      dotProduct += (profile[genreKey] ?? 0.0) * genreWeight;
      profileNorm += pow(profile[genreKey] ?? 0.0, 2);
      bookNorm += pow(genreWeight, 2);
    }

    // Calculate course similarity
    if ((features['course']!['value'] as String).isNotEmpty) {
      final courseKey = 'course_${features['course']!['value']}';
      const courseWeight = 2.0;
      dotProduct += (profile[courseKey] ?? 0.0) * courseWeight;
      profileNorm += pow(profile[courseKey] ?? 0.0, 2);
      bookNorm += pow(courseWeight, 2);
    }

    return (profileNorm > 0 && bookNorm > 0) 
        ? dotProduct / (sqrt(profileNorm) * sqrt(bookNorm))
        : 0.0;
  }

  // Updates user profile with weighted book features
  void _addToProfile(Map<String, double> profile, Map<String, dynamic> bookData, double weight) {
    final features = {
      'writer': {'weight': 4.0, 'value': bookData['writer']?.toString().toLowerCase() ?? ''},
      'genre': {'weight': 2.5, 'values': (bookData['genre'] as List<dynamic>?)?.map((g) => g.toString().toLowerCase()).toList() ?? []},
      'course': {'weight': 2.0, 'value': bookData['course']?.toString().toLowerCase() ?? ''}
    };

    final String writerValue = features['writer']!['value'] as String;
    if (writerValue.isNotEmpty) {
      final key = 'writer_$writerValue';
      profile[key] = (profile[key] ?? 0.0) + 4.0 * weight;
    }

    for (var genre in features['genre']!['values'] as List<String>) {
      final key = 'genre_$genre';
      profile[key] = (profile[key] ?? 0.0) + 2.5 * weight;
    }

    final String courseValue = features['course']!['value'] as String;
    if (courseValue.isNotEmpty) {
      final key = 'course_$courseValue';
      profile[key] = (profile[key] ?? 0.0) + 2.0 * weight;
    }
  }

  // Generates recommendations using cosine similarity and diversity factors
  Future<List<Map<String, dynamic>>> _getRecommendedBooks(Map<String, double> userProfile) async {
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

  // Creates user profile from search history and bookmarks with time decay
  Future<Map<String, double>> _createUserProfile(String userId) async {
    Map<String, double> profile = {};
    final now = DateTime.now();

    final searches = await _firestore
        .collection('searchedBooks')
        .where('userId', isEqualTo: userId)
        .orderBy('searchedAt', descending: true)
        .limit(10)
        .get();

    final bookmarks = await _firestore
        .collection('bookmarks')
        .where('userId', isEqualTo: userId)
        .get();

    for (var doc in searches.docs) {
      final bookData = doc.data();
      final searchedAt = (bookData['searchedAt'] as Timestamp).toDate();
      final timeDecay = exp(-0.1 * now.difference(searchedAt).inDays);
      _addToProfile(profile, bookData, timeDecay);
    }

    for (var doc in bookmarks.docs) {
      final bookId = doc.data()['bookId'] as String?;
      if (bookId != null) {
        final bookDoc = await _firestore.collection('books').doc(bookId).get();
        if (bookDoc.exists) {
          _addToProfile(profile, bookDoc.data()!, 1.5);
        }
      }
    }

    return profile;
  }

  Future<void> _fetchRecommendations() async {
    try {
      setState(() => _isLoading = true);
      final userId = FirebaseAuth.instance.currentUser?.uid;

      if (userId == null) {
        print('No user logged in');
        return _updateState(await _getFallbackBooks(), false);
      }

      final userProfile = await _createUserProfile(userId);
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