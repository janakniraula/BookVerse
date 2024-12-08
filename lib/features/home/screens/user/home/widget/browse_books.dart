import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../../../books/detailScreen/course_book_detail_screen.dart';

class BrowseBooks extends StatefulWidget {
  const BrowseBooks({super.key});

  @override
  State<BrowseBooks> createState() => _BrowseBooksState();
}

class _BrowseBooksState extends State<BrowseBooks> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const int _limit = 12; // Increased initial load for better grid layout

  List<DocumentSnapshot> _books = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final snapshot = await _firestore
          .collection('books')
          .orderBy('title')
          .limit(_limit)
          .get();

      setState(() {
        _books = snapshot.docs;
        if (snapshot.docs.isNotEmpty) {
          _lastDocument = snapshot.docs.last;
        }
        _hasMore = snapshot.docs.length == _limit;
      });
    } catch (e) {
      print('Error loading initial data: $e');
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final snapshot = await _firestore
          .collection('books')
          .orderBy('title')
          .startAfterDocument(_lastDocument!)
          .limit(_limit)
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          _books.addAll(snapshot.docs);
          _lastDocument = snapshot.docs.last;
          _hasMore = snapshot.docs.length == _limit;
        });
      } else {
        setState(() {
          _hasMore = false;
        });
      }
    } catch (e) {
      print('Error loading more books: $e');
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_books.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Browse Books',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                final book = _books[index].data() as Map<String, dynamic>;
                return _buildBookCard(context, book);
              },
              childCount: _books.length,
            ),
          ),
        ),
        if (_hasMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: _isLoadingMore
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: _loadMore,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Load More Books',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        // Add some bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: 20),
        ),
      ],
    );
  }

  Widget _buildBookCard(BuildContext context, Map<String, dynamic> book) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CourseBookDetailScreen(
            title: book['title'] ?? 'No Title',
            writer: book['writer'] ?? 'Unknown Writer',
            imageUrl: book['imageUrl'] ?? '',
            course: book['course'] ?? '',
            summary: book['summary'] ?? '',
            genre: (book['genre'] as List<dynamic>?) ?? [],
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Hero(
              tag: 'book-${book['title']}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  book['imageUrl'] ?? '',
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.book, size: 40),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book['title'] ?? 'No Title',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            book['writer'] ?? 'Unknown Writer',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}