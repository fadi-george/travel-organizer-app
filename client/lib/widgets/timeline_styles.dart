import 'package:flutter/material.dart';

/// Shared styles and helpers for timeline view cards
abstract final class TimelineStyles {
  // Spacing & Dimensions
  static const double iconSize = 20;
  static const double iconContainerSize = 40;
  static const double iconContainerAlpha = 0.12;
  static const double borderRadius = 16;
  static const double contentSpacing = 14;

  // Padding & Margins
  static const EdgeInsets containerPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 14,
  );
  static const EdgeInsets itemMargin = EdgeInsets.only(bottom: 12);

  // Typography
  static const double titleFontSize = 16;
  static const FontWeight titleFontWeight = FontWeight.w600;
  static const double subtitleFontSize = 13;
  static const FontWeight subtitleFontWeight = FontWeight.w500;
  static const double subtitleAlpha = 0.5;

  /// Creates the standard timeline card container decoration
  static BoxDecoration containerDecoration({
    required ColorScheme colorScheme,
    required bool isDark,
  }) {
    return BoxDecoration(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: isDark
            ? colorScheme.outline.withValues(alpha: 0.35)
            : Colors.grey.shade300,
      ),
    );
  }

  /// Creates the circular icon container with accent color background
  static Widget iconContainer({
    required Color accentColor,
    required Widget child,
  }) {
    return Container(
      width: iconContainerSize,
      height: iconContainerSize,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: iconContainerAlpha),
        shape: BoxShape.circle,
      ),
      child: Center(child: child),
    );
  }

  /// Returns the title text style
  static TextStyle titleStyle(ColorScheme colorScheme) {
    return TextStyle(
      fontSize: titleFontSize,
      fontWeight: titleFontWeight,
      color: colorScheme.onSurface,
    );
  }

  /// Returns the subtitle text style
  static TextStyle subtitleStyle(ColorScheme colorScheme) {
    return TextStyle(
      fontSize: subtitleFontSize,
      fontWeight: subtitleFontWeight,
      color: colorScheme.onSurface.withValues(alpha: subtitleAlpha),
    );
  }
}
