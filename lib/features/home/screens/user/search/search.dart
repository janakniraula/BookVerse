import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../../books/detailScreen/course_book_detail_screen.dart';
import '../pdfView/pdflist.dart';
import 'BooksAll.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String query = '';
  List<DocumentSnapshot> searchResults = [];
  bool isLoading = false;
  String? userId;

  @override
  void initState() {
    super.initState();
    userId = FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _deleteSearchedBooks(String userId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('searchedBooks')
          .where('userId', isEqualTo: userId)
          .get();

      // Delete all documents for this user
      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }

      print('All previous searches for user $userId deleted successfully.');
    } catch (e) {
      print('Error deleting searched books for user $userId: $e');
    }
  }


  Future<void> _searchBooks(String query) async {
    if (query.isEmpty) {
      setState(() {
        searchResults = [];
      });
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;

      if (userId != null) {
        // Step 1: Delete previous searches for this user
        await _deleteSearchedBooks(userId);

        // Step 2: Fetch books matching the search query
        final uppercaseQuery = query.toUpperCase();
        final snapshot = await FirebaseFirestore.instance.collection('books').get();

        // Filter books based on title or writer containing the query
        final results = snapshot.docs.where((doc) {
          final data = doc.data();
          final bookTitle = (data['title'] as String?)?.toUpperCase() ?? '';
          final bookWriter = (data['writer'] as String?)?.toUpperCase() ?? '';
          return bookTitle.contains(uppercaseQuery) || bookWriter.contains(uppercaseQuery);
        }).toList();

        // Save results for the user in Firestore
        if (results.isNotEmpty) {
          await _saveSearchedBooks(query, userId, results);
        }

        setState(() {
          searchResults = results;
        });
      } else {
        setState(() {
          searchResults = [];
        });
      }
    } catch (e) {
      print('Error searching books: $e');
      setState(() {
        searchResults = [];
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _saveSearchedBooks(String searchQuery, String userId, List<QueryDocumentSnapshot> results) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      for (var doc in results) { // Use the passed `results` list
        final bookId = doc.id;
        final book = doc.data() as Map<String, dynamic>;
        final title = book['title']?.toString() ?? 'No title';
        final writer = book['writer']?.toString() ?? 'Unknown author';
        final imageUrl = book['imageUrl']?.toString() ?? '';
        final course = book['course']?.toString() ?? '';
        final summary = book['summary']?.toString() ?? 'No summary available';

        if (title.trim().toLowerCase() == searchQuery.trim().toLowerCase()) {
          final existingBookSnapshot = await FirebaseFirestore.instance
              .collection('searchedBooks')
              .where('userId', isEqualTo: userId)
              .where('bookId', isEqualTo: bookId)
              .get();

          if (existingBookSnapshot.docs.isEmpty) {
            final docRef = FirebaseFirestore.instance.collection('searchedBooks').doc();
            batch.set(docRef, {
              'userId': userId,
              'bookId': bookId,
              'title': title,
              'writer': writer,
              'imageUrl': imageUrl,
              'course': course,
              'summary': summary,
              'searchedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      await batch.commit();
      print('All matching books saved successfully.');
    } catch (e) {
      print('Failed to save searched books: $e');
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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AllPDFsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.menu_book),
            color: Colors.green,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AllBooksScreen()),
              );
            },
          ),


        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  query = value;
                });
                _searchBooks(value);
              },
              decoration: InputDecoration(
                labelText: 'Search',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                ),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Expanded(
            child: searchResults.isEmpty
                ? const Center(
              child: Text(
                'No results found',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
                : ListView.builder(
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                final book = searchResults[index].data() as Map<String, dynamic>;

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
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: imageUrl.isEmpty
                          ? const Icon(Icons.book, size: 50)
                          : Image.network(
                        imageUrl,
                        width: 50,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.book, size: 50);
                        },
                      ),
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(writer),
                    onTap: () {
                      Navigator.push(
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
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
