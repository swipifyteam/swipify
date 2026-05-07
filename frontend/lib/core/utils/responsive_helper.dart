import 'package:flutter/material.dart';

/// Helper class to handle responsive design across different screen sizes.
/// Follows a mobile-first adaptive approach.
class ResponsiveHelper {
  // Breakpoints
  static const double mobileBreakpoint = 700;
  static const double tabletBreakpoint = 1100;

  /// Returns true if the screen width is less than 700.
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;

  /// Returns true if the screen width is between 700 and 1100.
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobileBreakpoint &&
      MediaQuery.of(context).size.width < tabletBreakpoint;

  /// Returns true if the screen width is 1100 or greater.
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint;

  /// Returns the appropriate cross axis count for grids based on screen size.
  static int getCrossAxisCount(BuildContext context, {int mobile = 1, int tablet = 2, int desktop = 4}) {
    if (isMobile(context)) return mobile;
    if (isTablet(context)) return tablet;
    return desktop;
  }

  /// Returns a responsive padding based on screen size.
  static EdgeInsets getPadding(BuildContext context) {
    if (isMobile(context)) return const EdgeInsets.all(16.0);
    if (isTablet(context)) return const EdgeInsets.all(24.0);
    return const EdgeInsets.all(32.0);
  }
}
