import 'package:book_Verse/data/authentication/repository/authentication/admin_auth_repo.dart';
import 'package:book_Verse/features/home/screens/admin/navigations/requests.dart';
import 'package:book_Verse/features/home/screens/admin/returnedbooks/bookreturnUserScreen.dart';
import 'package:book_Verse/features/home/screens/admin/widgets/adminScreen.dart';
import 'package:book_Verse/features/home/screens/admin/widgets/adminprofile.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../../common/widgets/appbar/appbar.dart';
import '../../../../../common/widgets/custom_shapes/primary_header_container.dart';
import '../../../../../common/widgets/texts/section_heading.dart';
import '../../../../../utils/constants/sizes.dart';
import '../../DataForAdmin/usersdata.dart';
import '../BookIssue/users.dart';
import 'editScreen.dart';
import '../notification/notificationScreen.dart';

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});
  final Color lightGreen = const Color(0xFF0C8904); // Updated to match dashboard

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TPrimaryHeaderContainer(
              child: Column(
                children: [
                  TAppBar(
                    title: Text(
                      'Settings',
                      style: Theme.of(context).textTheme.headlineMedium!.apply(color: Colors.white),
                    ),
                  ),
                  TAdminProfileTitle(onPressed: () => Get.to(() => const AdminScreen())),
                  const SizedBox(height: TSizes.spaceBtwSections),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: TSizes.defaultSpace),
              child: Column(
                children: [
                  ListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      const TSectionHeading(title: 'Features', showActionButton: false,),
                      _buildSettingItem(
                        context,
                        icon: Iconsax.notification,
                        title: 'Notification',
                        subTitle: 'Send Notification to Users',
                        onTap: () => Get.to(() => const NotificationScreen()),
                      ),
                      const Divider(),
                      _buildSettingItem(
                        context,
                        icon: Iconsax.book_1,
                        title: 'Issued Books',
                        subTitle: 'List books that the Librarian has Issued',
                        onTap: () => Get.to(() => const UsersListScreen()),
                      ),
                      const Divider(),
                      _buildSettingItem(
                        context,
                        icon: Iconsax.document_upload,
                        title: 'Request List',
                        subTitle: 'Books that to be Issued',
                        onTap: () => Get.to(() => const AdminUserRequestsScreen()),
                      ),
                      const Divider(),
                      _buildSettingItem(
                        context,
                        icon: Iconsax.timer_1,
                        title: 'Book Return',
                        subTitle: 'List books that the user has to return',
                        onTap: () => Get.to(() => const AcceptReturnUsersScreen()),
                      ),
                      const Divider(),
                      _buildSettingItem(
                        context,
                        icon: Iconsax.data,
                        title: 'DATA',
                        subTitle: 'DATA available here',
                        onTap: () => Get.to(() => const UserListPage()),
                      ),
                      const Divider(),
                      _buildSettingItem(
                        context,
                        icon: Iconsax.search_normal,
                        title: 'Search Screen',
                        subTitle: 'Search Books',
                        onTap: () => Get.to(() => const SearchBookScreen()),
                      ),
                      const Divider(),
                      const SizedBox(height: TSizes.spaceBtwSections),
                      ElevatedButton(
                        onPressed: () {
                          _showLogoutConfirmationDialog(context);
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: lightGreen,
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: const Text('Logout', style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(height: TSizes.spaceBtwSections),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem(BuildContext context, {
    required IconData icon,
    required String title,
    required String subTitle,
    required VoidCallback onTap
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: lightGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: lightGreen, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subTitle,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: lightGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.arrow_forward_ios,
            color: lightGreen,
            size: 16,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Cancel',
                style: TextStyle(color: lightGreen),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(
                'Confirm',
                style: TextStyle(color: lightGreen),
              ),
              onPressed: () {
                Get.find<AdminAuthenticationRepository>().logout();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}