import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../allbooks.dart';
import '../booksEditing/editBooks.dart';
import 'package:book_Verse/features/home/screens/user/search/search.dart';

class SearchBookScreen extends StatefulWidget {
  const SearchBookScreen({super.key});

  @override
  _SearchBookScreenState createState() => _SearchBookScreenState();
}

class _SearchBookScreenState extends State<SearchBookScreen> {
  final _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  List<DocumentSnapshot> allBooks = [];
  List<DocumentSnapshot> searchResults = [];
  bool isLoading = false;
  bool isLoadingMore = false;
  DocumentSnapshot? lastDocument;
  static const int booksPerPage = 12;

  @override
  void initState() {
    super.initState();
    _loadInitialBooks();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.95 &&
        !isLoadingMore &&
        lastDocument != null) {
      _loadMoreBooks();
    }
  }

  Future<void> _loadInitialBooks() async {
    setState(() => isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('books')
          .orderBy('title')
          .limit(booksPerPage)
          .get();

      setState(() {
        allBooks = snapshot.docs;
        lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showError('Error loading books: $e');
    }
  }

  Future<void> _loadMoreBooks() async {
    if (isLoadingMore || lastDocument == null) return;

    setState(() => isLoadingMore = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('books')
          .orderBy('title')
          .startAfterDocument(lastDocument!)
          .limit(booksPerPage)
          .get();

      setState(() {
        allBooks.addAll(snapshot.docs);
        lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        isLoadingMore = false;
      });
    } catch (e) {
      setState(() => isLoadingMore = false);
      _showError('Error loading more books: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _buildBookCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditBookScreen(bookId: doc.id),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data['imageUrl'] != null)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    image: DecorationImage(
                      image: NetworkImage(data['imageUrl']),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['title'] ?? 'No Title',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['writer'] ?? 'Unknown Author',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      onChanged: _performSearch,
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
                  setState(() {
                    searchResults.clear();
                  });
                  _loadInitialBooks();
                },
              )
            : null,
      ),
    );
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        searchResults.clear();
      });
      return;
    }

    setState(() => isLoading = true);
    try {
      final uppercaseQuery = query.toUpperCase();
      final results = allBooks.where((doc) {
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
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showError('Error searching books: $e');
      }
    }
  }

  Widget _buildBookList() {
    if (isLoading && allBooks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: searchResults.isNotEmpty || _searchController.text.isNotEmpty
                ? searchResults.length
                : allBooks.length,
            itemBuilder: (context, index) {
              final doc = searchResults.isNotEmpty || _searchController.text.isNotEmpty
                  ? searchResults[index]
                  : allBooks[index];
              return _buildBookCard(doc);
            },
          ),
        ),
        if (!isLoading && !_searchController.text.isNotEmpty && lastDocument != null)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: isLoadingMore ? null : _loadMoreBooks,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: isLoadingMore
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Load More Books'),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Books'),
        actions: [
          IconButton(
            icon: const Icon(Icons.library_books),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AllBooksScreenAdmin()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildSearchField(),
          ),
          Expanded(
            child: _buildBookList(),
          ),
        ],
      ),
    );
  }
}