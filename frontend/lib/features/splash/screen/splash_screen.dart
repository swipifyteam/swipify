// lib/features/splash/screen/splash_screen.dart
// Splash Screen for Swipify.
// Handles initial authentication state check and entrance animation.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/features/navigation/main_nav_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    // 1. Initial delay for splash animation branding
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    final auth = context.read<AuthProvider>();
    
    // 2. If logged in, wait for the full profile (including roles) from Firestore.
    // This prevents race conditions where 'isAdmin' is false because the role 
    // hasn't arrived from the Firestore stream yet.
    if (auth.isLoggedIn) {
      debugPrint('[SPLASH] User logged in, waiting for profile data...');
      await auth.waitForProfile();
    }
    
    if (!mounted) return;

    // 3. Navigate based on the resolved role
    if (auth.isLoggedIn && auth.user?.isAdmin == true) {
      debugPrint('[SPLASH] Admin detected (${auth.user?.role}), redirecting to dashboard');
      Navigator.of(context).pushReplacementNamed('/admin');
    } else {
      // 🏁 GUEST ACCESS MODE / CONSUMER MODE 🏁
      // Users can browse products even when unauthenticated.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2D3748),
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // SWIPIFY GRADIENT S LOGO
              Image.asset(
                'assets/images/logo.png',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              const Text(
                "Swipify",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Swipe. Shop. Swipify.",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

