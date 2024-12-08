import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../../../utils/constants/colors.dart';
import '../../../../../utils/helpers/helper_function.dart';

class Received extends StatelessWidget {
  const Received({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final dark = THelperFunction.isDarkMode(context);

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: dark ? TColors.black : TColors.white,
          title: Text(
            'Books',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        body: Center(
          child: Text(
            'No user is logged in.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: dark ? TColors.black : TColors.white,
        elevation: 0,
        title: Text(
          'Books',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSectionHeader(context, 'Issued Books', dark),
            _buildIssuedBooksSection(context, userId, dark),
            const SizedBox(height: 16),
            _buildSectionHeader(context, 'Rejected Books', dark),
            _buildRejectedBooksSection(context, userId, dark),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, bool dark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: dark ? TColors.white : TColors.black,
        ),
      ),
    );
  }

  Widget _buildIssuedBooksSection(BuildContext context, String userId, bool dark) {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('issuedBooks')
            .where('userId', isEqualTo: userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(
                  fontSize: 16,
                  color: TColors.error,
                ),
              ),
            );
          }

          final issuedBooks = snapshot.data?.docs ?? [];
          
          if (issuedBooks.isEmpty) {
            return _buildEmptyState(context, 'No issued books', dark);
          }

          return ListView.builder(
            itemCount: issuedBooks.length,
            itemBuilder: (context, index) => _buildBookCard(
              context,
              issuedBooks[index].data() as Map<String, dynamic>,
              issuedBooks[index].id,
              true,
              dark,
            ),
          );
        },
      ),
    );
  }

  Widget _buildRejectedBooksSection(BuildContext context, String userId, bool dark) {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rejectedBooks')
            .where('userId', isEqualTo: userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(
                  fontSize: 16,
                  color: TColors.error,
                ),
              ),
            );
          }

          final rejectedBooks = snapshot.data?.docs ?? [];
          
          if (rejectedBooks.isEmpty) {
            return _buildEmptyState(context, 'No rejected books', dark);
          }

          return ListView.builder(
            itemCount: rejectedBooks.length,
            itemBuilder: (context, index) => _buildBookCard(
              context,
              rejectedBooks[index].data() as Map<String, dynamic>,
              rejectedBooks[index].id,
              false,
              dark,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message, bool dark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.book_outlined,
            size: 64,
            color: dark ? TColors.darkGrey : TColors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: dark ? TColors.darkGrey : TColors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookCard(
    BuildContext context,
    Map<String, dynamic> book,
    String docId,
    bool isIssued,
    bool dark,
  ) {
    DateTime? date = isIssued
        ? (book['issueDate'] as Timestamp?)?.toDate()
        : (book['rejectionDate'] as Timestamp?)?.toDate();
    String formattedDate = date != null
        ? DateFormat('yyyy-MM-dd – kk:mm').format(date)
        : 'N/A';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      color: dark ? TColors.darkContainer : TColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: dark ? TColors.darkGrey : TColors.grey,
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ListTile(
          leading: _buildBookImage(book['imageUrl']),
          title: Text(
            book['title'] ?? 'No Title',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: dark ? TColors.white : TColors.black,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Author: ${book['writer'] ?? 'Unknown'}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: dark ? TColors.white.withOpacity(0.7) : TColors.black.withOpacity(0.7),
                ),
              ),
              Text(
                '${isIssued ? 'Issued' : 'Rejection'} Date: $formattedDate',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: dark ? TColors.white.withOpacity(0.7) : TColors.black.withOpacity(0.7),
                ),
              ),
              if (!isIssued && book['rejectionReason'] != null)
                Text(
                  'Reason: ${book['rejectionReason']}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: TColors.error.withOpacity(0.8),
                  ),
                ),
            ],
          ),
          trailing: IconButton(
            icon: Icon(
              isIssued ? Icons.restore_from_trash : Icons.check_circle,
              color: isIssued ? TColors.error : TColors.success,
            ),
            onPressed: () {
              if (isIssued) {
                _confirmReturnBook(context, docId, book);
              } else {
                _removeBook(docId);
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBookImage(String? imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: Image.network(
        imageUrl ?? 'https://via.placeholder.com/150',
        width: 50,
        height: 75,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          final dark = THelperFunction.isDarkMode(context);
          return Container(
            width: 50,
            height: 75,
            color: dark ? TColors.darkGrey : TColors.grey,
            child: Icon(
              Icons.book,
              color: dark ? TColors.white : TColors.black,
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmReturnBook(BuildContext context, String docId, Map<String, dynamic> data) async {
    final bool? isConfirmed = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Return Book'),
          content: const Text('Are you sure you want to return this book?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (isConfirmed == true) {
      final toBeReturnedBooksCollection = FirebaseFirestore.instance.collection('toBeReturnedBooks');
      final issuedBooksCollection = FirebaseFirestore.instance.collection('issuedBooks');

      await toBeReturnedBooksCollection.add({
        ...data,
        'returnedDate': Timestamp.now(),
      });

      await issuedBooksCollection.doc(docId).delete();
    }
  }

  Future<void> _removeBook(String docId) async {
    final rejectedBooksCollection = FirebaseFirestore.instance.collection('rejectedBooks');
    await rejectedBooksCollection.doc(docId).delete();
  }
}
