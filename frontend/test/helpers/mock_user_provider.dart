// ============================================================
// test/helpers/mock_user_provider.dart
// A mock implementation of UserProvider for widget testing.
// ============================================================
import 'package:flutter/foundation.dart';
import 'package:swipify/features/profile/service/user_provider.dart';
import 'package:swipify/models/user_model.dart';
import 'package:swipify/models/product_model.dart';

class MockUserProvider extends ChangeNotifier implements UserProvider {
  UserModel? _profile;
  List<ProductModel> _likedProducts = [];
  List<ProductModel> _recentlyViewed = [];
  List<String> _claimedVoucherIds = [];
  bool _isLoading = false;

  @override
  UserModel? get profile => _profile;
  @override
  List<ProductModel> get likedProducts => _likedProducts;
  @override
  List<ProductModel> get recentlyViewed => _recentlyViewed;
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
        createdAt: _profile!.createdAt,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  @override
  Future<void> updateProfilePicture(String uid, List<int> bytes, String filename) async {}

  @override
  bool isLiked(String productId) => _likedProducts.any((p) => p.id == productId);

  @override
  Future<void> toggleLike(String uid, ProductModel product) async {}

  @override
  bool isVoucherClaimed(String voucherId) => _claimedVoucherIds.contains(voucherId);

  @override
  Future<void> claimVoucher(String voucherId) async {}

  @override
  void clear() {
    _profile = null;
    _likedProducts = [];
    _recentlyViewed = [];
    _claimedVoucherIds = [];
    notifyListeners();
  }
}
