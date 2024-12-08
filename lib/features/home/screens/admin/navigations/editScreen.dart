import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../allbooks.dart';
import '../booksEditing/editBooks.dart';
import 'package:book_Verse/utils/constants/colors.dart';
import 'package:book_Verse/utils/helpers/helper_function.dart';
import 'package:book_Verse/features/home/screens/user/pdfView/pdflist.dart';

class SearchBookScreen extends StatefulWidget {
  const SearchBookScreen({super.key});

  @override
  _SearchBookScreenState createState() => _SearchBookScreenState();
}

class _SearchBookScreenState extends State<SearchBookScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _debounceTimer;
  
  List<DocumentSnapshot> _allBooks = [];
  List<DocumentSnapshot> _searchResults = [];
  bool _isLoading = false;
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
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
      final snapshot = await _firestore.collection('books').orderBy('title').get();
      setState(() {
        _allBooks = snapshot.docs;
        _isInitialLoading = false;
      });
    } catch (e) {
      print('Error loading initial data: $e');
      setState(() => _isInitialLoading = false);
    }
  }

  void _handleSearch(String query) {
    _debounceTimer?.cancel();
    if (query.isEmpty) {
      setState(() => _searchResults.clear());
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      
      setState(() => _isLoading = true);
      final uppercaseQuery = query.toUpperCase();
      
      final results = _allBooks.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return [
          data['title']?.toString().toUpperCase(),
          data['writer']?.toString().toUpperCase(),
          data['course']?.toString().toUpperCase(),
        ].any((field) => field?.contains(uppercaseQuery) ?? false);
      }).toList();

      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    });
  }

  void _navigateToEdit(String bookId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditBookScreen(bookId: bookId),
      ),
    ).then((_) => _loadInitialData());
  }

  Widget _buildBookImage(String? imageUrl) {
    final isDark = THelperFunction.isDarkMode(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: imageUrl?.isNotEmpty == true
          ? Image.network(
              imageUrl!,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPlaceholder(isDark),
            )
          : _buildPlaceholder(isDark),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      color: isDark ? TColors.darkerGrey : Colors.grey[300],
      child: Icon(
        Icons.book,
        size: 40,
        color: isDark ? Colors.grey[600] : Colors.grey,
      ),
    );
  }

  Widget _buildBookTitle(String? title) {
    return Text(
      title ?? 'No Title',
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildAuthorText(String? author, bool isDark) {
    return Text(
      author ?? 'Unknown Writer',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: isDark ? Colors.grey[400] : Colors.grey[700],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildGridItem(DocumentSnapshot doc) {
    final isDark = THelperFunction.isDarkMode(context);
    final data = doc.data() as Map<String, dynamic>;
    
    return GestureDetector(
      onTap: () => _navigateToEdit(doc.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildBookImage(data['imageUrl'])),
          const SizedBox(height: 8),
          _buildBookTitle(data['title']),
          const SizedBox(height: 4),
          _buildAuthorText(data['writer'], isDark),
        ],
      ),
    );
  }

  Widget _buildListItem(DocumentSnapshot doc) {
    final isDark = THelperFunction.isDarkMode(context);
    final data = doc.data() as Map<String, dynamic>;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: InkWell(
        onTap: () => _navigateToEdit(doc.id),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                height: 120,
                child: _buildBookImage(data['imageUrl']),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBookTitle(data['title']),
                    const SizedBox(height: 4),
                    _buildAuthorText(data['writer'], isDark),
                    if (data['course'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        data['course'],
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _allBooks.length,
      itemBuilder: (_, index) => _buildGridItem(_allBooks[index]),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      onChanged: _handleSearch,
      decoration: InputDecoration(
        labelText: 'Search books by title, author, or course',
        hintText: 'Enter your search term',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30.0)),
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _handleSearch('');
                  _searchFocusNode.unfocus();
                },
              )
            : null,
      ),
    );
  }

  Widget _buildNoResults(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: isDark ? Colors.grey[400] : Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'No results found for "${_searchController.text}"',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.grey[400] : Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = THelperFunction.isDarkMode(context);

    return GestureDetector(
      onTap: () => _searchFocusNode.unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Edit Books', 
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.green),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AllPDFsScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.library_books, color: Colors.green),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AllBooksScreenAdmin()),
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
                    child: _buildSearchField(),
                  ),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _searchController.text.isEmpty
                            ? _buildBookGrid()
                            : _searchResults.isEmpty
                                ? _buildNoResults(isDark)
                                : ListView.builder(
                                    itemCount: _searchResults.length,
                                    itemBuilder: (_, index) => 
                                        _buildListItem(_searchResults[index]),
                                  ),
                  ),
                ],
              ),
      ),
    );
  }
}
