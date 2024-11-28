import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../../../../../books/detailScreen/course_book_detail_screen.dart';
import '../pdfView/pdflist.dart';
import 'BooksAll.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String query = '';
  List<DocumentSnapshot> searchResults = [];
  bool isLoading = false;
  String? userId;
  Timer? _debounceTimer;
  final TextEditingController _searchController = TextEditingController();
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
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() => _isInitialLoading = true);

      // Cache all books for faster search
      final snapshot = await _firestore
          .collection('books')
          .orderBy('title') // Optional: pre-sort books
          .get();

      _allBooks = snapshot.docs;

      setState(() => _isInitialLoading = false);
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

    // Debounce search to prevent excessive updates
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;

      setState(() => isLoading = true);

      try {
        final uppercaseQuery = searchQuery.toUpperCase();

        // Search in cached books
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

        // Save search results in background
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
      // Manage search history - keep only recent searches
      final previousSearches = await _firestore
          .collection('searchedBooks')
          .where('userId', isEqualTo: userId)
          .orderBy('searchedAt', descending: true)
          .limit(10)
          .get();

      // Batch operations for better performance
      final batch = _firestore.batch();

      // Remove old searches if there are too many
      if (previousSearches.docs.length >= 10) {
        for (var doc in previousSearches.docs.sublist(9)) {
          batch.delete(doc.reference);
        }
      }

      // Add new search result
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
    return Scaffold(
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
                  },
                )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : searchResults.isEmpty && _searchController.text.isNotEmpty
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
    );
  }

  Widget _buildBookCard(Map<String, dynamic> book) {
    final title = book['title'] ?? 'No title';
    final writer = book['writer'] ?? 'Unknown author';
    final imageUrl = book['imageUrl'] ?? '';
    final course = book['course'] ?? '';
    final summary = book['summary'] ?? 'No summary available';

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
              title: title,
              writer: writer,
              imageUrl: imageUrl,
              course: course,
              summary: summary,
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
                child: imageUrl.isNotEmpty
                    ? Image.network(
                  imageUrl,
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
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      writer,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      course,
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
}