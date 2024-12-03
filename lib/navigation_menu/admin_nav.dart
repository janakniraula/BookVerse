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

class AdminNavigationController extends GetxController {
  static AdminNavigationController get instance => Get.find();
  int selectedIndex = 2;

  void changeIndex(int index) {
    selectedIndex = index;
    update();
  }
}

class AdminNavigationMenu extends StatelessWidget {
  const AdminNavigationMenu({super.key});

  NavigationDestination _buildNavDestination(
    IconData icon,
    String label,
    bool isSelected,
    bool darkMode,
  ) {
    return NavigationDestination(
      icon: Icon(
        icon,
        size: 24,
        color: isSelected
            ? darkMode
                ? TColors.white
                : TColors.primaryColor
            : darkMode
                ? TColors.white.withOpacity(0.5)
                : TColors.darkGrey,
      ),
      label: label,
      selectedIcon: Icon(
        icon,
        size: 24,
        color: darkMode ? TColors.white : TColors.primaryColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = THelperFunction.isDarkMode(context);
    
    return GetBuilder<AdminNavigationController>(
      init: AdminNavigationController(),
      builder: (controller) {
        return Scaffold(
          bottomNavigationBar: NavigationBarTheme(
            data: NavigationBarThemeData(
              labelTextStyle: MaterialStateProperty.all(
                TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: darkMode ? TColors.white : TColors.black,
                ),
              ),
            ),
            child: NavigationBar(
              height: 65,
              elevation: 0,
              selectedIndex: controller.selectedIndex,
              backgroundColor: darkMode ? TColors.black : TColors.white,
              indicatorColor: darkMode
                  ? TColors.white.withOpacity(0.1)
                  : TColors.primaryColor.withOpacity(0.1),
              onDestinationSelected: controller.changeIndex,
              destinations: [
                _buildNavDestination(
                  Iconsax.book_1,
                  'Add Books',
                  controller.selectedIndex == 0,
                  darkMode,
                ),
                _buildNavDestination(
                  Iconsax.edit,
                  'Edit',
                  controller.selectedIndex == 1,
                  darkMode,
                ),
                _buildNavDestination(
                  Iconsax.home,
                  'Dashboard',
                  controller.selectedIndex == 2,
                  darkMode,
                ),
                _buildNavDestination(
                  Iconsax.message_question,
                  'Requests',
                  controller.selectedIndex == 3,
                  darkMode,
                ),
                _buildNavDestination(
                  Iconsax.setting,
                  'Settings',
                  controller.selectedIndex == 4,
                  darkMode,
                ),
              ],
            ),
          ),
          body: IndexedStack(
            index: controller.selectedIndex,
            children: const [
              AddBooks(),
              SearchBookScreen(),
              Dashboard(),
              AdminUserRequestsScreen(),
              AdminSettingsScreen(),
            ],
          ),
        );
      },
    );
  }
}