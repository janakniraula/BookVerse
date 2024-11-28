import 'package:book_Verse/common/network_check/network_manager.dart';
import 'package:book_Verse/utils/popups/fullscreen_loader.dart';
import 'package:book_Verse/utils/popups/loaders.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../../../../data/authentication/repository/authentication/admin_auth_repo.dart';
import '../../../../utils/constants/image_strings.dart';
import '../../../personalization/controller/admin_Controller.dart';

class AdminLoginController extends GetxController {

  final rememberMe = false.obs;
  final hidePassword = true.obs;
  final localStorage = GetStorage();
  final email = TextEditingController();
  final password = TextEditingController();
  GlobalKey<FormState> adminloginFormKey = GlobalKey<FormState>();
  final adminController = Get.put(AdminController());
  final selectedRole = 'Admin'.obs; // Default to Admin role

  /// -- Email and Password Sign In
  Future<void> emailAndPasswordSignIn() async {
    try {
      TFullScreenLoader.openLoadingDialogue('Logging you in...', TImages.checkRegistration);

      // Check internet connection
      final isConnected = await NetworkManager.instance.isConnected();
      if (!isConnected) {
        TFullScreenLoader.stopLoading();
        TLoaders.errorSnackBar(title: 'No Internet', message: 'Please check your internet connection.');
        return;
      }

      // Validate form
      if (!adminloginFormKey.currentState!.validate()) {
        TFullScreenLoader.stopLoading();
        return;
      }

      // Save credentials if Remember Me is selected
      if (rememberMe.value) {
        localStorage.write('Admin_Remember_Me_Email', email.text.trim());
        localStorage.write('Admin_Remember_Me_Password', password.text.trim());
      }

      // Perform login
      final userCredentials = await AdminAuthenticationRepository.instance.loginWithEmailAndPassword(
        email.text.trim(),
        password.text.trim(),
      );

      // Fetch role from Firestore
      final Role = await AdminAuthenticationRepository.instance.getAdminRole(userCredentials.user!.uid);
      if (Role != 'Admin') {
        throw Exception('You are not authorized to log in as an Admin.');
      }

      TFullScreenLoader.stopLoading();
      AdminAuthenticationRepository.instance.screenRedirect();
    } catch (e) {
      TFullScreenLoader.stopLoading();
      TLoaders.errorSnackBar(title: 'Login Failed', message: e.toString());
    }
  }



  /// -- Google Sign In Authentication
  Future<void> googleSignIn() async {
    try {
      TFullScreenLoader.openLoadingDialogue('Logging you in...', TImages.checkRegistration);

      // Checking Internet connection
      final isConnected = await NetworkManager.instance.isConnected();
      if (!isConnected) {
        TFullScreenLoader.stopLoading();
        TLoaders.errorSnackBar(title: 'No Internet', message: 'Please check your internet connection.');
        return;
      }

      // Google authentication
      final userCredentials = await AdminAuthenticationRepository.instance.signInWithGoogle();

      // Save user records
      await adminController.saveAdminRecord(userCredentials);
      TFullScreenLoader.stopLoading();

      // Redirect
      AdminAuthenticationRepository.instance.screenRedirect();
    } catch (e) {
      TFullScreenLoader.stopLoading();
      TLoaders.errorSnackBar(title: 'Oh Snap', message: e.toString());
    }
  }
}