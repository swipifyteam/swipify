// ============================================================
// test/helpers/mock_auth_provider.dart
// A mock implementation of AuthProvider for widget testing.
// ============================================================
import 'package:flutter/foundation.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/core/models/app_user.dart';

class MockAuthProvider extends ChangeNotifier implements AuthProvider {
  AppUser? _user;
  bool _isLoading = false;
  String? _error;

  @override
  AppUser? get user => _user;
  
  @override
  bool get isLoading => _isLoading;
  
  @override
  String? get error => _error;
  
  @override
  bool get isLoggedIn => _user != null;

  void setMockUser(AppUser? user) {
    _user = user;
    notifyListeners();
  }

  void setMockLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setMockError(String? error) {
    _error = error;
    notifyListeners();
  }

  @override
  Future<AppUser?> loginWithEmail(String email, String password) async {
    return _user;
  }

  @override
  Future<AppUser?> signUpWithEmail(
      String email, String password, String displayName, {
      String? username,
      String? phoneNumber,
      String? gender,
      String? dateOfBirth,
      bool signOutAfter = true,
  }) async {
    return _user;
  }

  @override
  Future<void> logout() async {
    _user = null;
    notifyListeners();
  }

  @override
  Future<void> signOut() async => logout();

  @override
  Future<AppUser?> loginWithFacebook() async => _user;

  @override
  Future<AppUser?> loginWithGoogle() async => _user;

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> refreshUserData() async {}

  @override
  Future<AppUser?> getCurrentUser() async => _user;

  @override
  Future<void> handlePendingRedirect() async {}

  @override
  Future<void> toggleFollowSeller(String sellerId) async {}

  @override
  Future<AppUser?> waitForProfile({Duration timeout = const Duration(seconds: 5)}) async {
    return _user;
  }

  @override
  Future<void> fetchSignupConfig() async {}

  @override
  Future<void> loginWithPhone(String phoneNumber) async {}

  @override
  Future<AppUser?> verifyOTP(String smsCode) async => _user;

  @override
  Future<Map<String, dynamic>?> fetchUserByPhone(String phone) async => null;

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<void> updateEmail(String newEmail) async {}

  @override
  void updatePhoneNumberLocally(String newPhone) {}
}
