import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../../../books/detailScreen/course_book_detail_screen.dart';

class BookListScreen extends StatelessWidget {
  final bool isCourseBook;
  final String? filter;

  const BookListScreen({super.key, required this.isCourseBook, this.filter});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isCourseBook ? 'Course Books' : 'Books'),
        backgroundColor: isDark ? Colors.black : Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark 
                ? [Colors.black, Colors.black87, Colors.black54]
                : [Colors.white, Colors.white, Colors.grey[100]!],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('books')
              .where('isCourseBook', isEqualTo: isCourseBook)
              .where(
                isCourseBook ? 'course' : 'genre',
                isEqualTo: filter?.isNotEmpty == true ? filter : null,
              )
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final groupedBooks = _groupBooks(snapshot.data!.docs);
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: groupedBooks.length,
              itemBuilder: (context, index) => _buildBookCard(
                context, 
                groupedBooks.values.elementAt(index),
                isDark,
              ),
            );
          },
        ),
      ),
    );
  }

  Map<String, Map<String, dynamic>> _groupBooks(List<QueryDocumentSnapshot> docs) {
    final groupedBooks = <String, Map<String, dynamic>>{};
    
    for (var doc in docs) {
      final book = doc.data() as Map<String, dynamic>;
      final title = book['title'] ?? 'No Title';
      
      if (!groupedBooks.containsKey(title)) {
        groupedBooks[title] = {
          'title': title,
          'writer': book['writer'] ?? 'Unknown Writer',
          'imageUrl': book['imageUrl'] ?? '',
          'genre': book['genre'] ?? '',
          'course': book['course'] ?? '',
          'summary': book['summary'] ?? '',
          'totalCopies': 0,
        };
      }
      groupedBooks[title]!['totalCopies'] += book['numberOfCopies'] ?? 0;
    }
    
    return groupedBooks;
  }

  Widget _buildBookCard(BuildContext context, Map<String, dynamic> book, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      color: isDark ? Colors.grey[900] : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CourseBookDetailScreen(
              title: book['title'],
              writer: book['writer'],
              imageUrl: book['imageUrl'],
              course: book['course'] ?? book['genre'] ?? '',
              summary: book['summary'],
            ),
          ),
        ),
        child: SizedBox(
          height: 180,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBookImage(book),
              _buildBookDetails(book, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookImage(Map<String, dynamic> book) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(12),
        bottomLeft: Radius.circular(12),
      ),
      child: book['imageUrl']?.isNotEmpty == true
          ? Image.network(
              book['imageUrl'],
              width: 120,
              height: 180,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
            )
          : _buildPlaceholderImage(),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 120,
      height: 180,
      color: Colors.grey[800],
      child: Icon(Icons.book, size: 40, color: Colors.grey[600]),
    );
  }

  Widget _buildBookDetails(Map<String, dynamic> book, bool isDark) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              book['title'],
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark ? Colors.white : Colors.black,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              book['writer'],
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[700],
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.book_outlined, 
                  size: 16, 
                  color: isDark ? Colors.grey[500] : Colors.grey[700]
                ),
                const SizedBox(width: 4),
                Text(
                  'Available: ${book['totalCopies']}',
                  style: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            if (book['course']?.isNotEmpty == true || 
                book['genre']?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8, 
                  vertical: 4
                ),
                decoration: BoxDecoration(
                  color: isDark 
                      ? Colors.blue.withOpacity(0.2)
                      : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  book['course'] ?? book['genre'] ?? '',
                  style: TextStyle(
                    color: isDark ? Colors.blue[300] : Colors.blue[700],
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
