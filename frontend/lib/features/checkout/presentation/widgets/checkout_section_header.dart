// lib/features/checkout/presentation/widgets/checkout_section_header.dart
import 'package:flutter/material.dart';

class CheckoutSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onActionPressed;
  final String? actionLabel;

  const CheckoutSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.onActionPressed,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          if (onActionPressed != null && actionLabel != null)
            TextButton(
              onPressed: onActionPressed,
              child: Text(
                actionLabel!,
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
