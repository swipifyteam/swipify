import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/features/auth/screen/login_screen.dart';
import 'package:swipify/features/profile/service/user_provider.dart';
import 'package:swipify/features/profile/screens/help_screen.dart';
import 'package:swipify/services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _emailUpdates = false;
  bool _biometrics = true;
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifications = _prefs.getBool('notifications') ?? true;
      _emailUpdates = _prefs.getBool('emailUpdates') ?? false;
      _biometrics = _prefs.getBool('biometrics') ?? true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, UserProvider>(
      builder: (context, authProvider, userProv, _) {
        final profile = userProv.profile;
        final name = profile?.name ?? authProvider.user?.displayName ?? 'User';
        final email = profile?.email ?? authProvider.user?.email ?? 'Not set';
        final phone = profile?.phoneNumber ?? authProvider.user?.phoneNumber ?? '';

        return Scaffold(
          backgroundColor: SwipifyTheme.backgroundColor,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: SwipifyTheme.backgroundColor,
            iconTheme: const IconThemeData(color: SwipifyTheme.textPrimary),
            title: Text(
              'Settings',
              style: SwipifyTheme.heading2.copyWith(fontSize: 18),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            children: [
              // ── Account Section ─────────────────────────────────────────
              _SettingsSection(
                title: 'Account',
                items: [
                  _SettingsTile(
                    icon: Icons.person_outline_rounded,
                    title: 'Personal Info',
                    subtitle: name,
                    onTap: () => _showEditNameDialog(context, name),
                  ),
                  _SettingsTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Password & Security',
                    onTap: authProvider.isSocialUser 
                      ? () => _showSocialInfo(context, "Password") 
                      : () => _showPasswordResetDialog(authProvider, email),
                  ),
                  _SettingsTile(
                    icon: Icons.alternate_email_rounded,
                    title: 'Email',
                    subtitle: email,
                    onTap: authProvider.isSocialUser 
                      ? () => _showSocialInfo(context, "Email") 
                      : () => _showEditEmailDialog(context, email, authProvider, userProv),
                  ),
                  _SettingsTile(
                    icon: Icons.phone_android_rounded,
                    title: 'Phone Number',
                    subtitle: phone.isNotEmpty ? phone : 'Not linked',
                    onTap: () => _showEditPhoneDialog(context, phone, authProvider, userProv),
                  ),
                ],
              ),

              // ── Notifications Section ───────────────────────────────────
              _SettingsSection(
                title: 'Notifications',
                items: [
                  _ToggleTile(
                    title: 'System Notifications',
                    value: _notifications,
                    onChanged: (v) {
                      setState(() => _notifications = v);
                      _prefs.setBool('notifications', v);
                    },
                  ),
                  _ToggleTile(
                    title: 'Marketing Emails',
                    value: _emailUpdates,
                    onChanged: (v) {
                      setState(() => _emailUpdates = v);
                      _prefs.setBool('emailUpdates', v);
                    },
                  ),
                ],
              ),

              // ── Security Section ───────────────────────────────────────
              _SettingsSection(
                title: 'Privacy & Safety',
                items: [
                  _ToggleTile(
                    title: 'Biometric Access',
                    value: _biometrics,
                    onChanged: (v) {
                      setState(() => _biometrics = v);
                      _prefs.setBool('biometrics', v);
                    },
                  ),
                  const _SettingsTile(icon: Icons.shield_moon_outlined, title: 'Two-Factor (2FA)'),
                  _SettingsTile(
                    icon: Icons.visibility_outlined, 
                    title: 'Privacy Center',
                    onTap: () => _showPolicyDialog("Privacy Center", authProvider.signupConfig?['privacy_policy'] ?? "No privacy policy found."),
                  ),
                ],
              ),

              // ── About Section ──────────────────────────────────────────
              _SettingsSection(
                title: 'About Swipify',
                items: [
                  _SettingsTile(
                    icon: Icons.help_center_outlined, 
                    title: 'Get Help',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen())),
                  ),
                  _SettingsTile(
                    icon: Icons.policy_outlined, 
                    title: 'Legal & Policies',
                    onTap: () => _showPolicyDialog("Legal & Policies", authProvider.signupConfig?['terms_of_service'] ?? "No terms of service found."),
                  ),
                  const _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    title: 'App Version',
                    subtitle: 'v2.4.0 (Build 502)',
                  ),
                ],
              ),

              // ── Admin Section (Conditional) ─────────────────────────────
              if (authProvider.user?.isAdmin ?? false)
                _SettingsSection(
                  title: 'Administrative',
                  items: [
                    _SettingsTile(
                      icon: Icons.admin_panel_settings_rounded,
                      title: 'Admin Dashboard',
                      subtitle: 'Manage users, sellers, and platform',
                      onTap: () => Navigator.of(context).pushNamed('/admin'),
                    ),
                  ],
                ),

              const SizedBox(height: 24),
              
              // Logout / Actions
              ElevatedButton(
                onPressed: () async {
                  await authProvider.logout();
                  userProv.clear();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.redAccent,
                  elevation: 0,
                  shadowColor: Colors.black.withValues(alpha: 0.05),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Color(0xFFFEE2E2)),
                  ),
                ),
                child: Text(
                  'SIGN OUT',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1),
                ),
              ),
              
              const SizedBox(height: 12),
              
              TextButton(
                onPressed: () => _showDeleteAccountDialog(authProvider),
                child: Text(
                  'Delete Account Permanently',
                  style: GoogleFonts.inter(color: Colors.redAccent.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  void _showEditNameDialog(BuildContext context, String currentName) {
    final controller = TextEditingController(text: currentName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 32, left: 32, right: 32,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Update Profile Name', style: SwipifyTheme.heading2),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: "Full Name",
                labelStyle: GoogleFonts.inter(color: SwipifyTheme.textSecondary),
                filled: true,
                fillColor: SwipifyTheme.backgroundColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final uid = context.read<AuthProvider>().user?.uid;
                  if (uid != null && controller.text.isNotEmpty) {
                    await context.read<UserProvider>().updateName(uid, controller.text);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: SwipifyTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('SAVE CHANGES', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  void _showEditEmailDialog(BuildContext context, String currentEmail, AuthProvider auth, UserProvider uProv) {
    final controller = TextEditingController(text: currentEmail);
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 32, left: 32, right: 32,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Update Email Address', style: SwipifyTheme.heading2),
              const SizedBox(height: 8),
              Text('A verification link will be sent to your new email.', style: GoogleFonts.inter(color: SwipifyTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: "New Email",
                  labelStyle: GoogleFonts.inter(color: SwipifyTheme.textSecondary),
                  filled: true,
                  fillColor: SwipifyTheme.backgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    if (controller.text.isEmpty || !controller.text.contains('@')) return;
                    
                    setState(() => isLoading = true);
                    try {
                      await auth.updateEmail(controller.text);
                      await uProv.updateEmail(controller.text);
                      
                      if (context.mounted) {
                        Navigator.pop(context);
                        _showCustomSnackBar(context, 'Verification email sent! Please check your inbox.');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        _showCustomSnackBar(context, e.toString().replaceAll('Exception: ', ''), isError: true);
                      }
                    } finally {
                      setState(() => isLoading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SwipifyTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('SAVE CHANGES', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditPhoneDialog(BuildContext context, String currentPhone, AuthProvider auth, UserProvider uProv) {
    final controller = TextEditingController(text: currentPhone);
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 32, left: 32, right: 32,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Update Phone Number', style: SwipifyTheme.heading2),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: "New Phone Number",
                  hintText: "+63 912 345 6789",
                  labelStyle: GoogleFonts.inter(color: SwipifyTheme.textSecondary),
                  filled: true,
                  fillColor: SwipifyTheme.backgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    final phone = controller.text.trim();
                    if (phone.isEmpty || phone.length < 8) return;
                    
                    setState(() => isLoading = true);
                    try {
                      final uid = auth.user?.uid;
                      if (uid == null) throw Exception("No active session");
                      
                      await ApiService.sendSmsOtp(phone, uid);
                      
                      if (context.mounted) {
                        Navigator.pop(context);
                        _showPhoneOtpDialog(context, phone, auth, uProv);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                        );
                      }
                    } finally {
                      setState(() => isLoading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SwipifyTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('SEND OTP', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  void _showPhoneOtpDialog(BuildContext context, String phone, AuthProvider auth, UserProvider uProv) {
    final controller = TextEditingController();
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 32, left: 32, right: 32,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Verify Phone Number', style: SwipifyTheme.heading2),
              const SizedBox(height: 8),
              Text('Enter the 6-digit code sent to $phone', style: GoogleFonts.inter(color: SwipifyTheme.textSecondary)),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, letterSpacing: 4, fontSize: 24),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  counterText: "",
                  filled: true,
                  fillColor: SwipifyTheme.backgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    final otp = controller.text.trim();
                    if (otp.length != 6) return;
                    
                    setState(() => isLoading = true);
                    try {
                      final uid = auth.user?.uid;
                      if (uid == null) throw Exception("No active session");
                      
                      await ApiService.verifySmsOtp(uid, phone, otp);
                      auth.updatePhoneNumberLocally(phone);
                      
                      if (context.mounted) {
                        // Pop OTP dialog
                        Navigator.pop(context);
                        
                        // Update local state in UserProvider
                        uProv.updatePhoneNumber(phone);
                        
                        _showCustomSnackBar(context, 'Phone number updated successfully!');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        _showCustomSnackBar(context, e.toString().replaceAll('Exception: ', ''), isError: true);
                      }
                    } finally {
                      setState(() => isLoading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SwipifyTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('VERIFY', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
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

  void _showPasswordResetDialog(AuthProvider auth, String email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Reset Password", style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: Text(
          "We will send a password reset link to $email. Are you sure you want to proceed?",
          style: GoogleFonts.inter(height: 1.6, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CANCEL", style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: SwipifyTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await auth.sendPasswordResetEmail(email);
                if (!mounted) return;
                // ignore: use_build_context_synchronously
                _showCustomSnackBar(context, 'Password reset email sent!');
              } catch (e) {
                if (!mounted) return;
                // ignore: use_build_context_synchronously
                _showCustomSnackBar(context, e.toString(), isError: true);
              }
            },
            child: Text("SEND LINK", style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: SwipifyTheme.primaryColor)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  void _showSocialInfo(BuildContext context, String type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Social Account", style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: Text(
          "Your $type is managed by your social login provider (Google/Facebook). To change it, please update your settings directly in your social account.",
          style: GoogleFonts.inter(height: 1.6, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("GOT IT", style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: SwipifyTheme.primaryColor)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  void _showCustomSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : SwipifyTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 4),
        elevation: 0,
      ),
    );
  }

  void _showDeleteAccountDialog(AuthProvider auth) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Account", style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.red)),
        content: Text(
          "This action is permanent and cannot be undone. All your data will be erased.\n\nAre you sure you want to delete your account?",
          style: GoogleFonts.inter(height: 1.6, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CANCEL", style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: SwipifyTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await auth.deleteAccount();
                if (!mounted) return;
                // ignore: use_build_context_synchronously
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              } catch (e) {
                if (!mounted) return;
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString()), backgroundColor: Colors.red, duration: const Duration(seconds: 4)),
                );
              }
            },
            child: Text("DELETE", style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.red)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> items;
  const _SettingsSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12, top: 12),
          child: Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800, 
              fontSize: 11, 
              color: SwipifyTheme.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: SwipifyTheme.glassShadow,
            border: Border.all(color: SwipifyTheme.borderColor),
          ),
          child: Column(
            children: List.generate(items.length, (i) {
              return Column(
                children: [
                  items[i],
                  if (i < items.length - 1) 
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Divider(height: 1, color: SwipifyTheme.borderColor),
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  const _SettingsTile({required this.icon, required this.title, this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: SwipifyTheme.primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: SwipifyTheme.primaryColor, size: 20),
      ),
      title: Text(
        title, 
        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: SwipifyTheme.textPrimary),
      ),
      subtitle: subtitle != null
          ? Text(subtitle!, style: GoogleFonts.inter(fontSize: 12, color: SwipifyTheme.textSecondary, fontWeight: FontWeight.w500))
          : null,
      trailing: const Icon(Icons.chevron_right_rounded, color: SwipifyTheme.borderColor, size: 20),
      onTap: onTap,
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleTile({required this.title, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SwitchListTile(
        title: Text(
          title, 
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: SwipifyTheme.textPrimary),
        ),
        value: value,
        onChanged: onChanged,
        activeThumbColor: SwipifyTheme.primaryColor,
        activeTrackColor: SwipifyTheme.primaryColor.withValues(alpha: 0.2),
      ),
    );
  }
}
