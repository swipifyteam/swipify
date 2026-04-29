import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/features/auth/screen/otp_verification_screen.dart';
import 'package:swipify/core/theme.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
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

  Future<void> _handleSendOTP() async {
    final auth = context.read<AuthProvider>();
    final phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      _showError("Please enter your phone number");
      return;
    }

    // Basic format check
    if (!phone.startsWith('+')) {
      _showError("Please include your country code (e.g., +63)");
      return;
    }

    // Check if user exists first
    auth.setLoading(true);
    try {
      final user = await auth.fetchUserByPhone(phone);
      if (user == null) {
        _showError("No account found with this phone number. Please sign up first.");
        auth.setLoading(false);
        return;
      }
    } catch (e) {
      // If check fails, we might still want to try loginWithPhone or show error
      debugPrint('[AUTH] Phone check failed: $e');
    }

    await auth.loginWithPhone(phone);
    
    if (mounted && auth.error == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const OTPVerificationScreen()),
      );
    } else if (mounted && auth.error != null) {
      _showError(auth.error!);
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
                "Continue with Phone",
                style: GoogleFonts.inter(
                  fontSize: 28, 
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "We'll send you a 6-digit code to verify your account.",
                style: GoogleFonts.inter(
                  fontSize: 14, 
                  color: SwipifyTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),

              // PHONE FIELD
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18, letterSpacing: 1),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.phone_android_outlined, size: 24, color: SwipifyTheme.primaryColor),
                  hintText: "+63 912 345 6789",
                  hintStyle: GoogleFonts.inter(color: Colors.grey.withValues(alpha: 0.5), fontWeight: FontWeight.w500),
                  filled: true,
                  fillColor: SwipifyTheme.backgroundColor.withValues(alpha: 0.5),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
                    borderSide: const BorderSide(color: SwipifyTheme.primaryColor, width: 1.5),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),

              // SEND CODE BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: auth.isLoading ? null : _handleSendOTP,
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
                        "SEND CODE", 
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
