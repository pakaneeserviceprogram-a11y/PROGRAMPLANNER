import 'dart:async';

import 'package:flutter/material.dart';

import '../data/platform_support.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../data/business_card_scanner.dart';
import '../data/id_gen.dart';
import '../data/medication_reminder.dart';
import '../data/medicine_label_parser.dart';
import '../data/notifications.dart';
import '../data/repositories/medication_repository.dart';
import '../models/medication.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/back_button_circle.dart';
import '../widgets/form_sheet.dart';
import '../widgets/section_heading.dart';

/// เตือนกินยา — แยกยารักษาโรคออกจากวิตามิน/ยาบำรุง
///
/// **แอปไม่ได้แนะนำยาและไม่ได้ตรวจปฏิกิริยาระหว่างยา** ข้อมูลทุกอย่างมาจากผู้ใช้
/// (พิมพ์เอง หรือสแกนจากกล่องยาของตัวเอง — ดู [MedicineLabelParser])
class MedicationScreen extends StatefulWidget {
  /// เทสต์ส่งตัวอ่านปลอมเข้ามาแทน ML Kit
  final CardTextRecognizer? recognizer;

  /// เทสต์ส่งฟังก์ชันเลือกรูปของตัวเองเข้ามา (คืน path ของรูป, null = ผู้ใช้ยกเลิก)
  final Future<String?> Function(ImageSource source)? pickImage;

  const MedicationScreen({super.key, this.recognizer, this.pickImage});

  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen> {
  final MedicationRepository _meds = MedicationRepository();
  final MedicationLogRepository _log = MedicationLogRepository();

  bool _scanning = false;

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _syncReminders() {
    // ตั้งเตือนใหม่ไม่สำเร็จไม่ควรทำให้การบันทึกยาล้ม — ข้อมูลถูกบันทึกไปแล้ว
    unawaited(NotificationService.syncScheduleReminders().catchError((Object e) {
      debugPrint('ตั้งการแจ้งเตือนยาใหม่ไม่สำเร็จ: $e');
      return 0;
    }));
  }

  Future<String?> _pick(ImageSource source) async {
    if (widget.pickImage != null) return widget.pickImage!(source);
    final file = await ImagePicker().pickImage(source: source, imageQuality: 90);
    return file?.path;
  }

  /// ถ่ายรูปกล่องยา → แกะชื่อ/ตัวยาที่อ่านได้ → เปิดฟอร์มให้ผู้ใช้ตรวจก่อนบันทึก
  ///
  /// ปิดสถานะ "กำลังอ่าน" ก่อนเปิดฟอร์ม เพราะฟอร์มค้างอยู่จนผู้ใช้กดบันทึก/ปิด
  Future<void> _scanLabel() async {
    if (_scanning) return;
    setState(() => _scanning = true);

    MedicineLabel? label;
    try {
      final path = await _pick(ImageSource.camera);
      if (path == null) return; // ผู้ใช้ยกเลิก

      final recognizer = widget.recognizer ?? CardTextRecognizer.instance;
      label = MedicineLabelParser.parse(await recognizer.recognize(path));
    } catch (e) {
      if (mounted) _toast('อ่านรูปไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }

    if (label == null || !mounted) return;

    if (label.isEmpty) {
      _toast('อ่านฉลากไม่ออก — ลองถ่ายให้เห็นบรรทัดตัวยาชัด ๆ หรือพิมพ์เอง');
    } else if (label.ingredients.isEmpty) {
      _toast('อ่านได้แต่ชื่อยา ยังไม่เจอบรรทัดตัวยา — เพิ่มเองได้ในฟอร์ม');
    } else {
      _toast('อ่านตัวยาได้ ${label.ingredients.length} รายการ — ตรวจให้ตรงกับกล่องก่อนบันทึก');
    }
    await _openForm(prefill: label);
  }

  Future<void> _toggleDose(MedicationDose dose) async {
    final taken = await _log.toggle(DateTime.now(), dose.medication.id, dose.time);
    _toast(taken ? 'บันทึกว่ากิน ${dose.medication.name} แล้ว' : 'ยกเลิกการติ๊ก ${dose.medication.name}');
  }

  Future<void> _openForm({Medication? existing, MedicineLabel? prefill}) async {
    final nameController = TextEditingController(text: existing?.name ?? prefill?.brand ?? '');
    final brandController = TextEditingController(text: existing?.brand ?? prefill?.brand ?? '');
    final conditionController = TextEditingController(text: existing?.conditionLabel ?? '');
    final doseController = TextEditingController(text: existing?.dose ?? '1 เม็ด');
    final noteController = TextEditingController(text: existing?.note ?? '');

    var kind = existing?.kind ?? MedicationKind.treatment;
    var timing = existing?.timing ?? DoseTiming.afterMeal;
    var times = [...?existing?.times];
    if (times.isEmpty) times = ['08:00'];
    var ingredients = [...?existing?.ingredients, ...?prefill?.ingredients];

    await showAppFormSheet(
      context: context,
      title: existing == null ? 'เพิ่มยา' : 'แก้ไขยา',
      submitLabel: 'บันทึก',
      footerBuilder: existing == null
          ? null
          : (sheetCtx) => FormDeleteButton(
                pageContext: context,
                label: 'ลบยานี้',
                confirmTitle: 'ลบยานี้?',
                confirmMessage: '“${existing.name}” จะถูกลบออกจากรายการยา และการเตือนจะหยุด',
                doneMessage: 'ลบ “${existing.name}” แล้ว',
                onDelete: () async {
                  await _meds.delete(existing.id);
                  _syncReminders();
                },
              ),
      bodyBuilder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LabeledDropdown<MedicationKind>(
              label: 'ประเภท',
              value: kind,
              options: MedicationKind.values,
              display: (k) => k.label,
              onChanged: (v) => setSheetState(() => kind = v!),
            ),
            const SizedBox(height: 14),
            AuthField(
              key: const ValueKey('med-name-field'),
              label: 'ชื่อยา',
              hint: 'เช่น ยาลดความดัน (เช้า)',
              controller: nameController,
            ),
            const SizedBox(height: 14),
            AuthField(
              key: const ValueKey('med-brand-field'),
              label: 'ยี่ห้อ / ชื่อบนกล่อง (ไม่ใส่ก็ได้)',
              hint: 'เช่น Norvasc',
              controller: brandController,
            ),
            const SizedBox(height: 14),
            AuthField(
              key: const ValueKey('med-condition-field'),
              label: kind == MedicationKind.treatment ? 'โรค / อาการที่กินยานี้' : 'เป้าหมายการบำรุง (ไม่ใส่ก็ได้)',
              hint: kind == MedicationKind.treatment ? 'เช่น ความดันโลหิตสูง' : 'เช่น บำรุงกระดูก',
              controller: conditionController,
            ),
            const SizedBox(height: 14),
            AuthField(
              key: const ValueKey('med-dose-field'),
              label: 'กินครั้งละ',
              hint: '1 เม็ด',
              controller: doseController,
            ),
            const SizedBox(height: 14),
            LabeledDropdown<DoseTiming>(
              label: 'ช่วงที่กิน',
              value: timing,
              options: DoseTiming.values,
              display: (t) => t.label,
              onChanged: (v) => setSheetState(() => timing = v!),
            ),
            const SizedBox(height: 16),

            _SheetLabel('เวลาที่ต้องกิน (${times.length} ครั้ง/วัน)'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final time in times)
                  InputChip(
                    key: ValueKey('med-time-$time'),
                    label: Text(time),
                    onDeleted: () => setSheetState(() => times.remove(time)),
                    backgroundColor: AppColors.surface2,
                  ),
                ActionChip(
                  key: const ValueKey('med-add-time'),
                  avatar: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('เพิ่มเวลา'),
                  onPressed: () async {
                    final picked = await showTimePicker(context: ctx, initialTime: const TimeOfDay(hour: 8, minute: 0));
                    if (picked == null) return;
                    final value =
                        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                    if (times.contains(value)) return;
                    setSheetState(() {
                      times.add(value);
                      times.sort();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            _SheetLabel('ตัวยา / ส่วนประกอบ'),
            const SizedBox(height: 4),
            const Text('ใส่ตามที่เขียนบนกล่องยาของคุณเท่านั้น — แอปไม่ได้ค้นข้อมูลยาให้',
                style: TextStyle(fontSize: 11.5, height: 1.4, color: AppColors.textFaint)),
            const SizedBox(height: 8),
            if (ingredients.isEmpty)
              const Text('ยังไม่ได้ใส่', style: TextStyle(fontSize: 12.5, color: AppColors.textFaint))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final ingredient in ingredients)
                    InputChip(
                      key: ValueKey('med-ingredient-${ingredient.name}'),
                      label: Text(ingredient.label),
                      onDeleted: () => setSheetState(() => ingredients.remove(ingredient)),
                      backgroundColor: AppColors.surface2,
                    ),
                ],
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                key: const ValueKey('med-add-ingredient'),
                avatar: const Icon(Icons.add_rounded, size: 16),
                label: const Text('เพิ่มตัวยา'),
                onPressed: () async {
                  final added = await _askIngredient(ctx);
                  if (added != null) setSheetState(() => ingredients.add(added));
                },
              ),
            ),
            const SizedBox(height: 14),
            AuthField(
              key: const ValueKey('med-note-field'),
              label: 'บันทึกเพิ่มเติม (ไม่ใส่ก็ได้)',
              hint: 'เช่น ห้ามกินพร้อมนม',
              controller: noteController,
            ),
          ],
        ),
      ),
      onSubmit: () async {
        final name = nameController.text.trim();
        if (name.isEmpty) {
          _toast('ใส่ชื่อยาก่อนบันทึก');
          return;
        }
        final brand = brandController.text.trim();
        final condition = conditionController.text.trim();
        final dose = doseController.text.trim();
        final note = noteController.text.trim();

        await _meds.put(Medication(
          id: existing?.id ?? newId(),
          name: name,
          brand: brand.isEmpty ? null : brand,
          kind: kind,
          conditionLabel: condition.isEmpty ? null : condition,
          ingredients: ingredients,
          dose: dose.isEmpty ? '1 เม็ด' : dose,
          times: [...times]..sort(),
          timing: timing,
          note: note.isEmpty ? null : note,
          active: existing?.active ?? true,
        ));
        _syncReminders();
        if (mounted) Navigator.of(context).pop();
      },
    );
  }

  /// ถามชื่อตัวยา + ปริมาณ (ตามที่อยู่บนฉลาก)
  Future<MedIngredient?> _askIngredient(BuildContext sheetContext) async {
    final nameController = TextEditingController();
    final strengthController = TextEditingController();

    return showDialog<MedIngredient>(
      context: sheetContext,
      builder: (ctx) => AlertDialog(
        title: const Text('เพิ่มตัวยา'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AuthField(
              key: const ValueKey('ingredient-name-field'),
              label: 'ชื่อตัวยา',
              hint: 'เช่น Paracetamol',
              controller: nameController,
            ),
            const SizedBox(height: 12),
            AuthField(
              key: const ValueKey('ingredient-strength-field'),
              label: 'ปริมาณ (ไม่ใส่ก็ได้)',
              hint: 'เช่น 500 mg',
              controller: strengthController,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('ยกเลิก')),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final strength = strengthController.text.trim();
              Navigator.of(ctx).pop(MedIngredient(name: name, strength: strength.isEmpty ? null : strength));
            },
            child: const Text('เพิ่ม'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ValueListenableBuilder<Box<Map>>(
          valueListenable: _meds.listenable(),
          builder: (context, _, _) => ValueListenableBuilder<Box<Map>>(
            valueListenable: _log.listenable(),
            builder: (context, _, _) => _buildBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final all = _meds.getActive();
    final doses = MedicationReminder.dosesFor(all, _log.takenOn(DateTime.now()));
    final overdue = MedicationReminder.overdue(doses);
    final next = MedicationReminder.next(doses);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const Row(
          children: [
            BackButtonCircle(),
            SizedBox(width: 12),
            Expanded(
              child: Text('ยาและวิตามิน',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text('ตั้งเวลาเตือนกินยา แล้วติ๊กเมื่อกินแล้ว — ข้อมูลยาทั้งหมดคุณใส่เอง แอปไม่ได้แนะนำยาหรือตรวจยาตีกัน',
            style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textFaint)),
        const SizedBox(height: 18),

        Row(
          children: [
            Expanded(
              child: _ActionButton(
                key: const ValueKey('med-add'),
                icon: Icons.add_rounded,
                label: 'เพิ่มยาเอง',
                onTap: () => _openForm(),
              ),
            ),
            if (PlatformSupport.textScan) ...[
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  key: const ValueKey('med-scan'),
                  icon: Icons.photo_camera_rounded,
                  label: 'สแกนกล่องยา',
                  onTap: _scanning ? null : _scanLabel,
                ),
              ),
            ],
          ],
        ),
        if (_scanning) ...[
          const SizedBox(height: 18),
          const Center(child: CircularProgressIndicator()),
        ],
        const SizedBox(height: 16),

        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeading(
                title: 'ยาของวันนี้',
                action: doses.isEmpty ? null : '${doses.where((d) => d.taken).length} / ${doses.length}',
              ),
              const SizedBox(height: 12),
              if (doses.isEmpty)
                const Text('ยังไม่มียาที่ตั้งเวลาไว้ — กด “เพิ่มยาเอง” เพื่อเริ่ม',
                    style: TextStyle(fontSize: 12.5, color: AppColors.textFaint))
              else ...[
                if (overdue.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text('เลยเวลาแล้ว ${overdue.length} ครั้ง',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: formDangerColor)),
                  )
                else if (next != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text('ครั้งถัดไป ${next.time} • ${next.medication.name}',
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                  ),
                for (final dose in doses)
                  _DoseRow(
                    key: ValueKey('dose-${dose.medication.id}-${dose.time}'),
                    dose: dose,
                    onToggle: () => _toggleDose(dose),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        for (final kind in MedicationKind.values) ...[
          _MedicationSection(
            kind: kind,
            items: all.where((m) => m.kind == kind).toList(),
            onEdit: (med) => _openForm(existing: med),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _MedicationSection extends StatelessWidget {
  final MedicationKind kind;
  final List<Medication> items;
  final ValueChanged<Medication> onEdit;

  const _MedicationSection({required this.kind, required this.items, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(title: kind.label, action: items.isEmpty ? null : '${items.length} รายการ'),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(
              kind == MedicationKind.treatment
                  ? 'ยังไม่มียารักษาโรค'
                  : 'ยังไม่มีวิตามินหรือยาบำรุง',
              style: const TextStyle(fontSize: 12.5, color: AppColors.textFaint),
            )
          else
            for (final med in items) _MedicationRow(med: med, onEdit: () => onEdit(med)),
        ],
      ),
    );
  }
}

class _MedicationRow extends StatelessWidget {
  final Medication med;
  final VoidCallback onEdit;

  const _MedicationRow({required this.med, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final detail = [
      if (med.times.isNotEmpty) med.times.join(', '),
      med.dose,
      med.timing.label,
    ].join(' • ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(med.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(detail, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                if (med.conditionLabel != null && med.conditionLabel!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('สำหรับ${med.conditionLabel}',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.nutrition, fontWeight: FontWeight.w700)),
                ],
                if (med.ingredients.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(med.ingredientSummary,
                      style: const TextStyle(fontSize: 11.5, height: 1.4, color: AppColors.textFaint)),
                ],
                if (med.note != null && med.note!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(med.note!, style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
                ],
              ],
            ),
          ),
          RowEditButton(onTap: onEdit),
        ],
      ),
    );
  }
}

class _DoseRow extends StatelessWidget {
  final MedicationDose dose;
  final VoidCallback onToggle;

  const _DoseRow({super.key, required this.dose, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final overdue = dose.isOverdue(DateTime.now());
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              dose.taken ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 22,
              color: dose.taken
                  ? AppColors.exercise
                  : overdue
                      ? formDangerColor
                      : AppColors.textFaint,
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 48,
              child: Text(dose.time,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dose.medication.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: dose.taken ? AppColors.textFaint : AppColors.text,
                      decoration: dose.taken ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('${dose.medication.dose} • ${dose.medication.timing.label}',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: dose.medication.kind == MedicationKind.treatment ? AppColors.nutritionSoft : AppColors.exerciseSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                dose.medication.kind.shortLabel,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: dose.medication.kind == MedicationKind.treatment ? AppColors.nutrition : AppColors.exercise,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  final String text;

  const _SheetLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textMuted));
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({super.key, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: enabled ? AppColors.nutritionSoft : AppColors.surface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: enabled ? AppColors.nutrition : AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: enabled ? AppColors.nutrition : AppColors.textFaint),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: enabled ? AppColors.nutrition : AppColors.textFaint,
                )),
          ],
        ),
      ),
    );
  }
}
