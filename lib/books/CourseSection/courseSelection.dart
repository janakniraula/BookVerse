import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/home/screens/user/home/widget/bookList_Screen.dart';

class CourseSelectionScreen extends StatelessWidget {
  final String grade;

  const CourseSelectionScreen({super.key, required this.grade});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('$grade Courses'),
        elevation: 0,
        backgroundColor: isDark ? Colors.black : Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('books')
            .where('grade', isEqualTo: grade)
            .where('isCourseBook', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final courses = snapshot.data!.docs
              .map((book) => book['course'] as String?)
              .where((course) => course != null)
              .cast<String>()
              .toSet()
              .toList();

          return _buildCoursesGrid(context, courses, isDark);
        },
      ),
    );
  }

  Widget _buildCoursesGrid(BuildContext context, List<String> courses, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark 
              ? [Colors.black, Colors.black87, Colors.black54]
              : [Colors.white, Colors.white, Colors.grey[100]!],
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
        itemBuilder: (context, index) => _buildCourseCard(
          context, 
          courses[index],
          isDark,
        ),
      ),
    );
  }

  Widget _buildCourseCard(BuildContext context, String course, bool isDark) {
    return Card(
      elevation: 4,
      color: isDark ? Colors.grey[900] : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookListScreen(
              isCourseBook: true,
              filter: course,
            ),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: isDark 
                  ? [Colors.blue[900]!, Colors.blue[700]!]
                  : [Colors.blue[200]!, Colors.blue[400]!],
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
                color: isDark ? Colors.white.withOpacity(0.9) : Colors.white
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  course,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.white,
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
}
