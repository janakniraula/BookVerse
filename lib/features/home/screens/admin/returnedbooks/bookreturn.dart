import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AcceptReturnedBooksScreen extends StatelessWidget {
  final String userId;
  final _dateFormat = DateFormat('dd MMMM yyyy');
  final _firestore = FirebaseFirestore.instance;

  AcceptReturnedBooksScreen({required this.userId, super.key});

  Widget _buildBookImage(String? imageUrl) {
    return SizedBox(
      width: 60,
      height: 90,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: imageUrl?.isNotEmpty == true
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : const Center(child: CircularProgressIndicator()),
              )
            : const Icon(Icons.book),
      ),
    );
  }

  Future<void> _acceptReturn(String docId, String bookId, Map<String, dynamic> bookData) async {
    try {
      final batch = _firestore.batch();
      
      // Delete return request
      batch.delete(_firestore.collection('toBeReturnedBooks').doc(docId));

      // Get user data first
      final userDoc = await _firestore.collection('Users').doc(userId).get();
      if (!userDoc.exists) return;

      // Prepare DATA document
      final dataDoc = _firestore.collection('DATA').doc();
      batch.set(dataDoc, {
        'UserId': userId,
        'UserName': userDoc.get('UserName'),
        'Email': userDoc.get('Email'),
        'PhoneNumber': userDoc.get('PhoneNumber'),
        'Image': bookData['imageUrl'],
        'BookName': bookData['title'],
        'IssueDate': bookData['issueDate'],
        'AcceptedDate': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // Update book copies in a separate transaction
      await _firestore.runTransaction((transaction) async {
        final bookDoc = await transaction.get(_firestore.collection('books').doc(bookId));
        if (bookDoc.exists) {
          final currentCopies = bookDoc.get('numberOfCopies') as int;
          transaction.update(bookDoc.reference, {'numberOfCopies': currentCopies + 1});
        }
      });
    } catch (e) {
      debugPrint('Error accepting return: $e');
    }
  }

  Widget _buildBookCard(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final issueDate = data["issueDate"] is Timestamp 
        ? (data["issueDate"] as Timestamp).toDate()
        : null;

    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        leading: _buildBookImage(data["imageUrl"]),
        title: Text(
          data['title'] as String,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data["writer"] as String),
            if (issueDate != null)
              Text('Issue Date: ${_dateFormat.format(issueDate)}'),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.check_circle, color: Colors.green),
          onPressed: () => _showAcceptDialog(context, doc, data),
        ),
      ),
    );
  }

  void _showAcceptDialog(BuildContext context, DocumentSnapshot doc, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Book Return'),
        content: const Text('Are you sure you want to accept this returned book?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Accept'),
            onPressed: () {
              _acceptReturn(doc.id, data['bookId'], data);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Books to be Returned')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('toBeReturnedBooks')
            .where('userId', isEqualTo: userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No books to accept for return.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) => _buildBookCard(context, snapshot.data!.docs[index]),
          );
        },
      ),
    );
  }
}
