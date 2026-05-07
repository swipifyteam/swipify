import 'package:flutter/material.dart';
import 'package:swipify/models/user_model.dart';
import 'package:swipify/services/api_service.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _profile;
  List<String> _claimedVoucherIds = [];
  bool _isLoading = false;

  UserModel? get profile => _profile;
  List<String> get claimedVoucherIds => _claimedVoucherIds;
  bool get isLoading => _isLoading;

  Future<void> loadProfile(String uid) async {
    _isLoading = true;
    notifyListeners();
    try {
      _profile = await ApiService.getUserProfile(uid);
    } catch (e) {
      debugPrint('[USER PROVIDER] Load error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateName(String uid, String newName) async {
    try {
      await ApiService.updateUserProfile(uid, {'name': newName});
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
    } catch (e) {
      debugPrint('[USER PROVIDER] Update name error: $e');
      rethrow;
    }
  }

  Future<void> updateProfilePicture(String uid, List<int> bytes, String filename) async {
    _isLoading = true;
    notifyListeners();
    try {
      final imageUrl = await ApiService.uploadProfilePicture(uid, bytes, filename);
      if (_profile != null) {
        _profile = UserModel(
          id: _profile!.id,
          name: _profile!.name,
          email: _profile!.email,
          role: _profile!.role,
          profileImage: imageUrl,
          phoneNumber: _profile!.phoneNumber,
          createdAt: _profile!.createdAt,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[USER PROVIDER] Upload error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  bool isVoucherClaimed(String voucherId) {
    return _claimedVoucherIds.contains(voucherId);
  }

  Future<void> claimVoucher(String voucherId) async {
    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 800));
    if (!_claimedVoucherIds.contains(voucherId)) {
      _claimedVoucherIds.add(voucherId);
      notifyListeners();
    }
  }

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

  void clear() {
    _profile = null;
    _claimedVoucherIds = [];
    notifyListeners();
  }
}
