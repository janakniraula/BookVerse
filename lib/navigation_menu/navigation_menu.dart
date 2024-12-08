import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../features/home/screens/user/home/home.dart';
import '../features/home/screens/user/mark/markApp.dart';
import '../features/home/screens/user/received/received.dart';
import '../features/home/screens/user/search/search.dart';
import '../features/personalization/profile/settings.dart';
import '../utils/constants/colors.dart';
import '../utils/helpers/helper_function.dart';

// Define the controller first
class NavigationController extends GetxController {
  static NavigationController get instance => Get.find();
  int selectedIndex = 2;

  void changeIndex(int index) {
    selectedIndex = index;
    update();
  }
}

class NavigationMenu extends StatelessWidget {
  const NavigationMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final darkMode = THelperFunction.isDarkMode(context);
    
    return GetBuilder<NavigationController>(
      init: NavigationController(),
      builder: (controller) {
        return Scaffold(
          bottomNavigationBar: NavigationBarTheme(
            data: NavigationBarThemeData(
              labelTextStyle: WidgetStateProperty.all(
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
                  'Browse',
                  controller.selectedIndex == 0,
                  darkMode,
                ),
                _buildNavDestination(
                  Iconsax.bookmark,
                  'Bookmark',
                  controller.selectedIndex == 1,
                  darkMode,
                ),
                _buildNavDestination(
                  Iconsax.home,
                  'Home',
                  controller.selectedIndex == 2,
                  darkMode,
                ),
                _buildNavDestination(
                  Iconsax.book_saved,
                  'Library',
                  controller.selectedIndex == 3,
                  darkMode,
                ),
                _buildNavDestination(
                  Iconsax.user,
                  'Profile',
                  controller.selectedIndex == 4,
                  darkMode,
                ),
              ],
            ),
          ),
          body: IndexedStack(
            index: controller.selectedIndex,
            children: const [
              SearchScreen(),
              MarkApp(),
              HomeScreen(),
              Received(),
              SettingScreen(),
            ],
          ),
        );
      },
    );
  }

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
}