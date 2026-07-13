import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:dance_pulse/app/data/models/dance_models.dart';
import 'package:dance_pulse/app/data/services/supabase_store.dart';
import 'package:dance_pulse/app/modules/home_feed/feed_controller.dart';

import 'package:dance_pulse/app/modules/profile/profile_controller.dart';
import 'package:dance_pulse/app/modules/login/login_controller.dart';
import 'package:dance_pulse/app/modules/navigation_wrapper/navigation_controller.dart';

class AuthController extends GetxController {
  final SupabaseStore _dbHelper = SupabaseStore.instance;
  
  // Custom states
  DancerProfile? _currentUserProfile;
  bool _isLoading = true;
  bool _isLoggedIn = false;

  DancerProfile? get currentUserProfile => _currentUserProfile;
  set currentUserProfile(DancerProfile? profile) {
    _currentUserProfile = profile;
    update();
  }
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;

  @override
  void onInit() {
    super.onInit();
    _loadLocalSession();
  }

  Future<void> _loadLocalSession() async {
    _isLoading = true;
    update();
    try {
      final persistedUid = await _dbHelper.getPersistedSessionUid();
      if (persistedUid != null) {
        final profile = await _dbHelper.getUserProfile(persistedUid);
        if (profile != null) {
          _currentUserProfile = profile;
          _isLoggedIn = true;
          // Refresh feed controller data for the recovered session
          try {
            Get.find<FeedController>().refreshData();
          } catch (e) {
            debugPrint("Error refreshing feed on session recovery: $e");
          }
          return;
        }
      }
      _currentUserProfile = null;
      _isLoggedIn = false;
    } catch (e) {
      debugPrint("Error loading local session: $e");
      _currentUserProfile = null;
      _isLoggedIn = false;
    } finally {
      _isLoading = false;
      update();
    }
  }

  // Normal Sign In
  Future<bool> signInWithEmail(String email, String password) async {
    _isLoading = true;
    update();

    try {
      await Future.delayed(const Duration(seconds: 1));
      
      final profile = await _dbHelper.authenticateUser(email, password);
      if (profile == null) {
        throw Exception("Invalid email or password.");
      }
      
      await _dbHelper.persistSession(profile.uid);
      
      _isLoggedIn = true;
      _currentUserProfile = profile;
      _isLoading = false;
      update();

      // Clear any cached profile controllers on login
      Get.delete<ProfileController>(tag: 'me', force: true);

      // Refresh feed database state for the newly logged-in user
      try {
        Get.find<FeedController>().refreshData();
      } catch (e) {
        debugPrint("Error refreshing feed on login: $e");
      }

      return true;
    } catch (e) {
      _isLoading = false;
      update();
      debugPrint("Sign In Error: $e");
      rethrow;
    }
  }

  // Normal Sign Up
  Future<bool> signUpWithEmail(String email, String password, String name) async {
    _isLoading = true;
    update();

    try {
      await Future.delayed(const Duration(seconds: 1));
      
      final isEmailTaken = await _dbHelper.isEmailRegistered(email);
      if (isEmailTaken) {
        throw Exception("Email address is already registered.");
      }

      final username = email.split('@').first;
      final isUsernameTaken = await _dbHelper.isUsernameRegistered(username);
      final finalUsername = isUsernameTaken 
          ? "${username}_${DateTime.now().millisecondsSinceEpoch % 1000}" 
          : username;
      
      final newProfile = DancerProfile(
        uid: "user_${DateTime.now().millisecondsSinceEpoch}",
        username: finalUsername,
        displayName: name,
        avatarUrl: defaultAvatarUrl,
        bio: "Just joined the Dance Community! 🕺💃",
        followersCount: 0,
        followingCount: 0,
        likesCount: 0,
        danceStyles: ["All Styles"],
      );
      
      final createdProfile = await _dbHelper.registerUser(
        profile: newProfile,
        email: email,
        password: password,
      );
      if (createdProfile == null) {
        throw Exception("Could not register user.");
      }
      
      // Do NOT log the user in or persist session automatically.
      // The user must verify their email first and then manually sign in.
      _isLoading = false;
      update();

      return true;
    } catch (e) {
      _isLoading = false;
      update();
      debugPrint("Sign Up Error: $e");
      rethrow;
    }
  }


  // Sign Out
  Future<void> signOut() async {
    try {
      await _dbHelper.persistSession(null);
    } catch (e) {
      debugPrint("Error clearing persisted session: $e");
    }
    
    // Clear user specific states to prevent leak to the next session
    Get.delete<ProfileController>(tag: 'me', force: true);
    Get.delete<LoginController>(force: true);
    try {
      Get.find<NavigationController>().currentIndex.value = 0;
    } catch (_) {}

    _isLoggedIn = false;
    _currentUserProfile = null;
    update();

    // Refresh feed database state on logout
    try {
      Get.find<FeedController>().refreshData();
    } catch (e) {
      debugPrint("Error refreshing feed on logout: $e");
    }
  }

  Future<void> updateProfile(String name, String bio, {String? gender, DateTime? dateOfBirth}) async {
    if (_currentUserProfile != null) {
      final updatedProfile = DancerProfile(
        uid: _currentUserProfile!.uid,
        username: _currentUserProfile!.username,
        displayName: name,
        avatarUrl: _currentUserProfile!.avatarUrl,
        bio: bio,
        followersCount: _currentUserProfile!.followersCount,
        followingCount: _currentUserProfile!.followingCount,
        likesCount: _currentUserProfile!.likesCount,
        isVerified: _currentUserProfile!.isVerified,
        danceStyles: _currentUserProfile!.danceStyles,
        gender: gender,
        dateOfBirth: dateOfBirth,
      );
      
      await _dbHelper.saveUserProfile(updatedProfile);
      _currentUserProfile = updatedProfile;
      update();
    }
  }

  Future<bool> updateAvatar(String localPath) async {
    if (_currentUserProfile == null) return false;
    _isLoading = true;
    update();

    try {
      final avatarUrl = await _dbHelper.uploadAvatar(localPath, _currentUserProfile!.uid);
      
      final updatedProfile = DancerProfile(
        uid: _currentUserProfile!.uid,
        username: _currentUserProfile!.username,
        displayName: _currentUserProfile!.displayName,
        avatarUrl: avatarUrl,
        bio: _currentUserProfile!.bio,
        followersCount: _currentUserProfile!.followersCount,
        followingCount: _currentUserProfile!.followingCount,
        likesCount: _currentUserProfile!.likesCount,
        isVerified: _currentUserProfile!.isVerified,
        danceStyles: _currentUserProfile!.danceStyles,
      );

      await _dbHelper.saveUserProfile(updatedProfile);
      _currentUserProfile = updatedProfile;
      _isLoading = false;
      update();
      return true;
    } catch (e) {
      _isLoading = false;
      update();
      debugPrint("Error updating avatar: $e");
      return false;
    }
  }
}
