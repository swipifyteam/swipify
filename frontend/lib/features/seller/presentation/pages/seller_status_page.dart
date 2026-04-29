// lib/features/seller/presentation/pages/seller_status_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/features/seller/service/seller_provider.dart';
import 'package:swipify/features/seller/domain/entities/seller_entity.dart';



class SellerStatusPage extends StatefulWidget {
  const SellerStatusPage({super.key});

  @override
  State<SellerStatusPage> createState() => _SellerStatusPageState();
}

class _SellerStatusPageState extends State<SellerStatusPage> {
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
              Icon(Icons.hourglass_empty, size: 80, color: SwipifyTheme.primaryColor),
              const SizedBox(height: 24),
              const Text(
                'Application Pending',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'We are reviewing your seller application. You will receive a notification once it has been approved. This usually takes 1-2 business days.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.5),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  final authProvider = context.read<AuthProvider>();
                  final sellerProvider = context.read<SellerProvider>();
                  final uid = authProvider.user?.uid;
                  if (uid == null) return;
                  await authProvider.refreshUserData();
                  if (!context.mounted) return;
                  await sellerProvider.loadSellerStatus(uid);
                  // If status is no longer pending, return to profile so the user can see the update
                  if (!context.mounted) return;
                  final status = sellerProvider.status;
                  if (status != SellerStatus.pending) {
                    Navigator.pop(context);
                  }
                },
                child: const Text('Refresh Status'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Return to Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

