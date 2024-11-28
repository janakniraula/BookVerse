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

class NavigationMenu extends StatelessWidget {
  const NavigationMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NavigationController());
    final darkMode = THelperFunction.isDarkMode(context);

    return Scaffold(
      bottomNavigationBar: Obx(
            () => Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: NavigationBar(
            height: 65,
            elevation: 0,
            selectedIndex: controller.selectedIndex.value,
            onDestinationSelected: (index) => controller.selectedIndex.value = index,
            backgroundColor: darkMode ? TColors.black : TColors.white,
            indicatorColor: darkMode
                ? TColors.white.withOpacity(0.1)
                : TColors.primaryColor.withOpacity(0.1),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              _buildNavDestination(
                Iconsax.book_1,
                'Browse',
                controller.selectedIndex.value == 0,
                darkMode,
              ),
              _buildNavDestination(
                Iconsax.bookmark,
                'Bookmark',
                controller.selectedIndex.value == 1,
                darkMode,
              ),
              _buildNavDestination(
                Iconsax.home,
                'Home',
                controller.selectedIndex.value == 2,
                darkMode,
              ),
              _buildNavDestination(
                Iconsax.book_saved,
                'Library',
                controller.selectedIndex.value == 3,
                darkMode,
              ),
              _buildNavDestination(
                Iconsax.user,
                'Profile',
                controller.selectedIndex.value == 4,
                darkMode,
              ),
            ],
          ),
        ),
      ),
      body: Obx(
            () => AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: KeyedSubtree(
            key: ValueKey<int>(controller.selectedIndex.value),
            child: controller.screens[controller.selectedIndex.value],
          ),
        ),
      ),
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

class NavigationController extends GetxController {
  static NavigationController get instance => Get.find();

  final Rx<int> selectedIndex = 2.obs;
  final RxList<Widget> screens = <Widget>[].obs;

  @override
  void onInit() {
    super.onInit();
    initializeScreens();
  }

  void initializeScreens() {
    screens.value = [
      const SearchScreen(),
      const MarkApp(),
      const HomeScreen(),
      const Received(),
      const SettingScreen(),
    ];
  }

  void changeIndex(int index) {
    selectedIndex.value = index;
  }

  @override
  void onClose() {
    screens.clear();
    super.onClose();
  }
}