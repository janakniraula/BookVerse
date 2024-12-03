import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/home/screens/user/home/widget/bookList_Screen.dart';
import '../detailScreen/course_book_detail_screen.dart';

class CourseSelectionScreen extends StatelessWidget {
  final String grade;

  const CourseSelectionScreen({super.key, required this.grade});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Grade $grade Courses'),
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
          .where('grade', isEqualTo: grade)
          .where('isCourseBook', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final books = snapshot.data!.docs;
        final courses = _extractUniqueCourses(books);

        return courses.isEmpty 
            ? _buildBooksList(books)
            : _buildCoursesList(courses);
      },
    );
  }

  List<String> _extractUniqueCourses(List<QueryDocumentSnapshot> books) {
    return books
        .map((book) => book['course'] as String?)
        .where((course) => course != null)
        .cast<String>()
        .toSet()
        .toList();
  }

  Widget _buildCoursesList(List<String> courses) {
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
          childAspectRatio: 1.2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: courses.length,
        itemBuilder: (context, index) => _buildCourseCard(context, courses[index]),
      ),
    );
  }

  Widget _buildCourseCard(BuildContext context, String course) {
    return Card(
      elevation: 4,
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToCourseBooks(context, course),
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.book_outlined,
                size: 40,
                color: Colors.white.withOpacity(0.9),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  course,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBooksList(List<QueryDocumentSnapshot> books) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black, Colors.black87, Colors.black54],
        ),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: books.length,
        itemBuilder: (context, index) {
          final book = books[index].data() as Map<String, dynamic>;
          return _buildBookCard(context, book);
        },
      ),
    );
  }

  Widget _buildBookCard(BuildContext context, Map<String, dynamic> book) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToBookDetail(context, book),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            _buildBookImage(book),
            _buildBookInfo(book),
          ],
        ),
      ),
    );
  }

  Widget _buildBookImage(Map<String, dynamic> book) {
    return ClipRRect(
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
      child: book['imageUrl']?.isNotEmpty == true
          ? Image.network(
              book['imageUrl'],
              width: 100,
              height: 120,
              fit: BoxFit.cover,
            )
          : Container(
              width: 100,
              height: 120,
              color: Colors.grey[200],
              child: Icon(Icons.book, size: 40, color: Colors.grey[400]),
            ),
    );
  }

  Widget _buildBookInfo(Map<String, dynamic> book) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              book['title'] ?? 'No Title',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              book['writer'] ?? 'Unknown Writer',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Available Copies: ${book['numberOfCopies'] ?? 0}',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToCourseBooks(BuildContext context, String course) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookListScreen(
          isCourseBook: true,
          filter: course,
        ),
      ),
    );
  }

  void _navigateToBookDetail(BuildContext context, Map<String, dynamic> book) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CourseBookDetailScreen(
          title: book['title'] ?? 'No Title',
          writer: book['writer'] ?? 'Unknown Writer',
          imageUrl: book['imageUrl'] ?? '',
          course: book['course'] ?? '',
          summary: book['summary'] ?? '',
        ),
      ),
    );
  }
}
