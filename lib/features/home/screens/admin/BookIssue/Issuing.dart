import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:book_Verse/utils/constants/colors.dart';
import 'package:book_Verse/utils/helpers/helper_functions.dart';
import 'package:book_Verse/common/styles/shadows.dart';

class IssuedBooksScreen extends StatelessWidget {
  final String userId;

  const IssuedBooksScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final dark = THelperFunctions.isDarkMode(context);
    
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: dark ? TColors.black : TColors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: dark ? TColors.white : TColors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Issued Books',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: dark ? TColors.white : TColors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark 
                ? [
                    TColors.black,
                    TColors.black.withOpacity(0.87),
                    TColors.black.withOpacity(0.54),
                  ]
                : [
                    TColors.white,
                    TColors.white,
                    TColors.grey.withOpacity(0.1)
                  ],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('issuedBooks')
              .where('userId', isEqualTo: userId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  color: dark ? TColors.primaryColor : TColors.secondary,
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: TextStyle(
                    color: dark ? TColors.white : TColors.black,
                  ),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState(context, dark);
            }

            final sortedDocs = snapshot.data!.docs.toList()
              ..sort((a, b) {
                final aDate = (a.data() as Map<String, dynamic>)['issueDate'] as Timestamp;
                final bDate = (b.data() as Map<String, dynamic>)['issueDate'] as Timestamp;
                return bDate.compareTo(aDate); // Descending order
              });

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedDocs.length,
              itemBuilder: (context, index) {
                var bookData = sortedDocs[index].data() as Map<String, dynamic>;
                return _buildBookCard(context, bookData, dark);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool dark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_books,
            size: 64,
            color: dark ? TColors.darkGrey : TColors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'No books issued yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: dark ? TColors.darkGrey : TColors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookCard(BuildContext context, Map<String, dynamic> bookData, bool dark) {
    String imageUrl = bookData['imageUrl'] ?? '';
    String title = bookData['title'] ?? 'No Title';
    String writer = bookData['writer'] ?? 'Unknown';
    Timestamp timestamp = bookData['issueDate'] ?? Timestamp.now();
    String issueDate = DateFormat('MMM dd, yyyy').format(timestamp.toDate());

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: dark ? TColors.darkContainer : TColors.white,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [TShadowStyle.verticalProductShadow],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: 80,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildPlaceholderImage(dark),
                  )
                : _buildPlaceholderImage(dark),
          ),
          title: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: dark ? TColors.white : TColors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                writer,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: dark ? TColors.white.withOpacity(0.7) : TColors.black.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: dark ? TColors.darkGrey : TColors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Issued: $issueDate',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: dark ? TColors.darkGrey : TColors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(bool dark) {
    return Container(
      width: 80,
      height: 120,
      decoration: BoxDecoration(
        color: dark ? TColors.darkGrey : TColors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.book,
        size: 40,
        color: dark ? TColors.white.withOpacity(0.5) : TColors.black.withOpacity(0.5),
      ),
    );
  }
}