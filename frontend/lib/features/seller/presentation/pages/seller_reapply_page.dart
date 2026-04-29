// lib/features/seller/presentation/pages/seller_reapply_page.dart
import 'package:flutter/material.dart';
import 'package:swipify/features/seller/presentation/pages/seller_onboarding_page.dart';

class SellerReapplyPage extends StatelessWidget {
  const SellerReapplyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Application Status')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Colors.red),
              const SizedBox(height: 24),
              const Text(
                'Application Rejected',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Unfortunately, your seller application could not be approved at this time. Please ensure all your details and documents are correct.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.5),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const SellerOnboardingPage()),
                  );
                },
                child: const Text('Reapply Now'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Return Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
