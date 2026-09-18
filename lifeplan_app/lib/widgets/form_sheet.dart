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
  Widget Function(BuildContext context)? footerBuilder,
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
              if (footerBuilder != null) ...[
                const SizedBox(height: 10),
                footerBuilder(ctx),
              ],
            ],
          ),
        ),
      );
    },
  );
}

const formDangerColor = Color(0xFFB3401E);

/// ถามยืนยันก่อนลบ — คืน true เมื่อผู้ใช้กด "ลบ"
Future<bool> confirmDeleteDialog(BuildContext context, {required String title, required String message}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('ยกเลิก')),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(foregroundColor: formDangerColor),
          child: const Text('ลบ'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// ปุ่ม "ลบ" ใต้ปุ่มบันทึกของฟอร์มแก้ไข (ใช้กับ `footerBuilder`)
///
/// ถามยืนยัน → ปิดฟอร์ม → เรียก [onDelete] → แสดง SnackBar บนหน้าที่เปิดฟอร์ม ([pageContext])
class FormDeleteButton extends StatelessWidget {
  final BuildContext pageContext;
  final String label;
  final String confirmTitle;
  final String confirmMessage;
  final String doneMessage;
  final Future<void> Function() onDelete;

  const FormDeleteButton({
    super.key,
    required this.pageContext,
    required this.label,
    required this.confirmTitle,
    required this.confirmMessage,
    required this.doneMessage,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: () async {
          if (!await confirmDeleteDialog(context, title: confirmTitle, message: confirmMessage)) return;
          if (context.mounted) Navigator.of(context).pop();
          await onDelete();
          if (pageContext.mounted) {
            ScaffoldMessenger.of(pageContext).showSnackBar(SnackBar(content: Text(doneMessage)));
          }
        },
        style: TextButton.styleFrom(
          foregroundColor: formDangerColor,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: const Icon(Icons.delete_outline_rounded, size: 20),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// ปุ่มดินสอเล็ก ๆ ท้ายแถว สำหรับรายการที่ "แตะ" ถูกใช้ทำอย่างอื่นอยู่แล้ว (ติ๊กเสร็จ/เลื่อนสถานะ)
class RowEditButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color color;

  const RowEditButton({super.key, required this.onTap, this.color = AppColors.textFaint});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'แก้ไข',
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        child: SizedBox(width: 36, height: 36, child: Icon(Icons.edit_outlined, size: 18, color: color)),
      ),
    );
  }
}

/// ช่องกดเลือกค่า (วันที่/เวลา) หน้าตาเดียวกับ AuthField แต่เปิด picker แทนคีย์บอร์ด
class PickerBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const PickerBox({super.key, required this.label, required this.value, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
        const SizedBox(height: 7),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border, width: 1.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(icon, size: 17, color: AppColors.textFaint),
                const SizedBox(width: 10),
                Expanded(child: Text(value, style: const TextStyle(fontSize: 14, color: AppColors.text))),
              ],
            ),
          ),
        ),
      ],
    );
  }
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
