import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'course_book_detail_screen.dart';

class GenreBookDetailScreen extends StatelessWidget {
  final String genre;
  const GenreBookDetailScreen({super.key, required this.genre});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Books in Genre: $genre'),
        elevation: 0,
        backgroundColor: Colors.black,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('books')
          .where('genre', arrayContains: genre)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final groupedBooks = _groupBooksByTitle(snapshot.data!.docs);
        return _buildBookGrid(groupedBooks);
      },
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $error'),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.book_outlined, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          Text('No books found for genre: $genre'),
        ],
      ),
    );
  }

  Widget _buildBookGrid(Map<String, Map<String, dynamic>> groupedBooks) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black, Colors.black87, Colors.black54],
        ),
      ),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.48,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
        ),
        itemCount: groupedBooks.length,
        itemBuilder: (context, index) => _buildBookCard(
          context,
          groupedBooks.values.elementAt(index),
        ),
      ),
    );
  }

  Widget _buildBookCard(BuildContext context, Map<String, dynamic> book) {
    return Card(
      elevation: 4,
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToDetail(context, book),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildBookImage(book),
            _buildBookInfo(book),
          ],
        ),
      ),
    );
  }

  Widget _buildBookImage(Map<String, dynamic> book) {
    return Expanded(
      flex: 5,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildImageOrPlaceholder(book['imageUrl']),
            _buildCopiesOverlay(book['totalCopies']),
          ],
        ),
      ),
    );
  }

  Widget _buildImageOrPlaceholder(String? imageUrl) {
    return imageUrl?.isNotEmpty == true
        ? Image.network(
            imageUrl!,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(child: CircularProgressIndicator());
            },
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
          )
        : _buildPlaceholder();
  }

  Widget _buildCopiesOverlay(int copies) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
          ),
        ),
        padding: const EdgeInsets.all(8),
        child: Text(
          '$copies copies available',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildBookInfo(Map<String, dynamic> book) {
    return Expanded(
      flex: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              book['title'] ?? 'No Title',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.white,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              book['writer'] ?? 'Unknown Writer',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Icon(Icons.book, size: 40, color: Colors.grey[400]),
    );
  }

  void _navigateToDetail(BuildContext context, Map<String, dynamic> book) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CourseBookDetailScreen(
          title: book['title'] ?? 'No Title',
          writer: book['writer'] ?? 'Unknown Writer',
          imageUrl: book['imageUrl'] ?? '',
          course: book['course'] ?? '',
          summary: book['summary'] ?? '',
          genre: (book['genre'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        ),
      ),
    );
  }

  Map<String, Map<String, dynamic>> _groupBooksByTitle(List<QueryDocumentSnapshot> books) {
    final groupedBooks = <String, Map<String, dynamic>>{};
    for (var book in books) {
      final data = book.data() as Map<String, dynamic>;
      final title = data['title'] ?? 'No Title';
      
      if (!groupedBooks.containsKey(title)) {
        groupedBooks[title] = {
          'title': title,
          'writer': data['writer'] ?? 'Unknown Writer',
          'imageUrl': data['imageUrl'] ?? '',
          'course': data['course'] ?? '',
          'summary': data['summary'] ?? '',
          'genre': data['genre'] ?? [],
          'totalCopies': 0,
        };
      }
      final copies = data['numberOfCopies'];
      groupedBooks[title]!['totalCopies'] += (copies is int) ? copies : 0;
    }
    return groupedBooks;
  }
}
