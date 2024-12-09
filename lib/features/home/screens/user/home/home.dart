import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../../books/contentbasedrecommendation.dart';
import '../../../../../books/detailScreen/genre_book_detail_screen.dart';
import '../../../../../books/CourseSection/courseSelection.dart';
import '../../../../../common/widgets/custom_shapes/primary_header_container.dart';
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
  bool _isGridLayout = false;

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
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CourseSelectionScreen(grade: grade),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [Colors.blue[700]!, Colors.blue[900]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.school_outlined,
                  size: 24,
                  color: Colors.white.withOpacity(0.9),
                ),
                const SizedBox(height: 6),
                Text(
                  grade,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_courseBooks[grade]?.length ?? 0} Books',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenreCard(String genre) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GenreBookDetailScreen(genre: genre),
          ),
        ),
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: 120,
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              colors: [Colors.blue[700]!, Colors.blue[900]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                genre,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${_genreBooks[genre]?.length ?? 0} Books',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenreSection() {
    return _buildSection(
      title: 'Genres',
      trailing: IconButton(
        icon: Icon(_isGridLayout ? Icons.view_list : Icons.grid_view),
        onPressed: () {
          setState(() {
            _isGridLayout = !_isGridLayout;
          });
        },
      ),
      content: _isGridLayout
          ? GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.5,
              ),
              itemCount: _genreBooks.length,
              itemBuilder: (context, index) =>
                  _buildGenreCard(_genreBooks.keys.elementAt(index)),
            )
          : SizedBox(
              height: 100,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _genreBooks.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _buildGenreCard(_genreBooks.keys.elementAt(index)),
                ),
              ),
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget content,
    VoidCallback? onViewAll,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (trailing != null) trailing,
              if (onViewAll != null)
                TextButton(
                  onPressed: onViewAll,
                  child: const Text('View All'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        content,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: TPrimaryHeaderContainer(
                child: Column(
                  children: [
                    SizedBox(height: TSizes.sm),
                    THomeAppBar(),
                    SizedBox(height: TSizes.spaceBtwSections),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: $_error'),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildListDelegate([
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: ContentBasedAlgorithm(),
                  ),
                  const SizedBox(height: 8),
                  _buildSection(
                    title: 'Course Books',
                    content: GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.3,
                      ),
                      itemCount: _courseBooks.length,
                      itemBuilder: (context, index) =>
                          _buildGradeCard(_courseBooks.keys.elementAt(index)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildGenreSection(),
                  const SizedBox(height: 12),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}