import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:swipify/core/models/app_user.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/features/navigation/main_nav_screen.dart';
import 'package:swipify/core/theme.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String? phoneNumber;
  final String? uid;

  const OTPVerificationScreen({
    super.key,
    this.phoneNumber,
    this.uid,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _handleVerify() async {
    final auth = context.read<AuthProvider>();
    final code = _otpController.text.trim();

    if (code.isEmpty || code.length < 6) {
      _showError("Please enter the 6-digit code");
      return;
    }

    try {
      debugPrint('[OTP] Calling verifyOTP...');
      final user = await auth.verifyOTP(
        code, 
        phoneNumber: widget.phoneNumber, 
        uid: widget.uid,
      );
      
      debugPrint('[OTP] verifyOTP returned. user=$user, error=${auth.error}');

      if (!mounted) return;

      if (user != null) {
        _navigateHome(user);
        return;
      }

      // FALLBACK: If verifyOTP returned null but Firebase Auth has a user,
      // it means sign-in worked but there was a state sync issue.
      final fbUser = FirebaseAuth.instance.currentUser;
      debugPrint('[OTP] Fallback check: FirebaseAuth.currentUser=${fbUser?.uid}');
      
      if (fbUser != null) {
        debugPrint('[OTP] Fallback: Firebase session exists! Navigating to home...');
        final fallbackUser = AppUser.fromFirebaseUser(fbUser);
        _navigateHome(fallbackUser);
        return;
      }

      // If we truly have no user and no error, show a message
      if (auth.error != null) {
        _showError(auth.error!);
      } else {
        _showError("Verification failed. Please request a new code and try again.");
      }
    } catch (e) {
      debugPrint('[OTP] _handleVerify exception: $e');
      if (mounted) {
        _showError(auth.error ?? "Verification failed: $e");
      }
    }
  }

  void _navigateHome(AppUser user) {
    debugPrint('[OTP] Navigating home for user: ${user.uid} (isAdmin: ${user.isAdmin})');
    if (user.isAdmin) {
      Navigator.pushNamedAndRemoveUntil(context, '/admin', (route) => false);
    } else {
      Navigator.pushAndRemoveUntil(
        context, 
        MaterialPageRoute(builder: (_) => const MainNavScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Enter Verification Code",
                style: GoogleFonts.inter(
                  fontSize: 28, 
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "We've sent a 6-digit code to your phone number.",
                style: GoogleFonts.inter(
                  fontSize: 14, 
                  color: SwipifyTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),

              // OTP FIELD
              TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 32, letterSpacing: 8),
                decoration: InputDecoration(
                  counterText: "",
                  hintText: "000000",
                  hintStyle: GoogleFonts.inter(color: Colors.grey.withValues(alpha: 0.3), fontWeight: FontWeight.w500, letterSpacing: 8),
                  filled: true,
                  fillColor: SwipifyTheme.backgroundColor.withValues(alpha: 0.5),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16), 
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16), 
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16), 
                    borderSide: const BorderSide(color: SwipifyTheme.primaryColor, width: 2),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),

              // VERIFY BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: auth.isLoading ? null : _handleVerify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SwipifyTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: auth.isLoading 
                    ? const SizedBox(
                        height: 20, 
                        width: 20, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      ) 
                    : Text(
                        "VERIFY", 
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1)
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
