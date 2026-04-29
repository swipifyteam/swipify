import 'package:flutter/material.dart';

class AppConstants {
  // Spacing
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;

  // Border Radius
  static const double radiusSmall = 4.0;
  static const double radiusMedium = 8.0;

  // Assets (Placeholders for now)
  static const String logoPath = 'assets/logo.png';
  
  // Dummy Data for testing
  static const List<String> bannerImages = [
    'https://picsum.photos/800/400?random=1',
    'https://picsum.photos/800/400?random=2',
    'https://picsum.photos/800/400?random=3',
  ];

  static const List<Map<String, dynamic>> brands = [
    {'name': 'Nike', 'icon': Icons.sports_baseball},
    {'name': 'Samsung', 'icon': Icons.smartphone},
    {'name': 'Apple', 'icon': Icons.laptop_mac},
    {'name': 'Adidas', 'icon': Icons.run_circle},
    {'name': 'Sony', 'icon': Icons.tv},
    {'name': 'Nestle', 'icon': Icons.local_hospital},
    {'name': 'Toyota', 'icon': Icons.directions_car},
    {'name': 'Logitech', 'icon': Icons.mouse},
  ];
}
