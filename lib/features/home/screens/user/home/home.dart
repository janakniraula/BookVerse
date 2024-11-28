import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../../books/contentbasedrecommendation.dart';
import '../../../../../books/detailScreen/genre_book_detail_screen.dart';
import '../../../../../books/CourseSection/courseSelection.dart';
import '../../../../../common/widgets/custom_shapes/primary_header_container.dart';
import '../../../../../common/widgets/texts/section_heading.dart';
import '../../../../../utils/constants/sizes.dart';
import 'widget/home_appbar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, List<QueryDocumentSnapshot>> _courseBooks = {};
  Map<String, List<QueryDocumentSnapshot>> _genreBooks = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);
      await Future.wait([
        _loadCourseBooks(),
        _loadGenreBooks(),
      ]);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCourseBooks() async {
    final snapshot = await _firestore
        .collection('books')
        .where('isCourseBook', isEqualTo: true)
        .get();

    _courseBooks = {};
    for (var book in snapshot.docs) {
      final grade = book['grade'] as String?;
      if (grade != null) {
        _courseBooks.putIfAbsent(grade, () => []).add(book);
      }
    }
  }

  Future<void> _loadGenreBooks() async {
    final snapshot = await _firestore
        .collection('books')
        .where('isCourseBook', isEqualTo: false)
        .get();

    _genreBooks = {};
    for (var book in snapshot.docs) {
      final genres = book['genre'] as List<dynamic>?;
      if (genres != null) {
        for (var genre in genres) {
          if (genre is String) {
            _genreBooks.putIfAbsent(genre, () => []).add(book);
          }
        }
      }
    }
  }

  Widget _buildGradeCard(String grade) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CourseSelectionScreen(grade: grade),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.purpleAccent, Colors.deepPurpleAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.4),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.school,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              grade,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.1,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreCard(String genre) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GenreBookDetailScreen(genre: genre),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.green, Colors.greenAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.4),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            genre,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionGrid({
    required Map<String, List<QueryDocumentSnapshot>> items,
    required Widget Function(String) cardBuilder,
    required double childAspectRatio,
  }) {
    final itemKeys = items.keys.toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: itemKeys.length,
      itemBuilder: (context, index) => cardBuilder(itemKeys[index]),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error: $_error',
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading content...'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        // Hide keyboard and remove focus from any text field
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                // Header
                const TPrimaryHeaderContainer(
                  child: Column(
                    children: [
                      SizedBox(height: TSizes.sm),
                      THomeAppBar(),
                      SizedBox(height: TSizes.spaceBtwSections),
                    ],
                  ),
                ),

                // Body
                if (_isLoading)
                  _buildLoadingState()
                else if (_error != null)
                  _buildErrorState()
                else
                  Padding(
                    padding: const EdgeInsets.all(TSizes.cardRadiusSm),
                    child: Column(
                      children: [
                        // Recommendations Section
                        const ContentBasedAlgorithm(),
                        const Divider(),

                        // Course Books Section
                        TSectionHeading(
                          title: '| Course Books',
                          fontSize: 25,
                          onPressed: () {},
                        ),
                        _buildSectionGrid(
                          items: _courseBooks,
                          cardBuilder: _buildGradeCard,
                          childAspectRatio: 4 / 3,
                        ),
                        const Divider(),
                        const SizedBox(height: TSizes.spaceBtwItems),

                        // Genre Section
                        TSectionHeading(
                          title: '| Genre',
                          fontSize: 25,
                          onPressed: () {},
                        ),
                        _buildSectionGrid(
                          items: _genreBooks,
                          cardBuilder: _buildGenreCard,
                          childAspectRatio: 3,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
