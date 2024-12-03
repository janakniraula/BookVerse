import 'package:book_Verse/books/detailScreen/pdflistscreen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import '../../features/home/screens/user/mark/provider.dart';

class CourseBookDetailScreen extends StatefulWidget {
  final String title;
  final String writer;
  final String imageUrl;
  final String course;
  final String summary;

  const CourseBookDetailScreen({
    super.key,
    required this.title,
    required this.writer,
    required this.imageUrl,
    required this.course,
    required this.summary,
  });

  @override
  _CourseBookDetailScreenState createState() => _CourseBookDetailScreenState();
}

class _CourseBookDetailScreenState extends State<CourseBookDetailScreen> {
  bool isBookmarked = false;
  bool isOutOfStock = false;
  late String userId;
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    _initializeUserId();
  }

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  Future<void> _initializeUserId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      userId = user.uid;
      if (_mounted) {
        await _checkIfBookmarked();
        await _checkAvailability();
      }
    }
  }

  Future<void> _checkIfBookmarked() async {
    if (!_mounted) return;
    
    final snapshot = await FirebaseFirestore.instance
        .collection('bookmarks')
        .where('title', isEqualTo: widget.title)
        .where('userId', isEqualTo: userId)
        .get();

    if (_mounted) {
      setState(() {
        isBookmarked = snapshot.docs.isNotEmpty;
      });
    }
  }

  Future<void> _checkAvailability() async {
    if (!_mounted) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('books')
        .where('title', isEqualTo: widget.title)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty && _mounted) {
      final bookData = snapshot.docs.first.data();
      setState(() {
        isOutOfStock = (bookData['numberOfCopies'] ?? 0) <= 0;
      });
    }
  }

  void _toggleBookmark() {
    if (isOutOfStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This book is out of stock and cannot be added.')),
      );
      return;
    }

    final bookData = {
      'title': widget.title,
      'writer': widget.writer,
      'imageUrl': widget.imageUrl,
      'course': widget.course,
      'summary': widget.summary,
      'userId': userId,
    };

    if (isBookmarked) {
      _removeBookmark(bookData);
    } else {
      _addBookmark(bookData);
    }
  }

  Future<void> _addBookmark(Map<String, dynamic> bookData) async {
    if (!_mounted) return;

    try {
      final bookSnapshot = await FirebaseFirestore.instance
          .collection('books')
          .where('title', isEqualTo: widget.title)
          .limit(1)
          .get();

      if (!_mounted) return;

      if (bookSnapshot.docs.isEmpty) {
        if (_mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Book not found'))
          );
        }
        return;
      }

      final bookId = bookSnapshot.docs.first.id;
      final bookDataWithId = {
        ...bookData,
        'bookId': bookId,
        'timestamp': FieldValue.serverTimestamp(),
      };

      final docRef = await FirebaseFirestore.instance.collection('bookmarks').add(bookDataWithId);
      
      if (!_mounted) return;

      Provider.of<BookmarkProvider>(context, listen: false).addBookmark({
        ...bookDataWithId,
        'id': docRef.id,
      });
      
      if (_mounted) {
        setState(() {
          isBookmarked = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.title} Added'))
        );
      }
    } catch (error) {
      if (_mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to Add: $error'))
        );
      }
    }
  }

  Future<void> _removeBookmark(Map<String, dynamic> bookData) async {
    if (!_mounted) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('bookmarks')
        .where('title', isEqualTo: widget.title)
        .where('userId', isEqualTo: userId)
        .get();

    if (!_mounted) return;

    if (snapshot.docs.isNotEmpty) {
      final docId = snapshot.docs.first.id;
      try {
        await FirebaseFirestore.instance.collection('bookmarks').doc(docId).delete();
        
        if (!_mounted) return;

        Provider.of<BookmarkProvider>(context, listen: false).removeBookmark({
          ...bookData,
          'id': docId,
        });
        
        if (_mounted) {
          setState(() {
            isBookmarked = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${widget.title} removed'))
          );
        }
      } catch (error) {
        if (_mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove: $error'))
          );
        }
      }
    }
  }

  Future<void> _viewPDFs() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('books')
        .where('title', isEqualTo: widget.title)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty || snapshot.docs.first.data()['pdfs'] == null) {
      _showNoPDFsDialog();
      return;
    }

    final pdfs = List<Map<String, dynamic>>.from(snapshot.docs.first.data()['pdfs']);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PDFListScreen2(pdfs: pdfs),
      ),
    );
  }



  void _showNoPDFsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No PDFs Found'),
        content: const Text('No PDFs are available for this book.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border),
            onPressed: _toggleBookmark,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _viewPDFs,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Image.network(
                  widget.imageUrl,
                  width: 190,
                  height: 280,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(child: Text('Image not available', style: TextStyle(color: Colors.red)));
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text('Title: ${widget.title}', style: Theme.of(context).textTheme.bodySmall),
              Text('Writer: ${widget.writer}', style: Theme.of(context).textTheme.bodySmall),
              Text('Course: ${widget.course}', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              Text('Summary:', style: Theme.of(context).textTheme.bodySmall),
              Text(widget.summary),
              if (isOutOfStock) ...[
                const SizedBox(height: 16),
                const Text('This book is currently out of stock.', style: TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
