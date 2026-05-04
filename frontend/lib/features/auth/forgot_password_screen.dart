import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/core/theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showError("Please enter your email.");
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      _showError("Please enter a valid email address.");
      return;
    }

    debugPrint('[AUTH] UI: Password reset initiated for $email');
    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.sendPasswordResetEmail(email);

      debugPrint('[AUTH] UI: Reset email sent — popping screen');
      if (mounted) {
        _showSuccess("Reset email sent! Check your inbox.");
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        final err = context.read<AuthProvider>().error;
        _showError(err ?? "Reset failed. Please verify your email.");
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final isLoading = authProvider.isLoading;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.black87),
            title: Text("Reset Password", style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.black87)),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Forgot Password?",
                  style: GoogleFonts.inter(
                    fontSize: 28, 
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Don't worry! Enter your email address below and we'll send you a link to reset your password.",
                  style: GoogleFonts.inter(
                    fontSize: 14, 
                    color: SwipifyTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 48),

                Text(
                  "Email Address",
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: SwipifyTheme.textPrimary),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.email_outlined, size: 20, color: SwipifyTheme.primaryColor),
                    hintText: "you@example.com",
                    hintStyle: GoogleFonts.inter(color: Colors.grey.withValues(alpha: 0.5), fontWeight: FontWeight.w500),
                    filled: true,
                    fillColor: SwipifyTheme.backgroundColor.withValues(alpha: 0.5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: SwipifyTheme.primaryColor, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _sendResetEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SwipifyTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            "SEND RESET LINK", 
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
