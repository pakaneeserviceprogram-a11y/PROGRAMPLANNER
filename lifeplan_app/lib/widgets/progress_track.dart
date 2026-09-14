import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A thin rounded progress bar matching the design system.
class ProgressTrack extends StatelessWidget {
  final double value; // 0.0 - 1.0
  final Color color;
  final Color? trackColor;
  final double height;

  const ProgressTrack({
    super.key,
    required this.value,
    required this.color,
    this.trackColor,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: height,
        backgroundColor: trackColor ?? AppColors.surface2,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}
