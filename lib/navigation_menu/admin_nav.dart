import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../features/home/screens/admin/navigations/addBooks.dart';
import '../features/home/screens/admin/navigations/dashboard.dart';
import '../features/home/screens/admin/navigations/editScreen.dart';
import '../features/home/screens/admin/navigations/requests.dart';
import '../features/home/screens/admin/navigations/settingScreen.dart';
import '../utils/constants/colors.dart';
import '../utils/helpers/helper_function.dart';

class AdminNavigationMenu extends StatelessWidget {
  const AdminNavigationMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AdminNavigationController());
    final darkMode = THelperFunction.isDarkMode(context);

    return Scaffold(
      bottomNavigationBar: Obx(
            () => NavigationBar(
          height: 65,
          elevation: 0,
          selectedIndex: controller.selectedIndex.value,
          onDestinationSelected: controller.onDestinationSelected,
          backgroundColor: darkMode
              ? TColors.black
              : Colors.white.withOpacity(0.1),
          indicatorColor: darkMode
              ? TColors.white.withOpacity(0.3)
              : TColors.black.withOpacity(0.3),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Iconsax.book_1),
              label: 'Add Books',
            ),
            NavigationDestination(
              icon: Icon(Iconsax.edit),
              label: 'Edit',
            ),
            NavigationDestination(
              icon: Icon(Iconsax.home),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Iconsax.message_question),
              label: 'Requests',
            ),
            NavigationDestination(
              icon: Icon(Iconsax.setting),
              label: 'Settings',
            ),
          ],
        ),
      ),
      body: Obx(
            () => AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: controller.currentScreen,
        ),
      ),
    );
  }
}

class AdminNavigationController extends GetxController {
  static AdminNavigationController get instance => Get.find();

  final Rx<int> selectedIndex = 2.obs;

  final List<Widget> screens = const [
    AddBooks(),                  // index 0 - Add Books
    SearchBookScreen(),          // index 1 - Edit
    Dashboard(),                 // index 2 - Dashboard (default)
    AdminUserRequestsScreen(),   // index 3 - Requests
    AdminSettingsScreen(),       // index 4 - Settings
  ];

  Widget get currentScreen => screens[selectedIndex.value];

  void onDestinationSelected(int index) {
    selectedIndex.value = index;
  }


}