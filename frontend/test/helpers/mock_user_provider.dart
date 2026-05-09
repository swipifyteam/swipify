// ============================================================
// test/helpers/mock_user_provider.dart
// A mock implementation of UserProvider for widget testing.
// ============================================================
import 'package:flutter/foundation.dart';
import 'package:swipify/features/profile/service/user_provider.dart';
import 'package:swipify/models/user_model.dart';

class MockUserProvider extends ChangeNotifier implements UserProvider {
  UserModel? _profile;
  List<String> _claimedVoucherIds = [];
  bool _isLoading = false;

  @override
  UserModel? get profile => _profile;
  
  @override
  List<String> get claimedVoucherIds => _claimedVoucherIds;
  
  @override
  bool get isLoading => _isLoading;

  void setMockProfile(UserModel? profile) {
    _profile = profile;
    notifyListeners();
  }

  void setMockLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  @override
  Future<void> loadProfile(String uid) async {}

  @override
  Future<void> updateName(String uid, String newName) async {
    if (_profile != null) {
      _profile = UserModel(
        id: _profile!.id,
        name: newName,
        email: _profile!.email,
        role: _profile!.role,
        profileImage: _profile!.profileImage,
        phoneNumber: _profile!.phoneNumber,
        createdAt: _profile!.createdAt,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  @override
  Future<void> updateProfilePicture(String uid, List<int> bytes, String filename) async {}

  @override
  bool isVoucherClaimed(String voucherId) => _claimedVoucherIds.contains(voucherId);


  @override
  void clear() {
    _profile = null;
    _claimedVoucherIds = [];
    notifyListeners();
  }

  @override
  Future<void> updateEmail(String newEmail) async {
    if (_profile != null) {
      _profile = UserModel(
        id: _profile!.id,
        name: _profile!.name,
        email: newEmail,
        role: _profile!.role,
        profileImage: _profile!.profileImage,
        phoneNumber: _profile!.phoneNumber,
        createdAt: _profile!.createdAt,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  @override
  Future<void> updatePhoneNumber(String newPhone) async {
    if (_profile != null) {
      _profile = UserModel(
        id: _profile!.id,
        name: _profile!.name,
        email: _profile!.email,
        role: _profile!.role,
        profileImage: _profile!.profileImage,
        phoneNumber: newPhone,
        createdAt: _profile!.createdAt,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }
  
  @override
  Future<void> claimVoucher(String uid, String voucherId) {
    // TODO: implement claimVoucher
    throw UnimplementedError();
  }
}
