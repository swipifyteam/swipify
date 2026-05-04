import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swipify/core/theme.dart';

class CategoryChip extends StatelessWidget {
  final String category;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.category,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: backgroundColor.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: backgroundColor.withValues(alpha: 0.1)),
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              category,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: SwipifyTheme.textPrimary,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
