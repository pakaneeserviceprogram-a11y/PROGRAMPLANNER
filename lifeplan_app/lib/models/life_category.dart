import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The life domains LifePlan tracks. Shared across dashboard, schedule and
/// progress so every module keeps one consistent color + icon.
enum LifeCategory { exercise, nutrition, sleep, work, crm, finance, learning }

extension LifeCategoryX on LifeCategory {
  String get label => switch (this) {
        LifeCategory.exercise => 'ออกกำลังกาย',
        LifeCategory.nutrition => 'ทานอาหาร & โภชนาการ',
        LifeCategory.sleep => 'คุณภาพการนอน',
        LifeCategory.work => 'งานประจำ',
        LifeCategory.crm => 'ลูกค้า & ขายประกัน',
        LifeCategory.finance => 'การเงิน',
        LifeCategory.learning => 'เรียนรู้ & พัฒนาตนเอง',
      };

  Color get color => switch (this) {
        LifeCategory.exercise => AppColors.exercise,
        LifeCategory.nutrition => AppColors.nutrition,
        LifeCategory.sleep => AppColors.sleep,
        LifeCategory.work => AppColors.work,
        LifeCategory.crm => AppColors.crm,
        LifeCategory.finance => AppColors.finance,
        LifeCategory.learning => AppColors.learning,
      };

  Color get softColor => switch (this) {
        LifeCategory.exercise => AppColors.exerciseSoft,
        LifeCategory.nutrition => AppColors.nutritionSoft,
        LifeCategory.sleep => AppColors.sleepSoft,
        LifeCategory.work => AppColors.workSoft,
        LifeCategory.crm => AppColors.crmSoft,
        LifeCategory.finance => AppColors.financeSoft,
        LifeCategory.learning => AppColors.learningSoft,
      };

  IconData get icon => switch (this) {
        LifeCategory.exercise => Icons.directions_run_rounded,
        LifeCategory.nutrition => Icons.restaurant_rounded,
        LifeCategory.sleep => Icons.bedtime_rounded,
        LifeCategory.work => Icons.work_rounded,
        LifeCategory.crm => Icons.groups_rounded,
        LifeCategory.finance => Icons.account_balance_wallet_rounded,
        LifeCategory.learning => Icons.menu_book_rounded,
      };
}
