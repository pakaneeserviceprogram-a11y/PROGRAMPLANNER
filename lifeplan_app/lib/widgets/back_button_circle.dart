import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class BackButtonCircle extends StatelessWidget {
  const BackButtonCircle({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.center,
        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 17, color: AppColors.text),
      ),
    );
  }
}
