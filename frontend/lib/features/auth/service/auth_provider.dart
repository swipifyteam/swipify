// lib/providers/auth_provider.dart
// Centralized authentication state management.
// ALL Firebase Auth operations go through this provider — never in widgets/UI.
// Facebook login uses redirect flow on web (not popup) to avoid browser issues.

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:swipify/core/models/app_user.dart';
import 'package:swipify/core/utils/phone_utils.dart';
import 'package:swipify/services/api_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';

class AuthProvider extends ChangeNotifier {
  AppUser? _user;
  bool _isLoading = false;
  String? _error;
  String? _verificationId;
  StreamSubscription<DocumentSnapshot>? _userStreamSubscription;
  Map<String, dynamic> _signupConfig = {
    'step_labels': ['Contact', 'Security', 'Profile', 'Address'],
    'password_min_length': 8,
  };
  String? _pendingPhone;
  String? _pendingUid;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;
  String? get error => _error;
  String? get verificationId => _verificationId;
  Map<String, dynamic>? get signupConfig => _signupConfig;
  /// Returns true if the user is logged in ONLY via a social provider (Google/Facebook)
  /// and does not have a native email/password account.
  bool get isSocialUser => FirebaseAuth.instance.currentUser?.providerData.every((p) => p.providerId != 'password') ?? false;

  void setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  AuthProvider() {
    _init();
  }

  // ── Initialization ─────────────────────────────────────────────────────────

  Future<void> _init() async {
    debugPrint('[AUTH] Initializing AuthProvider — listening to authStateChanges');
    // 1. Initial listener for Firebase Auth state
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      await _onAuthStateChanged(user);
    });
    
    // 2. Fetch data-driven configuration from Firestore
    await fetchSignupConfig();
  }

  Future<void> fetchSignupConfig() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('signup_config').get();
      if (doc.exists && doc.data() != null) {
        _signupConfig = doc.data()!;
        debugPrint('[AUTH] Fetched data-driven signup config');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AUTH] Failed to fetch signup config: $e');
    }
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    _userStreamSubscription?.cancel();
    _userStreamSubscription = null;

    if (firebaseUser != null) {
      debugPrint('[USER] Auth user: ${firebaseUser.uid}');
      debugPrint('[USER] Starting stream...');
      
      // Set initial user state immediately to avoid null-checks in UI
      _user = AppUser.fromFirebaseUser(firebaseUser);
      debugPrint('[USER] _user set in _onAuthStateChanged: ${_user?.uid}');
      notifyListeners();

      try {
        // Start a stream to reactively update the local profile (e.g., when sellerStatus: APPROVED)
        _userStreamSubscription = FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .snapshots()
            .listen((snapshot) {
          if (snapshot.exists) {
            final userData = snapshot.data();
            _user = AppUser.fromFirebaseUser(firebaseUser, extraData: userData);
            debugPrint('[USER] Stream success: sellerStatus=${_user!.sellerStatus}');
            notifyListeners();
          }
        }, onError: (e) {
          debugPrint('[USER] Stream error: $e');
        });

        // ── Device Token (FIRE AND FORGET) ──────────────────────────────────
        unawaited(_updateDeviceToken(firebaseUser.uid));
      } catch (e) {
        debugPrint('[USER] Listener setup failed: $e');
        _user = AppUser.fromFirebaseUser(firebaseUser);
        notifyListeners();
      }
    } else {
      debugPrint('[AUTH] User signed out — clearing state');
      _user = null;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> fetchUserByPhone(String phone) async {
    // Normalize to E.164 before querying
    final normalized = PhoneUtils.normalizePH(phone);
    if (normalized.isEmpty) {
      debugPrint('[AUTH] fetchUserByPhone: could not normalize "$phone"');
      return null;
    }
    debugPrint('[AUTH] fetchUserByPhone: querying Firestore with $normalized');

    try {
      // 1. Primary query on normalized 'phone_number' field
      var snap = await FirebaseFirestore.instance
          .collection('users')
          .where('phone_number', isEqualTo: normalized)
          .limit(1)
          .get();
      
      // 2. Fallback query on legacy 'phone' field if not found
      if (snap.docs.isEmpty) {
        debugPrint('[AUTH] fetchUserByPhone: no result for "phone_number", trying "phone" field');
        snap = await FirebaseFirestore.instance
            .collection('users')
            .where('phone', isEqualTo: normalized)
            .limit(1)
            .get();
      }

      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        debugPrint('[AUTH] fetchUserByPhone: user found with UID ${snap.docs.first.id}');
        // Add a masked email for UI display if needed
        if (data['email'] != null) {
          final email = data['email'] as String;
          final parts = email.split('@');
          if (parts.length == 2) {
            final name = parts[0];
            final domain = parts[1];
            data['email_masked'] = "${name[0]}***@$domain";
          }
        }
        return data;
      }
      debugPrint('[AUTH] fetchUserByPhone: no user found for $normalized');
      return null;
    } catch (e) {
      debugPrint('[AUTH] fetchUserByPhone error: $e');
      return null;
    }
  }

  Future<void> _updateDeviceToken(String uid) async {
    try {
      debugPrint('[NOTIF] Getting device token');
      final messaging = FirebaseMessaging.instance;
      
      // Request permissions (especially required for iOS)
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await messaging.getToken();
      if (token != null) {
        // Sync token to backend (using the fixed PUT endpoint)
        await ApiService.updateUserData(uid, {'device_token': token});
        
        // Update local state to reflect the token
        if (_user != null && _user!.uid == uid) {
          _user = _user!.copyWith(deviceToken: token);
          notifyListeners();
        }
        
        debugPrint('[NOTIF] Token saved');
      }
    } catch (e) {
      debugPrint('[NOTIF] Token update failed: $e');
    }
  }

  /// Manually refresh the current user's profile data from the backend.
  /// Typically called after a seller application is submitted or during polling.
  Future<void> refreshUserData() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      debugPrint('[AUTH] Refreshing user data for: ${firebaseUser.uid}');
      try {
        final userData = await ApiService.getUserData(firebaseUser.uid);
        _user = AppUser.fromFirebaseUser(firebaseUser, extraData: userData);
        notifyListeners();
        debugPrint('[USER] Refresh complete: sellerStatus=${_user!.sellerStatus}');
      } catch (e) {
        debugPrint('[USER] Refresh failed: $e');
      }
    }
  }

  /// Get the current authenticated user from Firebase Auth, ensuring local state is synced.
  /// FALLBACK: If local _user is null, it tries to recover from FirebaseAuth.instance.currentUser.
  Future<AppUser?> getCurrentUser() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null && _user == null) {
      debugPrint('[AUTH] Recovery: Found Firebase session but _user was null — syncing...');
      await _onAuthStateChanged(firebaseUser);
    }
    return _user;
  }

  /// Wait until the user profile (with extraData like role) is loaded from Firestore.
  /// Useful for splash screens or deep links that require role-based routing.
  Future<AppUser?> waitForProfile({Duration timeout = const Duration(seconds: 5)}) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return null;

    // If we already have the role (i.e. not the default 'user' or we have extra data), return it.
    // However, since AppUser.fromFirebaseUser defaults role to 'user', 
    // we should ideally check if the Firestore document was fetched.
    // Let's check if the user was initialized with extraData by checking if we have any extra fields.
    // A better way is to wait for the first non-null snapshot if we know it's coming.
    
    if (_user != null && _user!.role != 'user') return _user;

    // If still 'user' (default), we might be waiting for the stream.
    // Let's fetch it manually once to be sure.
    try {
      final userData = await ApiService.getUserData(firebaseUser.uid);
      _user = AppUser.fromFirebaseUser(firebaseUser, extraData: userData);
      notifyListeners();
      return _user;
    } catch (e) {
      debugPrint('[AUTH] waitForProfile manual fetch failed: $e');
      return _user; // Return whatever we have
    }
  }

  Future<AppUser?> loginWithFacebook() async {
    _setLoading(true);
    _clearError();

    debugPrint('[AUTH] Opening Facebook popup...');

    try {
      if (kIsWeb) {
        final provider = FacebookAuthProvider()
          ..addScope('email')
          ..addScope('public_profile');

        debugPrint('[AUTH] Waiting for user action...');
        
        final userCred = await FirebaseAuth.instance.signInWithPopup(provider);
        final firebaseUser = userCred.user;

        if (firebaseUser != null) {
          debugPrint('[AUTH] Login success: ${firebaseUser.uid}');
          // Navigation happens in UI, but we signal ready by setting state
          await _onAuthStateChanged(firebaseUser);
          return _user;
        } else {
          return null;
        }
      } else {
        // Native SDK result handling...
        final facebookAuth = _getFacebookAuthInstance();
        if (facebookAuth == null) throw Exception('Facebook Auth SDK missing');

        final result = await facebookAuth.login();
        if (result.status.toString() == 'LoginStatus.success' &&
            result.accessToken != null) {
          final credential = FacebookAuthProvider.credential(
            result.accessToken!.tokenString,
          );
          final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
          await _onAuthStateChanged(userCred.user);
          return _user;
        } else {
          throw Exception('Facebook login failed: ${result.status}');
        }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user') {
        return null;
      }
      debugPrint('[AUTH] Error during login: ${e.code}');
      _error = _mapAuthError(e.code);
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('[AUTH] Error during login: $e');
      _error = 'Facebook login failed.';
      notifyListeners();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Called once on app boot to collect the result of a Facebook redirect.
  /// Must be awaited before the app shows its main content.
  Future<void> handlePendingRedirect() async {
    if (!kIsWeb) return;
    debugPrint('[AUTH] Checking for pending redirect result');
    try {
      final result = await FirebaseAuth.instance.getRedirectResult();
      if (result.user != null) {
        _user = AppUser.fromFirebaseUser(result.user!);
        debugPrint('[AUTH] User received from redirect: ${_user!.uid}');
        debugPrint('[USER] Name updated: ${_user!.displayName}');
        notifyListeners();
      } else {
        debugPrint('[AUTH] No pending redirect result');
      }
    } catch (e) {
      // Non-critical — just log, don't surface to user
      debugPrint('[AUTH] getRedirectResult error (safe to ignore): $e');
    }
  }

  // ── Google Login ────────────────────────────────────────────────────────────

  Future<AppUser?> loginWithGoogle() async {
    debugPrint('[AUTH] Starting Google login');
    _setLoading(true);
    _clearError();

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId:
            '663414398790-aud6n3kviito1nlqenbhhu9b5ufmvn0c.apps.googleusercontent.com',
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);
      debugPrint('[AUTH] Google sign-in success: ${userCred.user?.uid}');
      
      if (userCred.user != null) {
        await _onAuthStateChanged(userCred.user);
        return _user;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AUTH] Google FirebaseAuthException: ${e.code}');
      _error = _mapAuthError(e.code);
      notifyListeners();
      rethrow;
    } catch (e) {
      debugPrint('[AUTH] Google login error: $e');
      _error = 'Google login failed. Please try again.';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ── Phone Authentication ────────────────────────────────────────────────────

  Future<void> loginWithPhone(String phoneNumber, {String? uid}) async {
    // Normalize before any backend interaction
    final normalized = PhoneUtils.normalizePH(phoneNumber);
    if (!PhoneUtils.isValidPH(normalized)) {
      _error = 'Invalid phone number format. Please use 09XXXXXXXXX format.';
      notifyListeners();
      return;
    }
    debugPrint('[AUTH] Starting CUSTOM SMS login for: $normalized (raw: $phoneNumber)');
    _setLoading(true);
    _clearError();

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final effectiveUid = uid ?? currentUser?.uid ?? _user?.uid;
      
      debugPrint('[AUTH] loginWithPhone UID Check: currentUser=${currentUser?.uid}, _user=${_user?.uid}');

      if (effectiveUid == null) {
        _error = "Session missing. Please sign up or log in first.";
        notifyListeners();
        return;
      }
      
      await ApiService.sendSmsOtp(normalized, effectiveUid);
      _pendingPhone = normalized;
      _pendingUid = effectiveUid;
      debugPrint('[AUTH] Custom SMS Code sent via Backend for UID: $_pendingUid');
      notifyListeners();
    } catch (e) {
      debugPrint('[AUTH] Custom Phone login error: $e');
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<AppUser?> verifyOTP(String smsCode, {String? phoneNumber, String? uid}) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final effectiveUid = uid ?? currentUser?.uid ?? _user?.uid ?? _pendingUid;
    final effectivePhone = phoneNumber ?? _pendingPhone;

    debugPrint('[AUTH] verifyOTP called. effectiveUid=$effectiveUid, effectivePhone=$effectivePhone');

    if (effectiveUid == null || effectivePhone == null) {
      _error = 'Session missing or phone number unknown. Please try again.';
      notifyListeners();
      return null;
    }

    _setLoading(true);
    _clearError();

    try {
      // Step 1: Call backend to verify OTP
      debugPrint('[AUTH] Step 1: Calling backend verifySmsOtp...');
      final response = await ApiService.verifySmsOtp(effectivePhone, smsCode.trim(), effectiveUid);
      debugPrint('[AUTH] Step 1 complete. Response keys: ${response.keys.toList()}');

      // Step 2: Extract custom token
      final customToken = response['custom_token'];
      debugPrint('[AUTH] Step 2: customToken is ${customToken != null ? "PRESENT" : "NULL"}');

      if (customToken == null) {
        _error = 'Server verified OTP but did not return a session token. Please try again.';
        notifyListeners();
        return null;
      }

      // Step 3: Sign in with the custom token
      debugPrint('[AUTH] Step 3: Signing in with custom token...');
      final userCred = await FirebaseAuth.instance.signInWithCustomToken(customToken);
      final fbUser = userCred.user;
      debugPrint('[AUTH] Step 3 complete. Firebase user: ${fbUser?.uid}');

      if (fbUser == null) {
        _error = 'Sign-in succeeded but no user session was created.';
        notifyListeners();
        return null;
      }

      // Step 4: Build AppUser and update internal state
      debugPrint('[AUTH] Step 4: Building AppUser and syncing state...');
      _user = AppUser.fromFirebaseUser(fbUser);
      notifyListeners();

      // Also kick off background Firestore sync (non-blocking)
      _onAuthStateChanged(fbUser);

      // Step 5: Cleanup
      _pendingPhone = null;
      _pendingUid = null;

      debugPrint('[AUTH] Step 5: SUCCESS. Returning user ${_user?.uid}');
      return _user;
    } catch (e) {
      debugPrint('[AUTH] verifyOTP EXCEPTION: $e');
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ── Email / Password Login ──────────────────────────────────────────────────

  Future<AppUser?> loginWithEmail(String email, String password) async {
    debugPrint('[AUTH] Starting email login for: $email');
    _setLoading(true);
    _clearError();

    try {
      final userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      debugPrint('[AUTH] Email login success: ${userCred.user?.uid}');
      
      if (userCred.user != null) {
        // Fetch full profile (including roles) immediately
        final userData = await ApiService.getUserData(userCred.user!.uid);
        _user = AppUser.fromFirebaseUser(userCred.user!, extraData: userData);
        notifyListeners();
        return _user;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AUTH] Email login error: ${e.code}');
      _error = _mapAuthError(e.code);
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ── Email / Password Signup ─────────────────────────────────────────────────

  Future<AppUser?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    required Map<String, String> address,
  }) async {
    // Normalize phone before signup
    final normalizedPhone = PhoneUtils.normalizePH(phone);
    if (!PhoneUtils.isValidPH(normalizedPhone)) {
      _error = 'Invalid phone number. Use 09XXXXXXXXX format.';
      notifyListeners();
      return null;
    }
    debugPrint('[AUTH] Starting unified signup for: $email (phone: $normalizedPhone)');
    _setLoading(true);
    _clearError();

    try {
      // 1. Call backend to create user & address
      // The backend handles: Firebase Auth User creation, Firestore User doc, and Firestore Address doc.
      final response = await ApiService.signup({
        'name': name.trim(),
        'email': email.trim(),
        'password': password.trim(),
        'phone': normalizedPhone,
        'address': address,
      });

      debugPrint('[AUTH] Backend signup success for UID: ${response['uid'] ?? response['user_id']}');

      // 2. Sign in locally to establish Firebase session
      // Since the backend already created the user, we just need to sign in.
      final userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      if (userCred.user != null) {
        // Fetch full profile (including roles and newly created address) immediately
        final userData = await ApiService.getUserData(userCred.user!.uid);
        _user = AppUser.fromFirebaseUser(userCred.user!, extraData: userData);
        notifyListeners();
        return _user;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AUTH] Firebase Auth error during signup sign-in: ${e.code}');
      _error = _mapAuthError(e.code);
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ── Engagement ──────────────────────────────────────────────────────────────

  Future<void> toggleFollowSeller(String sellerId) async {
    if (_user == null) return;
    
    final bool isFollowing = _user!.followedSellers.contains(sellerId);
    
    try {
      if (isFollowing) {
        debugPrint('[AUTH] Unfollowing seller: $sellerId');
        await ApiService.unfollowSeller(_user!.uid, sellerId);
      } else {
        debugPrint('[AUTH] Following seller: $sellerId');
        await ApiService.followSeller(_user!.uid, sellerId);
      }
    } catch (e) {
      debugPrint('[AUTH] Toggle follow failed: $e');
      _error = 'Failed to update follow status.';
      notifyListeners();
    }
  }


  // ── Logout ──────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    debugPrint('[AUTH] Logging out user: ${_user?.uid}');
    try {
      _userStreamSubscription?.cancel();
      _userStreamSubscription = null;
      await FirebaseAuth.instance.signOut();
      debugPrint('[AUTH] Sign out successful');
    } catch (e) {
      debugPrint('[AUTH] Sign out error: $e');
    }
  }

  /// Alias for logout to match Firebase terminology and UI calls.
  Future<void> signOut() => logout();

  // ── Password Reset ─────────────────────────────────────────────────────────

  Future<void> sendPasswordResetEmail(String email) async {
    debugPrint('[AUTH] Sending password reset email to: $email');
    _setLoading(true);
    _clearError();

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email.trim(),
      );
      debugPrint('[AUTH] Password reset email sent');
    } on FirebaseAuthException catch (e) {
      debugPrint('[AUTH] Password reset error: ${e.code}');
      _error = _mapAuthError(e.code);
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ── Account Management ──────────────────────────────────────────────────────
  
  Future<void> deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _error = "No active session.";
      notifyListeners();
      throw Exception(_error);
    }

    _setLoading(true);
    _clearError();

    try {
      final uid = user.uid;
      
      // 1. (Optional) Mark user document as deleted or remove it
      // This helps clean up the database. Security rules must allow the user to delete their own doc.
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      } catch (e) {
        debugPrint('[AUTH] Failed to delete Firestore user doc: $e');
        // Continue with account deletion even if Firestore deletion fails
      }

      // 2. Delete the Firebase Auth user
      await user.delete();
      
      // 3. Clear local state
      _user = null;
      notifyListeners();
      debugPrint('[AUTH] Account successfully deleted.');

    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _error = "For security reasons, you must log out and log back in before deleting your account.";
      } else {
        _error = _mapAuthError(e.code);
      }
      debugPrint('[AUTH] Delete account failed: ${e.code}');
      notifyListeners();
      throw Exception(_error);
    } catch (e) {
      _error = 'Failed to delete account. Please try again.';
      debugPrint('[AUTH] Delete account error: $e');
      notifyListeners();
      throw Exception(_error);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateEmail(String newEmail) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No active session.');
    }

    // Check if user is a social user (Google/Facebook)
    final isSocialUser = user.providerData.any((p) => p.providerId != 'password' && p.providerId != 'phone');
    if (isSocialUser) {
      throw Exception('Your email is managed by your login provider (Google/Facebook) and cannot be changed here.');
    }

    _setLoading(true);
    _clearError();

    try {
      // 1. Duplication check in Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: newEmail)
          .get();

      if (snapshot.docs.isNotEmpty) {
        throw Exception('Email is already in use by another account.');
      }

      // 2. Update Firebase Auth using the modern verification flow
      // This sends a verification email to the NEW email address.
      // Once verified, the user's email will be updated in Firebase Auth.
      await user.verifyBeforeUpdateEmail(newEmail);

      // 3. Update Firestore Document (We update it now so UI reflects the pending change, or at least record intent)
      // Note: In production, you might wait for a webhook or use a cloud function to sync after verification.
      // For now, we update it immediately to match the user's desired state.
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'email': newEmail,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // 4. Update local state
      _user = _user?.copyWith(email: newEmail);
      notifyListeners();
      
      debugPrint('[AUTH] Verification email sent to $newEmail. Email will update once verified.');
    } on FirebaseAuthException catch (e) {
      debugPrint('[AUTH] Update email Firebase error: ${e.code}');
      if (e.code == 'requires-recent-login') {
        throw Exception("For security reasons, you must log out and log back in before changing your email.");
      } else if (e.code == 'email-already-in-use') {
        throw Exception('Email is already in use by another account.');
      } else if (e.code == 'operation-not-allowed') {
        throw Exception('Email updates are currently disabled. Please contact support.');
      } else {
        throw Exception(_mapAuthError(e.code));
      }
    } catch (e) {
      debugPrint('[AUTH] Update email error: $e');
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    } finally {
      _setLoading(false);
    }
  }

  void updatePhoneNumberLocally(String newPhone) {
    if (_user != null) {
      _user = _user!.copyWith(phoneNumber: newPhone);
      notifyListeners();
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  /// Returns null on web (flutter_facebook_auth SDK not used on web)
  dynamic _getFacebookAuthInstance() {
    try {
      // flutter_facebook_auth is only used on native
      // import is done at runtime to avoid web build issues
      return null; // Override at native layer
    } catch (_) {
      return null;
    }
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Invalid email format.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'account-exists-with-different-credential':
        return 'An account exists with a different login method.';
      case 'popup-closed-by-user':
        return 'Login cancelled.';
      case 'invalid-phone-number':
        return 'Invalid phone number format. Please use +[country code][number].';
      case 'invalid-verification-code':
        return 'The verification code is invalid.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      case 'billing-not-enabled':
        return 'SMS is disabled on this project. Please use a Test Phone Number or enable billing in Firebase Console.';
      case 'operation-not-allowed':
        return 'This operation is not allowed. If you are updating your email, please ensure "Email address change" is enabled in the Firebase Console (Authentication > Settings > User Actions).';
      default:
        return 'Authentication failed. Please try again. ($code)';
    }
  }
}
