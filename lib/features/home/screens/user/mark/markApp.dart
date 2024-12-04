import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:book_Verse/features/home/screens/user/mark/provider.dart';
import 'package:book_Verse/features/home/screens/user/mark/requestssss.dart';
import '../../../../../books/detailScreen/course_book_detail_screen.dart';
import '../../../../../utils/constants/colors.dart';
import '../../../../../utils/helpers/helper_function.dart';

class MarkApp extends StatelessWidget {
  const MarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BookmarkProvider(),
      child: const BookmarkScreen(),
    );
  }
}

class BookmarkScreen extends StatelessWidget {
  const BookmarkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bookmarks = Provider.of<BookmarkProvider>(context).bookmarks;
    final dark = THelperFunction.isDarkMode(context);

    final filteredBookmarks = bookmarks.where((book) {
      final title = book['title'];
      return title != null && title.isNotEmpty;
    }).toList();

    final bookCounts = <String, int>{};
    for (var book in filteredBookmarks) {
      final title = book['title']!;
      bookCounts[title] = (bookCounts[title] ?? 0) + 1;
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: dark ? TColors.black : TColors.white,
        title: Text(
          'Bookmark Manager',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 4,
                color: dark ? TColors.darkContainer : TColors.lightContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          Text(
                            filteredBookmarks.length.toString(),
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          Text(
                            'Total Books',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (bookCounts.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bookmark_border,
                      size: 64,
                      color: dark ? TColors.darkGrey : TColors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No bookmarks yet',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: dark ? TColors.darkGrey : TColors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Your Bookmarks',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final title = bookCounts.keys.elementAt(index);
                    final count = bookCounts[title]!;
                    final book = filteredBookmarks.firstWhere(
                      (b) => b['title'] == title,
                      orElse: () => {
                        'title': '',
                        'writer': '',
                        'imageUrl': '',
                        'course': '',
                        'summary': '',
                      },
                    );

                    return Card(
                      elevation: 2,
                      color: dark ? TColors.darkContainer : TColors.lightContainer,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _navigateToDetail(context, book),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _buildBookImage(book, context),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      title,
                                      style: Theme.of(context).textTheme.titleMedium,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      book['writer'] ?? '',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.copy, 
                                          size: 16, 
                                          color: dark ? TColors.darkGrey : TColors.grey
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$count copies',
                                          style: Theme.of(context).textTheme.labelMedium,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                color: TColors.error,
                                onPressed: () => _removeBookmark(context, book),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: bookCounts.keys.length,
                ),
              ),
            ),
          ],

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RequestedListScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.list_alt),
                      label: const Text('View Requested Books'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _saveBookmarksToRequests(context),
        icon: const Icon(Icons.save, color: Colors.white),
        label: const Text('Save All', style: TextStyle(color: Colors.white)),
        backgroundColor: TColors.primaryColor,
      ),
    );
  }

  Widget _buildBookImage(Map<String, dynamic> book, BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: (book['imageUrl'] ?? '').isNotEmpty
          ? Image.network(
              book['imageUrl']!,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildPlaceholderImage(context);
              },
            )
          : _buildPlaceholderImage(context),
    );
  }

  Widget _buildPlaceholderImage(BuildContext context) {
    final dark = THelperFunction.isDarkMode(context);
    return Container(
      width: 80,
      height: 80,
      color: dark ? TColors.darkGrey : TColors.grey,
      child: Icon(
        Icons.book,
        size: 40,
        color: dark ? TColors.white : TColors.black,
      ),
    );
  }

  void _navigateToDetail(BuildContext context, Map<String, dynamic> book) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CourseBookDetailScreen(
          title: book['title'] ?? '',
          writer: book['writer'] ?? '',
          imageUrl: book['imageUrl'] ?? '',
          course: book['course'] ?? '',
          summary: book['summary'] ?? '',
        ),
      ),
    );
  }

  Future<void> _removeBookmark(BuildContext context, Map<String, dynamic> book) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    final docId = book['id'];
    try {
      await FirebaseFirestore.instance.collection('bookmarks').doc(docId).delete();
      Provider.of<BookmarkProvider>(context, listen: false).removeBookmark(book);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${book['title']} removed from bookmarks')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove bookmark: $error')),
      );
    }
  }

  Future<void> _saveBookmarksToRequests(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    final bookmarks = Provider.of<BookmarkProvider>(context, listen: false).bookmarks;
    final uniqueBookmarks = <Map<String, dynamic>>[];
    final seenTitles = <String>{};

    for (var book in bookmarks) {
      final title = book['title'] ?? '';
      if (title.isNotEmpty && !seenTitles.contains(title)) {
        uniqueBookmarks.add(book);
        seenTitles.add(title);
      }
    }

    final issuedBooksSnapshot = await FirebaseFirestore.instance
        .collection('issuedBooks')
        .where('userId', isEqualTo: user.uid)
        .get();
    final issuedBooksTitles = issuedBooksSnapshot.docs
        .map((doc) => doc.data()['title'] as String)
        .toSet();

    final nonIssuedBooks = uniqueBookmarks
        .where((book) => !issuedBooksTitles.contains(book['title'] ?? ''))
        .toList();

    final existingRequestsSnapshot = await FirebaseFirestore.instance
        .collection('requests')
        .where('userId', isEqualTo: user.uid)
        .get();
    final existingRequests = existingRequestsSnapshot.docs
        .expand((doc) => (doc.data()['books'] as List)
        .map((book) => book['title'] ?? ''))
        .toSet();

    final alreadyRequestedBooks = nonIssuedBooks
        .where((book) => existingRequests.contains(book['title'] ?? ''))
        .map((book) => book['title'] ?? '')
        .toSet();

    final newlyAddedBooks = nonIssuedBooks
        .where((book) => !existingRequests.contains(book['title'] ?? ''))
        .toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Books Status'),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              if (issuedBooksTitles.isNotEmpty) ...[
                const Text('Already issued books:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(issuedBooksTitles.join(', ')),
                const SizedBox(height: 8),
              ],
              if (alreadyRequestedBooks.isNotEmpty) ...[
                const Text('Already requested books:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(alreadyRequestedBooks.join(', ')),
                const SizedBox(height: 8),
              ],
              if (newlyAddedBooks.isNotEmpty) ...[
                const Text('New books to be requested:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(newlyAddedBooks.map((book) => book['title']).join(', ')),
              ] else
                const Text('No new books to request.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          if (newlyAddedBooks.isNotEmpty)
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await FirebaseFirestore.instance.collection('requests').add({
                    'userId': user.uid,
                    'books': newlyAddedBooks,
                    'requestedAt': FieldValue.serverTimestamp(),
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Books added to your requests')),
                  );
                } catch (error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to add requests: $error')),
                  );
                }
              },
              child: const Text('Confirm'),
            ),
        ],
      ),
    );
  }
}