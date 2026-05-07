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
  String? _verificationId;
  Map<String, dynamic>? _signupConfig = {
    'step_labels': ['Contact', 'Security', 'Profile', 'Address'],
    'password_min_length': 8,
  };

  @override
  AppUser? get user => _user;
  
  @override
  bool get isLoading => _isLoading;
  
  @override
  String? get error => _error;
  
  @override
  bool get isLoggedIn => _user != null;

  @override
  String? get verificationId => _verificationId;

  @override
  Map<String, dynamic>? get signupConfig => _signupConfig;

  @override
  bool get isSocialUser => false;

  void setMockUser(AppUser? user) {
    _user = user;
    notifyListeners();
  }

  void setMockLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  @override
  void setLoading(bool val) {
    _isLoading = val;
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
  Future<AppUser?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    required Map<String, String> address,
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
  Future<void> loginWithPhone(String phoneNumber, {String? uid}) async {}

  @override
  Future<AppUser?> verifyOTP(String smsCode, {String? phoneNumber, String? uid}) async => _user;

  @override
  Future<Map<String, dynamic>?> fetchUserByPhone(String phone) async => null;

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<void> updateEmail(String newEmail) async {}

  @override
  void updatePhoneNumberLocally(String newPhone) {}
}
