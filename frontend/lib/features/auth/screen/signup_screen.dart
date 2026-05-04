// lib/features/auth/screen/signup_screen.dart
// Shopee-style multi-step signup: Phone + Email required, then password, then profile.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter/gestures.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/features/auth/screen/phone_login_screen.dart';
import 'package:swipify/features/auth/screen/otp_verification_screen.dart';
import 'package:swipify/features/navigation/main_nav_screen.dart';
import 'package:swipify/core/theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _pageController = PageController();
  int _currentStep = 0;

  // Step 1: Contact
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  // Step 2: Security
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Step 3: Profile
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  String? _selectedGender;
  DateTime? _selectedDOB;

  @override
  void dispose() {
    _pageController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
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

  bool _isCheckingPhone = false;

  Future<void> _nextStep() async {
    if (_currentStep == 0) {
      if (await _validateStep1()) {
        setState(() => _currentStep++);
        _pageController.animateToPage(_currentStep,
            duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
      }
      return;
    }
    
    if (_currentStep == 1 && !_validateStep2()) return;

    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.animateToPage(_currentStep,
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(_currentStep,
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    }
  }

  Future<bool> _validateStep1() async {
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    if (phone.isEmpty) { _showError("Phone number is required"); return false; }
    if (!phone.startsWith('+')) { _showError("Include country code (e.g. +63)"); return false; }
    if (phone.length < 10) { _showError("Phone number is too short"); return false; }
    if (email.isEmpty) { _showError("Email address is required"); return false; }
    if (!email.contains('@') || !email.contains('.')) { _showError("Enter a valid email"); return false; }

    setState(() => _isCheckingPhone = true);
    try {
      final auth = context.read<AuthProvider>();
      final existingUser = await auth.fetchUserByPhone(phone);
      if (existingUser != null) {
        _showError("This phone number is already linked to another account (${existingUser['email_masked']}).");
        return false;
      }
    } finally {
      if (mounted) setState(() => _isCheckingPhone = false);
    }

    return true;
  }

  bool _validateStep2() {
    final auth = context.read<AuthProvider>();
    final config = auth.signupConfig;
    final minLen = (config?['password_min_length'] as num?)?.toInt() ?? 8;
    final maxLen = (config?['password_max_length'] as num?)?.toInt() ?? 16;
    
    final pw = _passwordController.text;
    final confirm = _confirmController.text;
    if (pw.isEmpty) { _showError("Password is required"); return false; }
    if (pw.length < minLen) { _showError("Password must be at least $minLen characters"); return false; }
    if (pw.length > maxLen) { _showError("Password must be at most $maxLen characters"); return false; }
    if (!RegExp(r'[A-Z]').hasMatch(pw)) { _showError("Include at least 1 uppercase letter"); return false; }
    if (!RegExp(r'[a-z]').hasMatch(pw)) { _showError("Include at least 1 lowercase letter"); return false; }
    if (!RegExp(r'[0-9]').hasMatch(pw)) { _showError("Include at least 1 number"); return false; }
    if (pw != confirm) { _showError("Passwords do not match"); return false; }
    return true;
  }

  int _passwordStrength(String pw) {
    int score = 0;
    if (pw.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(pw)) score++;
    if (RegExp(r'[a-z]').hasMatch(pw)) score++;
    if (RegExp(r'[0-9]').hasMatch(pw)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(pw)) score++;
    return score;
  }

  Future<void> _handleSignup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) { _showError("Full name is required"); return; }

    final auth = context.read<AuthProvider>();
    try {
      await auth.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        name,
        username: _usernameController.text.trim().isNotEmpty ? _usernameController.text.trim() : null,
        phoneNumber: _phoneController.text.trim(),
        gender: _selectedGender,
        dateOfBirth: _selectedDOB != null ? DateFormat('yyyy-MM-dd').format(_selectedDOB!) : null,
        signOutAfter: false, // Don't sign out so we can link phone!
      );

      if (!mounted) return;

      // Start OTP verification flow
      // Sanitize: Firebase E.164 needs +[country][number] without spaces
      final phone = _phoneController.text.trim().replaceAll(' ', '');
      await auth.loginWithPhone(phone);

      if (mounted && auth.error == null) {
         Navigator.pushReplacement(
           context,
           MaterialPageRoute(builder: (_) => const OTPVerificationScreen()),
         );
      } else if (mounted && auth.error != null) {
         _showError(auth.error!);
         // Fallback just in case OTP fails, we can just log out or go to login
      }

    } catch (e) {
      if (mounted) _showError(auth.error ?? "Signup failed");
    }
  }

  void _showPolicyDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Text(content, style: GoogleFonts.inter(height: 1.6, fontSize: 14)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CLOSE", style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: SwipifyTheme.primaryColor)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _pickDOB() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDOB ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1920),
      lastDate: now,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: SwipifyTheme.primaryColor),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDOB = picked);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        leading: _currentStep > 0
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _prevStep)
            : IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        title: Text("Sign Up", style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.black87)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // STEP INDICATOR
          _buildStepIndicator(auth),
          // PAGES
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1Contact(),
                _buildStep2Security(auth),
                _buildStep3Profile(auth),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── STEP INDICATOR ──────────────────────────────────────────────────────────
  Widget _buildStepIndicator(AuthProvider auth) {
    final labels = List<String>.from(auth.signupConfig?['step_labels'] ?? ["Contact", "Security", "Profile"]);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
      child: Row(
        children: List.generate(labels.length, (i) {
          final isActive = i <= _currentStep;
          final isComplete = i < _currentStep;
          
          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    // Left Line
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i == 0 
                          ? Colors.transparent 
                          : (i <= _currentStep ? SwipifyTheme.primaryColor : Colors.grey.shade200),
                      ),
                    ),
                    // Circle
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isComplete || isActive ? SwipifyTheme.primaryColor : Colors.grey.shade200,
                        border: isActive && !isComplete 
                          ? Border.all(color: SwipifyTheme.primaryColor.withValues(alpha: 0.2), width: 4) 
                          : null,
                      ),
                      child: Center(
                        child: isComplete
                            ? const Icon(Icons.check, color: Colors.white, size: 16)
                            : Text("${i + 1}", style: GoogleFonts.inter(
                                color: isActive ? Colors.white : Colors.grey,
                                fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ),
                    // Right Line
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i == labels.length - 1 
                          ? Colors.transparent 
                          : (i < _currentStep ? SwipifyTheme.primaryColor : Colors.grey.shade200),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  labels[i], 
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? SwipifyTheme.primaryColor : SwipifyTheme.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── STEP 1: CONTACT ─────────────────────────────────────────────────────────
  Widget _buildStep1Contact() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Your Contact Info", style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Text("Every account must be linked to a phone number and email for security & OTP verification.",
              style: GoogleFonts.inter(fontSize: 13, color: SwipifyTheme.textSecondary, fontWeight: FontWeight.w500, height: 1.5)),
          const SizedBox(height: 32),

          _buildLabel("Phone Number"),
          const SizedBox(height: 8),
          _buildField(_phoneController, "+63 912 345 6789", Icons.phone_android_outlined, keyboardType: TextInputType.phone),
          const SizedBox(height: 6),
          Text("Include country code. Used for OTP login.", style: GoogleFonts.inter(fontSize: 11, color: SwipifyTheme.textMuted)),

          const SizedBox(height: 24),
          _buildLabel("Email Address"),
          const SizedBox(height: 8),
          _buildField(_emailController, "you@example.com", Icons.email_outlined, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 6),
          Text("Used for account recovery and notifications.", style: GoogleFonts.inter(fontSize: 11, color: SwipifyTheme.textMuted)),

          const SizedBox(height: 40),
          _buildPrimaryButton("CONTINUE", _nextStep, loading: _isCheckingPhone),

          const SizedBox(height: 24),
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
          const SizedBox(height: 24),
          _buildSocialButton("Continue with Google", Icons.g_mobiledata, const Color(0xFFDB4437),
              () => context.read<AuthProvider>().loginWithGoogle()),
          const SizedBox(height: 12),
          _buildSocialButton("Continue with Facebook", Icons.facebook, const Color(0xFF4267B2),
              () => context.read<AuthProvider>().loginWithFacebook()),
        ],
      ),
    );
  }

  // ── STEP 2: SECURITY ────────────────────────────────────────────────────────
  Widget _buildStep2Security(AuthProvider auth) {
    final pw = _passwordController.text;
    final strength = _passwordStrength(pw);
    const strengthLabels = ["", "Weak", "Fair", "Good", "Strong", "Excellent"];
    const strengthColors = [Colors.grey, Colors.red, Colors.orange, Colors.amber, Colors.lightGreen, Colors.green];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Set Your Password", style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Text("${auth.signupConfig?['password_min_length'] ?? 8}–${auth.signupConfig?['password_max_length'] ?? 16} characters with uppercase, lowercase, and numbers.",
              style: GoogleFonts.inter(fontSize: 13, color: SwipifyTheme.textSecondary, fontWeight: FontWeight.w500, height: 1.5)),
          const SizedBox(height: 32),

          _buildLabel("Password"),
          const SizedBox(height: 8),
          _buildField(_passwordController, "Create password", Icons.lock_outline,
              obscure: _obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: Colors.grey),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              onChanged: (_) => setState(() {})),

          if (pw.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: List.generate(5, (i) => Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: i < strength ? strengthColors[strength] : Colors.grey.shade200,
                  ),
                ),
              )),
            ),
            const SizedBox(height: 6),
            Text(strengthLabels[strength], style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: strengthColors[strength])),
          ],

          const SizedBox(height: 24),
          _buildLabel("Confirm Password"),
          const SizedBox(height: 8),
          _buildField(_confirmController, "Re-enter password", Icons.lock_outline,
              obscure: _obscureConfirm,
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: Colors.grey),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              )),

          const SizedBox(height: 16),
          // Requirements checklist
          _buildCheck("${auth.signupConfig?['password_min_length'] ?? 8}–${auth.signupConfig?['password_max_length'] ?? 16} characters", pw.length >= ((auth.signupConfig?['password_min_length'] as num?)?.toInt() ?? 8) && pw.length <= ((auth.signupConfig?['password_max_length'] as num?)?.toInt() ?? 16)),
          _buildCheck("Uppercase letter (A-Z)", RegExp(r'[A-Z]').hasMatch(pw)),
          _buildCheck("Lowercase letter (a-z)", RegExp(r'[a-z]').hasMatch(pw)),
          _buildCheck("Number (0-9)", RegExp(r'[0-9]').hasMatch(pw)),

          const SizedBox(height: 32),
          _buildPrimaryButton("CONTINUE", _nextStep),
        ],
      ),
    );
  }

  // ── STEP 3: PROFILE ─────────────────────────────────────────────────────────
  Widget _buildStep3Profile(AuthProvider auth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Complete Your Profile", style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Text("Tell us a bit about yourself.", style: GoogleFonts.inter(fontSize: 13, color: SwipifyTheme.textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 32),

          _buildLabel("Full Name *"),
          const SizedBox(height: 8),
          _buildField(_nameController, "Juan Dela Cruz", Icons.person_outline),

          const SizedBox(height: 20),
          _buildLabel("Username (optional)"),
          const SizedBox(height: 8),
          _buildField(_usernameController, "juandc_shop", Icons.alternate_email),

          const SizedBox(height: 20),
          _buildLabel("Gender (optional)"),
          const SizedBox(height: 8),
          Row(
            children: (List<String>.from(auth.signupConfig?['gender_options'] ?? ["male", "female", "other"])).map((g) {
              final label = g[0].toUpperCase() + g.substring(1);
              final selected = _selectedGender == g.toLowerCase();
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedGender = g.toLowerCase()),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8), // simplified spacing
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: selected ? SwipifyTheme.primaryColor : SwipifyTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? SwipifyTheme.primaryColor : Colors.transparent, width: 1.5),
                    ),
                    child: Center(
                      child: Text(label, style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700, fontSize: 13,
                          color: selected ? Colors.white : SwipifyTheme.textSecondary)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),
          _buildLabel("Date of Birth (optional)"),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickDOB,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: SwipifyTheme.backgroundColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cake_outlined, size: 20, color: SwipifyTheme.primaryColor),
                  const SizedBox(width: 12),
                  Text(
                    _selectedDOB != null ? DateFormat('MMMM d, yyyy').format(_selectedDOB!) : "Select your birthday",
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, fontSize: 14,
                        color: _selectedDOB != null ? SwipifyTheme.textPrimary : Colors.grey.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),
          _buildPrimaryButton(auth.isLoading ? null : "CREATE ACCOUNT", auth.isLoading ? null : _handleSignup, loading: auth.isLoading),

          const SizedBox(height: 20),
          Center(
            child: Text.rich(
              TextSpan(
                text: "By signing up, you agree to our ",
                style: GoogleFonts.inter(fontSize: 11, color: SwipifyTheme.textMuted),
                children: [
                  TextSpan(
                    text: "Terms of Service",
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: SwipifyTheme.primaryColor),
                    recognizer: TapGestureRecognizer()..onTap = () => _showPolicyDialog("Terms of Service", auth.signupConfig?['terms_of_service'] ?? "Default terms..."),
                  ),
                  const TextSpan(text: " and "),
                  TextSpan(
                    text: "Privacy Policy",
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: SwipifyTheme.primaryColor),
                    recognizer: TapGestureRecognizer()..onTap = () => _showPolicyDialog("Privacy Policy", auth.signupConfig?['privacy_policy'] ?? "Default privacy policy..."),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Already have an account? ", style: GoogleFonts.inter(color: SwipifyTheme.textSecondary, fontSize: 14)),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                child: Text("Log In", style: GoogleFonts.inter(color: SwipifyTheme.primaryColor, fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── SHARED WIDGETS ──────────────────────────────────────────────────────────
  Widget _buildLabel(String text) {
    return Text(text, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: SwipifyTheme.textPrimary));
  }

  Widget _buildField(TextEditingController c, String hint, IconData icon, {
    bool obscure = false, TextInputType? keyboardType, Widget? suffixIcon, Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: c, obscureText: obscure, keyboardType: keyboardType, onChanged: onChanged,
      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 20, color: SwipifyTheme.primaryColor),
        suffixIcon: suffixIcon,
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.grey.withValues(alpha: 0.5), fontWeight: FontWeight.w500),
        filled: true,
        fillColor: SwipifyTheme.backgroundColor.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: SwipifyTheme.primaryColor, width: 1.5)),
      ),
    );
  }

  Widget _buildPrimaryButton(String? label, VoidCallback? onTap, {bool loading = false}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: SwipifyTheme.primaryColor, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0,
        ),
        child: loading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label ?? "", style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1)),
      ),
    );
  }

  Widget _buildCheck(String label, bool pass) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(pass ? Icons.check_circle : Icons.circle_outlined, size: 16, color: pass ? Colors.green : Colors.grey.shade400),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: pass ? Colors.green : SwipifyTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildSocialButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: color, size: 24),
        label: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: SwipifyTheme.textPrimary, fontSize: 14)),
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
