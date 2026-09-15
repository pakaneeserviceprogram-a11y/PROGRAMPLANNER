import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'auth_widgets.dart';

/// Shared bottom-sheet chrome for every "add ___" form in the app: a title,
/// scrollable body, and a full-width primary submit button that respects
/// the keyboard inset.
Future<void> showAppFormSheet({
  required BuildContext context,
  required String title,
  required Widget Function(BuildContext context) bodyBuilder,
  required String submitLabel,
  required VoidCallback onSubmit,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(999))),
              ),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 18),
              bodyBuilder(ctx),
              const SizedBox(height: 20),
              PrimaryButton(label: submitLabel, onPressed: onSubmit),
            ],
          ),
        ),
      );
    },
  );
}

/// Small labeled dropdown matching the AuthField visual language.
class LabeledDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> options;
  final String Function(T) display;
  /// null = ปิดใช้งาน dropdown (DropdownButton จะเป็นสีจาง กดไม่ได้)
  final ValueChanged<T?>? onChanged;

  const LabeledDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.display,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
        const SizedBox(height: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border, width: 1.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textFaint),
              items: options
                  .map((o) => DropdownMenuItem(value: o, child: Text(display(o), style: const TextStyle(fontSize: 14, color: AppColors.text))))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
