import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../../../../../books/detailScreen/course_book_detail_screen.dart';
import '../pdfView/pdflist.dart';
import 'BooksAll.dart';
import 'package:book_Verse/features/home/screens/user/home/widget/browse_books.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String query = '';
  List<DocumentSnapshot> searchResults = [];
  bool isLoading = false;
  String? userId;
  Timer? _debounceTimer;
  List<DocumentSnapshot> _allBooks = [];
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    userId = FirebaseAuth.instance.currentUser?.uid;
    _loadInitialData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() => _isInitialLoading = true);

      final snapshot = await _firestore
          .collection('books')
          .orderBy('title')
          .get();

      setState(() {
        _allBooks = snapshot.docs;
        _isInitialLoading = false;
      });
    } catch (e) {
      print('Error loading initial data: $e');
      setState(() => _isInitialLoading = false);
    }
  }

  Future<void> _searchBooks(String searchQuery) async {
    _debounceTimer?.cancel();

    if (searchQuery.isEmpty) {
      setState(() {
        searchResults = [];
        isLoading = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;

      setState(() => isLoading = true);

      try {
        final uppercaseQuery = searchQuery.toUpperCase();

        final results = _allBooks.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final title = (data['title'] as String?)?.toUpperCase() ?? '';
          final writer = (data['writer'] as String?)?.toUpperCase() ?? '';
          final course = (data['course'] as String?)?.toUpperCase() ?? '';

          return title.contains(uppercaseQuery) ||
              writer.contains(uppercaseQuery) ||
              course.contains(uppercaseQuery);
        }).toList();

        if (mounted) {
          setState(() {
            searchResults = results;
            isLoading = false;
          });
        }

        if (results.isNotEmpty && userId != null) {
          _saveSearchResults(searchQuery, results);
        }
      } catch (e) {
        print('Error searching books: $e');
        if (mounted) {
          setState(() {
            searchResults = [];
            isLoading = false;
          });
        }
      }
    });
  }

  Future<void> _saveSearchResults(String searchQuery, List<DocumentSnapshot> results) async {
    try {
      final previousSearches = await _firestore
          .collection('searchedBooks')
          .where('userId', isEqualTo: userId)
          .orderBy('searchedAt', descending: true)
          .limit(10)
          .get();

      final batch = _firestore.batch();

      if (previousSearches.docs.length >= 10) {
        for (var doc in previousSearches.docs.sublist(9)) {
          batch.delete(doc.reference);
        }
      }

      final newSearchRef = _firestore.collection('searchedBooks').doc();
      final firstResult = results.first.data() as Map<String, dynamic>;

      batch.set(newSearchRef, {
        'userId': userId,
        'query': searchQuery,
        'bookId': results.first.id,
        'title': firstResult['title'] ?? 'No title',
        'writer': firstResult['writer'] ?? 'Unknown author',
        'imageUrl': firstResult['imageUrl'] ?? '',
        'course': firstResult['course'] ?? '',
        'summary': firstResult['summary'] ?? 'No summary available',
        'searchedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      print('Error saving search results: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _searchFocusNode.unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Search Books'),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              color: Colors.green,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AllPDFsScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.menu_book),
              color: Colors.green,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AllBooksScreen()),
              ),
            ),
          ],
        ),
        body: _isInitialLoading
            ? const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading books...'),
            ],
          ),
        )
            : Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _searchBooks,
                decoration: InputDecoration(
                  labelText: 'Search books by title, author, or course',
                  hintText: 'Enter your search term',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _searchBooks('');
                      _searchFocusNode.unfocus();
                    },
                  )
                      : null,
                ),
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _searchController.text.isEmpty
                  ? const BrowseBooks()
                  : searchResults.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.search_off,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No results found for "${_searchController.text}"',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                itemCount: searchResults.length,
                itemBuilder: (context, index) {
                  final book = searchResults[index].data() as Map<String, dynamic>;
                  return _buildBookCard(book);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookCard(Map<String, dynamic> book) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 3,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CourseBookDetailScreen(
              title: book['title'] ?? 'No title',
              writer: book['writer'] ?? 'Unknown author',
              imageUrl: book['imageUrl'] ?? '',
              course: book['course'] ?? '',
              summary: book['summary'] ?? 'No summary available',
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: book['imageUrl']?.isNotEmpty == true
                    ? Image.network(
                  book['imageUrl']!,
                  width: 80,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildPlaceholderImage();
                  },
                )
                    : _buildPlaceholderImage(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book['title'] ?? 'No title',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book['writer'] ?? 'Unknown author',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book['course'] ?? '',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 80,
      height: 120,
      color: Colors.grey[300],
      child: const Icon(
        Icons.book,
        size: 40,
        color: Colors.grey,
      ),
    );
  }

  static Widget buildSearchField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required Function(String) onSearch,
    required VoidCallback onClear,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onSearch,
      decoration: InputDecoration(
        labelText: 'Search books by title, author, or course',
        hintText: 'Enter your search term',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: onClear,
              )
            : null,
      ),
    );
  }

  static Future<List<DocumentSnapshot>> performSearch(
    List<DocumentSnapshot> allBooks,
    String searchQuery,
  ) async {
    if (searchQuery.isEmpty) {
      return [];
    }

    final uppercaseQuery = searchQuery.toUpperCase();
    return allBooks.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final title = (data['title'] as String?)?.toUpperCase() ?? '';
      final writer = (data['writer'] as String?)?.toUpperCase() ?? '';
      final course = (data['course'] as String?)?.toUpperCase() ?? '';

      return title.contains(uppercaseQuery) ||
          writer.contains(uppercaseQuery) ||
          course.contains(uppercaseQuery);
    }).toList();
  }
}