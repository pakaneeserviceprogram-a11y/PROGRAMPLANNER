import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'progress_screen.dart';
import 'schedule_screen.dart';

/// Bottom-nav shell: หน้าหลัก / ตารางเวลา / ความคืบหน้า / โปรไฟล์.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _tabs = [
    DashboardScreen(),
    ScheduleScreen(),
    ProgressScreen(),
    ProfileScreen(),
  ];

  static const _items = [
    (icon: Icons.home_rounded, outline: Icons.home_outlined, label: 'หน้าหลัก'),
    (icon: Icons.calendar_month_rounded, outline: Icons.calendar_month_outlined, label: 'ตารางเวลา'),
    (icon: Icons.trending_up_rounded, outline: Icons.trending_up_rounded, label: 'ความคืบหน้า'),
    (icon: Icons.person_rounded, outline: Icons.person_outline_rounded, label: 'โปรไฟล์'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_items.length, (i) {
                final active = i == _index;
                final item = _items[i];
                return GestureDetector(
                  onTap: () => setState(() => _index = i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        active ? item.icon : item.outline,
                        size: 22,
                        color: active ? AppColors.primary : AppColors.textFaint,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: active ? AppColors.primary : AppColors.textFaint,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
