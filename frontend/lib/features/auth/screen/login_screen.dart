// lib/features/auth/screen/login_screen.dart
// Premium Login Screen for Swipify.
// Part of the feature-based reconstruction.
// Handles multiple auth provider flows with rich aesthetics.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/features/auth/screen/phone_login_screen.dart';
import 'package:swipify/features/auth/forgot_password_screen.dart';
import 'package:swipify/features/navigation/main_nav_screen.dart';
import 'package:swipify/core/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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

  Future<void> _handleLogin() async {
    final auth = context.read<AuthProvider>();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError("Please enter email and password");
      return;
    }

    try {
      final user = await auth.loginWithEmail(email, password);
      if (mounted) {
        if (user != null && user.isAdmin) {
          Navigator.pushReplacementNamed(context, '/admin');
        } else {
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (_) => const MainNavScreen())
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showError(auth.error ?? "Login failed");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // BRAND LOGO
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: SwipifyTheme.primaryColor.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shopping_bag_rounded, size: 64, color: SwipifyTheme.primaryColor),
              ),
              const SizedBox(height: 16),
              Text(
                "Swipify",
                style: GoogleFonts.inter(
                  fontSize: 28, 
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Welcome back! Log in to continue",
                style: GoogleFonts.inter(
                  fontSize: 14, 
                  color: SwipifyTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 40),

              // LOGIN FIELDS
              _buildTextFormField(_emailController, "Email Address", Icons.email_outlined, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              _buildTextFormField(_passwordController, "Password", Icons.lock_outline, obscure: true),
              
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                    );
                  },
                  child: Text(
                    "Forgot Password?",
                    style: GoogleFonts.inter(
                      color: SwipifyTheme.primaryColor, 
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),

              // LOG IN BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: auth.isLoading ? null : _handleLogin,
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
                        "LOG IN", 
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1)
                      ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text("OR", style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 12)),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              
              const SizedBox(height: 32),

              // SOCIAL BUTTONS
              _buildSocialButton(
                "Continue with Phone", 
                Icons.phone_android_rounded, 
                SwipifyTheme.primaryColor, 
                () => Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => const PhoneLoginScreen())
                )
              ),
              const SizedBox(height: 16),
              _buildSocialButton(
                "Continue with Google", 
                Icons.g_mobiledata, 
                const Color(0xFFDB4437), 
                () => auth.loginWithGoogle()
              ),
              const SizedBox(height: 16),
              _buildSocialButton(
                "Continue with Facebook", 
                Icons.facebook, 
                const Color(0xFF4267B2), 
                () => auth.loginWithFacebook()
              ),
              
              const SizedBox(height: 32),
              
              // NAVIGATION LINK
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: GoogleFonts.inter(color: SwipifyTheme.textSecondary, fontSize: 14),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/signup'),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                    child: Text(
                      "Sign Up",
                      style: GoogleFonts.inter(
                        color: SwipifyTheme.primaryColor, 
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField(
    TextEditingController controller, 
    String label, 
    IconData icon, 
    {bool obscure = false, TextInputType? keyboardType}
  ) {
     return TextFormField(
       controller: controller,
       obscureText: obscure,
       keyboardType: keyboardType,
       style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
       decoration: InputDecoration(
         prefixIcon: Icon(icon, size: 20, color: SwipifyTheme.primaryColor),
         labelText: label,
         labelStyle: GoogleFonts.inter(color: SwipifyTheme.textSecondary, fontWeight: FontWeight.w500),
         filled: true,
         fillColor: SwipifyTheme.backgroundColor.withValues(alpha: 0.5),
         contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
     );
  }

  Widget _buildSocialButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: color, size: 24),
        label: Text(
          label,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: SwipifyTheme.textPrimary, fontSize: 14),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
          backgroundColor: Colors.white,
        ),
      ),
    );
  }
}
