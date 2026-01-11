import 'package:flutter/material.dart';

/// Shared app colors
class AppColors {
  static const primary = Color(0xFFFF7043);
}

/// Quick access to theme colors via context
extension AppColorsX on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
}

/// Shared FAB styles
class AppFab {
  static const backgroundColor = AppColors.primary;
  static const foregroundColor = Colors.white;

  static FloatingActionButton icon({
    required VoidCallback onPressed,
    required IconData icon,
    double iconSize = 24,
  }) {
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      shape: const CircleBorder(),
      child: Icon(icon, size: iconSize),
    );
  }

  static FloatingActionButton add({required VoidCallback onPressed}) {
    return icon(onPressed: onPressed, icon: Icons.add, iconSize: 28);
  }

  static FloatingActionButton map({required VoidCallback onPressed}) {
    return icon(onPressed: onPressed, icon: Icons.map_outlined);
  }
}
