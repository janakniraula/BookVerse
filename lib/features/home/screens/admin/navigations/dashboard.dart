import 'package:book_Verse/features/home/screens/admin/widgets/adminappbar.dart';
import 'package:book_Verse/utils/constants/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../../common/widgets/custom_shapes/primary_header_container.dart';
import '../../../../../utils/constants/sizes.dart';
import '../BookIssue/Issuing.dart';
import '../USersScreen/allUser.dart';
import '../allbooks.dart';
import '../returnedbooks/bookreturn.dart';
import 'package:book_Verse/utils/helpers/helper_function.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final _firestore = FirebaseFirestore.instance;
  late Future<List<QuerySnapshot>> _futureData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _futureData = Future.wait([
      _firestore.collection('books').get(),
      _firestore.collection('Users').get(),
      _firestore.collection('issuedBooks').get(),
      _firestore.collection('toBeReturnedBooks').get(),
      _firestore.collection('notifications').get(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = THelperFunction.isDarkMode(context);
    
    return Scaffold(
      backgroundColor: isDark ? TColors.black : TColors.white,
      body: RefreshIndicator(
        color: TColors.primaryColor,
        onRefresh: () async => setState(() => _loadData()),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              const TPrimaryHeaderContainer(
                child: Column(
                  children: [
                    SizedBox(height: TSizes.sm),
                    TAdminAppBar(),
                    SizedBox(height: TSizes.spaceBtwSections),
                  ],
                ),
              ),
              _buildDashboardContent(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardContent(bool isDark) {
    return FutureBuilder<List<QuerySnapshot>>(
      future: _futureData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(color: TColors.primaryColor),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const Text(
                    'Error loading data',
                    style: TextStyle(color: TColors.error),
                  ),
                  ElevatedButton(
                    onPressed: () => setState(() => _loadData()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TColors.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final [books, users, issuedBooks, returnedBooks, notifications] = snapshot.data!;

        return Container(
          color: isDark ? TColors.black : TColors.white,
          padding: const EdgeInsets.all(TSizes.defaultSpace),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatCard('Total Books', Icons.book, books.size.toString(), const AllBooksScreenAdmin(), isDark),
              _buildStatCard('Total Users', Icons.people, users.size.toString(), const AllUsersScreen(), isDark),
              _buildNotificationsSection(context, notifications.size, isDark),
              _buildIssuedBooksSection(issuedBooks.docs, isDark),
              _buildReturnedBooksSection(returnedBooks.docs, isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, IconData icon, String value, Widget destination, bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => destination)),
      child: Container(
        margin: const EdgeInsets.only(bottom: TSizes.spaceBtwItems),
        padding: const EdgeInsets.all(TSizes.md),
        decoration: BoxDecoration(
          color: isDark ? TColors.black : TColors.white,
          borderRadius: BorderRadius.circular(TSizes.cardRadiusLg),
          border: Border.all(color: isDark ? TColors.darkGrey : TColors.grey),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(TSizes.sm),
              decoration: BoxDecoration(
                color: TColors.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(TSizes.cardRadiusMd),
              ),
              child: Icon(icon, color: TColors.primaryColor, size: 24),
            ),
            const SizedBox(width: TSizes.spaceBtwItems),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: isDark ? TColors.white : TColors.black,
                    ),
                  ),
                  const SizedBox(height: TSizes.xs),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: TColors.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: isDark ? TColors.white : TColors.black,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsSection(BuildContext context, int notificationCount, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? TColors.black : TColors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDark ? TColors.darkGrey : TColors.grey),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('notifications')
              .orderBy('timestamp', descending: true)
              .limit(5)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final notifications = snapshot.data!.docs;
            return ExpansionTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: TColors.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.notifications, color: TColors.primaryColor, size: 20),
              ),
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              backgroundColor: Colors.transparent,
              collapsedBackgroundColor: Colors.transparent,
              title: Row(
                children: [
                  const Text(
                    'Recent Notifications',
                    style: TextStyle(
                      color: TColors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: TColors.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      notificationCount.toString(),
                      style: TextStyle(
                        color: TColors.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              children: [
                Container(
                  color: isDark ? TColors.black : TColors.white,
                  constraints: BoxConstraints(
                    maxHeight: notifications.length > 3 ? 200 : notifications.length * 72.0,
                    minHeight: 0,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final data = notifications[index].data() as Map<String, dynamic>;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        title: Text(
                          data['message'] ?? 'No message',
                          style: const TextStyle(
                            color: TColors.black,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          _formatDate(data['timestamp'] as Timestamp),
                          style: const TextStyle(
                            color: TColors.grey,
                            fontSize: 12,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: TColors.error, size: 20),
                          onPressed: () => _deleteNotification(notifications[index].id),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildIssuedBooksSection(List<QueryDocumentSnapshot> issuedBooks, bool isDark) {
    return _buildExpandableSection(
      'Issued Books',
      Icons.book_online,
      issuedBooks,
          (userId) => IssuedBooksScreen(userId: userId),
      isDark,
    );
  }

  Widget _buildReturnedBooksSection(List<QueryDocumentSnapshot> returnedBooks, bool isDark) {
    return _buildExpandableSection(
      'Returned Books',
      Icons.assignment_return,
      returnedBooks,
          (userId) => AcceptReturnedBooksScreen(userId: userId),
      isDark,
    );
  }

  Widget _buildExpandableSection(
      String title,
      IconData icon,
      List<QueryDocumentSnapshot> docs,
      Widget Function(String) destinationBuilder,
      bool isDark,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? TColors.black : TColors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDark ? TColors.darkGrey : TColors.grey),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: TColors.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: TColors.primaryColor, size: 20),
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
          title: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: TColors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: TColors.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  docs.length.toString(),
                  style: const TextStyle(
                    color: TColors.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          children: [
            Container(
              color: isDark ? TColors.black : TColors.white,
              constraints: BoxConstraints(
                maxHeight: docs.length > 3 ? 200 : docs.length * 72.0,
                minHeight: 0,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final userId = data['userId'] ?? 'Unknown';
                  return FutureBuilder<DocumentSnapshot>(
                    future: _firestore.collection('Users').doc(userId).get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox();
                      final userData = snapshot.data!.data() as Map<String, dynamic>?;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        title: Text(
                          userData?['UserName'] ?? 'Unknown User',
                          style: const TextStyle(
                            color: TColors.black,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          userData?['Email'] ?? 'No email',
                          style: const TextStyle(
                            color: TColors.grey,
                            fontSize: 12,
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, color: TColors.grey, size: 18),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => destinationBuilder(userId)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _deleteNotification(String docId) async {
    try {
      await _firestore.collection('notifications').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification deleted'),
            backgroundColor: TColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: TColors.error,
          ),
        );
      }
    }
  }
}