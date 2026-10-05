import 'dart:async';

import 'package:flutter/material.dart';

import '../data/calendar_utils.dart';
import '../data/id_gen.dart';
import '../data/notifications.dart';
import '../data/repositories/client_repository.dart';
import '../models/client.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/back_button_circle.dart';
import '../widgets/form_sheet.dart';
import '../widgets/section_heading.dart';

/// รายละเอียดลูกค้าหนึ่งราย — แผนประกัน, การเข้าพบ (พร้อมของขวัญ) และวันที่ต้องติดตาม
///
/// ทุกอย่างเก็บอยู่ในเรคคอร์ด `Client` เดียว จึงติดไปกับไฟล์สำรองและการลบลูกค้าโดยอัตโนมัติ
class ClientDetailScreen extends StatelessWidget {
  final String clientId;

  const ClientDetailScreen({super.key, required this.clientId});

  static const _dangerColor = Color(0xFFD64545);

  static String _money(double v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }

  static String _time(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static String _followUpText(DateTime at) =>
      '${CalendarUtils.thaiDateShort(at)} ${_time(TimeOfDay.fromDateTime(at))} น.';

  Client? _find(ClientRepository repo) {
    for (final c in repo.getAll()) {
      if (c.id == clientId) return c;
    }
    return null;
  }

  /// บันทึกลูกค้า แล้วตั้งการแจ้งเตือนใหม่ (วันติดตามอาจเปลี่ยน)
  Future<void> _save(ClientRepository repo, Client client) async {
    await repo.put(client);
    unawaited(NotificationService.syncScheduleReminders().catchError((Object e) {
      debugPrint('ตั้งการแจ้งเตือนใหม่ไม่สำเร็จ: $e');
      return 0;
    }));
  }

  /// แผนเปลี่ยนแล้วให้เบี้ยของลูกค้าตามผลรวมของแผน — ไม่ต้องกรอกซ้ำสองที่
  Client _withPlans(Client client, List<InsurancePlan> plans) {
    final updated = client.copyWith(plans: plans);
    return plans.isEmpty ? updated : updated.copyWith(premiumAmount: updated.plansPremium);
  }

  Future<void> _openPlanForm(BuildContext context, ClientRepository repo, Client client, {InsurancePlan? existing}) async {
    final nameController = TextEditingController(text: existing?.name);
    final sumController = TextEditingController(
        text: existing != null && existing.sumInsured > 0 ? existing.sumInsured.toStringAsFixed(0) : null);
    final premiumController = TextEditingController(
        text: existing != null && existing.annualPremium > 0 ? existing.annualPremium.toStringAsFixed(0) : null);
    final noteController = TextEditingController(text: existing?.note);
    var status = existing?.status ?? PlanStatus.proposed;

    double parse(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '').trim()) ?? 0;

    await showAppFormSheet(
      context: context,
      title: existing == null ? 'เพิ่มแผนประกัน' : 'แก้ไขแผนประกัน',
      submitLabel: 'บันทึก',
      footerBuilder: existing == null
          ? null
          : (sheetCtx) => FormDeleteButton(
                pageContext: context,
                label: 'ลบแผนนี้',
                confirmTitle: 'ลบแผนนี้?',
                confirmMessage: '“${existing.name}” จะถูกลบออกจากลูกค้ารายนี้',
                doneMessage: 'ลบแผน “${existing.name}” แล้ว',
                onDelete: () => _save(
                  repo,
                  _withPlans(client, client.plans.where((p) => p.id != existing.id).toList()),
                ),
              ),
      bodyBuilder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthField(label: 'ชื่อแผนประกัน', hint: 'เช่น สุขภาพเหมาจ่าย 5 ล้าน', controller: nameController),
            const SizedBox(height: 14),
            LabeledDropdown<PlanStatus>(
              label: 'สถานะ',
              value: status,
              options: PlanStatus.values,
              display: (s) => s.label,
              onChanged: (v) => setState(() => status = v!),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AuthField(
                    label: 'ทุนประกัน (บาท)',
                    hint: '1000000',
                    controller: sumController,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AuthField(
                    label: 'เบี้ยต่อปี (บาท)',
                    hint: '25000',
                    controller: premiumController,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AuthField(label: 'หมายเหตุ (ไม่บังคับ)', hint: 'เช่น รอผลตรวจสุขภาพ', controller: noteController),
          ],
        ),
      ),
      onSubmit: () async {
        final name = nameController.text.trim();
        if (name.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาใส่ชื่อแผนประกัน')));
          return;
        }
        final note = noteController.text.trim();
        // จดวันปิดเฉพาะตอนเพิ่งเปลี่ยนเป็น "มีผลแล้ว" — แก้แผนที่ปิดไปแล้วต้องไม่เลื่อนวันปิด
        final wasActive = existing?.status == PlanStatus.active;
        final closedAt = status != PlanStatus.active
            ? null
            : (wasActive ? existing!.closedAt : DateTime.now());
        final plan = InsurancePlan(
          id: existing?.id ?? newId(),
          name: name,
          sumInsured: parse(sumController),
          annualPremium: parse(premiumController),
          status: status,
          note: note.isEmpty ? null : note,
          closedAt: closedAt,
        );
        final plans = existing == null
            ? [...client.plans, plan]
            : [for (final p in client.plans) p.id == existing.id ? plan : p];
        await _save(repo, _withPlans(client, plans));
        if (context.mounted) Navigator.of(context).pop();
      },
    );
  }

  Future<void> _openVisitForm(BuildContext context, ClientRepository repo, Client client, {ClientVisit? existing}) async {
    final noteController = TextEditingController(text: existing?.note);
    final giftController = TextEditingController(text: existing?.gift);
    var date = existing?.date ?? CalendarUtils.dateOnly(DateTime.now());

    await showAppFormSheet(
      context: context,
      title: existing == null ? 'บันทึกการเข้าพบ' : 'แก้ไขการเข้าพบ',
      submitLabel: 'บันทึก',
      footerBuilder: existing == null
          ? null
          : (sheetCtx) => FormDeleteButton(
                pageContext: context,
                label: 'ลบบันทึกนี้',
                confirmTitle: 'ลบบันทึกการเข้าพบ?',
                confirmMessage: 'การเข้าพบวันที่ ${CalendarUtils.thaiDate(existing.date)} จะถูกลบ',
                doneMessage: 'ลบบันทึกการเข้าพบแล้ว',
                onDelete: () => _save(
                  repo,
                  client.copyWith(visits: client.visits.where((v) => v.id != existing.id).toList()),
                ),
              ),
      bodyBuilder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PickerBox(
              key: const ValueKey('visit-date-field'),
              label: 'วันที่เข้าพบ',
              icon: Icons.event_rounded,
              value: CalendarUtils.thaiDate(date),
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => date = CalendarUtils.dateOnly(picked));
              },
            ),
            const SizedBox(height: 14),
            AuthField(label: 'คุยเรื่องอะไร (ไม่บังคับ)', hint: 'เช่น นำเสนอแผนสุขภาพ ลูกค้าขอคิดก่อน', controller: noteController),
            const SizedBox(height: 14),
            AuthField(label: 'ของขวัญ/ของฝาก (ไม่บังคับ)', hint: 'เช่น กระเช้าผลไม้', controller: giftController),
          ],
        ),
      ),
      onSubmit: () async {
        final note = noteController.text.trim();
        final gift = giftController.text.trim();
        final visit = ClientVisit(
          id: existing?.id ?? newId(),
          date: date,
          note: note.isEmpty ? null : note,
          gift: gift.isEmpty ? null : gift,
        );
        final visits = existing == null
            ? [visit, ...client.visits]
            : [for (final v in client.visits) v.id == existing.id ? visit : v];
        visits.sort((a, b) => b.date.compareTo(a.date));
        await _save(repo, client.copyWith(visits: visits));
        if (context.mounted) Navigator.of(context).pop();
      },
    );
  }

  Future<void> _openFollowUpForm(BuildContext context, ClientRepository repo, Client client) async {
    final now = DateTime.now();
    final current = client.followUpAt;
    // ค่าตั้งต้น: อีก 7 วัน 10 โมง — รอบติดตามที่ใช้บ่อยหลังเข้าพบ
    var date = current != null ? CalendarUtils.dateOnly(current) : CalendarUtils.dateOnly(now.add(const Duration(days: 7)));
    var time = current != null ? TimeOfDay.fromDateTime(current) : const TimeOfDay(hour: 10, minute: 0);
    final noteController = TextEditingController(text: client.followUpNote);

    await showAppFormSheet(
      context: context,
      title: 'ตั้งวันติดตาม ${client.name}',
      submitLabel: 'บันทึก',
      footerBuilder: current == null
          ? null
          : (sheetCtx) => SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () async {
                    Navigator.of(sheetCtx).pop();
                    await _save(repo, client.copyWith(clearFollowUp: true));
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.event_busy_rounded, size: 20),
                  label: const Text('ยกเลิกวันติดตาม', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
      bodyBuilder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final days in const [3, 7, 14, 30])
                  ActionChip(
                    label: Text('อีก $days วัน'),
                    onPressed: () => setState(() => date = CalendarUtils.dateOnly(now.add(Duration(days: days)))),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            PickerBox(
              key: const ValueKey('follow-up-date-field'),
              label: 'วันที่',
              icon: Icons.event_rounded,
              value: 'วัน${CalendarUtils.weekdayFull[date.weekday - 1]}ที่ ${CalendarUtils.thaiDate(date)}',
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => date = CalendarUtils.dateOnly(picked));
              },
            ),
            const SizedBox(height: 14),
            PickerBox(
              key: const ValueKey('follow-up-time-field'),
              label: 'เวลาเตือน',
              icon: Icons.schedule_rounded,
              value: _time(time),
              onTap: () async {
                final picked = await showTimePicker(context: ctx, initialTime: time);
                if (picked != null) setState(() => time = picked);
              },
            ),
            const SizedBox(height: 14),
            AuthField(label: 'ต้องตามเรื่องอะไร (ไม่บังคับ)', hint: 'เช่น ถามผลตัดสินใจแผนสุขภาพ', controller: noteController),
          ],
        ),
      ),
      onSubmit: () async {
        final note = noteController.text.trim();
        final at = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        await _save(
          repo,
          Client(
            id: client.id,
            name: client.name,
            initials: client.initials,
            policyLabel: client.policyLabel,
            stage: client.stage,
            premiumAmount: client.premiumAmount,
            phone: client.phone,
            profileUrl: client.profileUrl,
            source: client.source,
            plans: client.plans,
            visits: client.visits,
            followUpAt: at,
            // ล้างโน้ตได้ด้วยการลบข้อความ (copyWith ทำแบบนั้นไม่ได้)
            followUpNote: note.isEmpty ? null : note,
            createdAt: client.createdAt,
          ),
        );
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ตั้งเตือนติดตาม ${client.name} ${_followUpText(at)} แล้ว')),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ClientRepository();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: repo.listenable(),
          builder: (context, box, child) {
            final client = _find(repo);
            if (client == null) {
              return const Center(child: Text('ไม่พบลูกค้ารายนี้', style: TextStyle(color: AppColors.textMuted)));
            }
            final due = client.isFollowUpDue();
            final gifts = client.visits.where((v) => v.gift != null).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Row(
                  children: [
                    const BackButtonCircle(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(client.name,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                          Text('${client.statusLabel} • ${client.policyLabel}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ติดตามครั้งถัดไป
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeading(
                        title: 'ติดตามครั้งถัดไป',
                        action: client.followUpAt == null ? 'ตั้งวัน' : 'แก้ไข',
                        onAction: () => _openFollowUpForm(context, repo, client),
                      ),
                      const SizedBox(height: 10),
                      if (client.followUpAt == null)
                        const Text('ยังไม่ได้ตั้ง — ตั้งไว้แล้วแอปจะเตือนเมื่อถึงเวลา',
                            style: TextStyle(fontSize: 12.5, color: AppColors.textFaint))
                      else ...[
                        Row(
                          children: [
                            Icon(Icons.notifications_active_rounded, size: 18, color: due ? _dangerColor : AppColors.crm),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${due ? 'เลยกำหนดแล้ว • ' : ''}${_followUpText(client.followUpAt!)}',
                                key: const ValueKey('follow-up-text'),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: due ? _dangerColor : AppColors.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (client.followUpNote != null) ...[
                          const SizedBox(height: 4),
                          Text(client.followUpNote!, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                        ],
                        const SizedBox(height: 8),
                        TextButton.icon(
                          key: const ValueKey('follow-up-done'),
                          onPressed: () async {
                            await _save(repo, client.copyWith(clearFollowUp: true));
                            if (context.mounted) await _openVisitForm(context, repo, client.copyWith(clearFollowUp: true));
                          },
                          style: TextButton.styleFrom(foregroundColor: AppColors.crm, padding: EdgeInsets.zero),
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                          label: const Text('ติดตามแล้ว — บันทึกการเข้าพบ', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // แผนประกัน
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeading(
                        title: 'แผนประกัน',
                        action: '+ เพิ่มแผน',
                        onAction: () => _openPlanForm(context, repo, client),
                      ),
                      const SizedBox(height: 6),
                      if (client.plans.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text('ยังไม่มีแผน — เพิ่มแผนที่เสนอหรือขายให้ลูกค้ารายนี้',
                              style: TextStyle(fontSize: 12.5, color: AppColors.textFaint)),
                        )
                      else ...[
                        for (final plan in client.plans)
                          _PlanRow(plan: plan, onTap: () => _openPlanForm(context, repo, client, existing: plan)),
                        const Divider(height: 18, color: AppColors.border),
                        Text('เบี้ยรวม ฿${_money(client.plansPremium)} / ปี (ไม่นับแผนที่ไม่สนใจ)',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.crm)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // การเข้าพบ & ของขวัญ
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeading(
                        title: 'การเข้าพบ & ของขวัญ',
                        action: '+ บันทึก',
                        onAction: () => _openVisitForm(context, repo, client),
                      ),
                      const SizedBox(height: 6),
                      if (client.visits.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text('ยังไม่มีบันทึกการเข้าพบ',
                              style: TextStyle(fontSize: 12.5, color: AppColors.textFaint)),
                        )
                      else ...[
                        if (gifts.isNotEmpty) ...[
                          Text('ให้ของขวัญไปแล้ว ${gifts.length} ครั้ง — ล่าสุด “${gifts.first.gift}”',
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          const SizedBox(height: 6),
                        ],
                        for (final visit in client.visits)
                          _VisitRow(visit: visit, onTap: () => _openVisitForm(context, repo, client, existing: visit)),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  final InsurancePlan plan;
  final VoidCallback onTap;

  const _PlanRow({required this.plan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final muted = !plan.status.counts;
    final details = [
      if (plan.sumInsured > 0) 'ทุน ฿${ClientDetailScreen._money(plan.sumInsured)}',
      if (plan.annualPremium > 0) 'เบี้ย ฿${ClientDetailScreen._money(plan.annualPremium)}/ปี',
    ].join(' • ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(Icons.shield_outlined, size: 20, color: muted ? AppColors.textFaint : AppColors.crm),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan.name,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: muted ? AppColors.textFaint : AppColors.text,
                        decoration: muted ? TextDecoration.lineThrough : null,
                      )),
                  if (details.isNotEmpty)
                    Text(details, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  if (plan.note != null)
                    Text(plan.note!, style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: AppColors.crmSoft, borderRadius: BorderRadius.circular(999)),
              child: Text(plan.status.label,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.crm)),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisitRow extends StatelessWidget {
  final ClientVisit visit;
  final VoidCallback onTap;

  const _VisitRow({required this.visit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.handshake_outlined, size: 20, color: AppColors.crm),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('เข้าพบ ${CalendarUtils.thaiDate(visit.date)}',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  if (visit.note != null)
                    Text(visit.note!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  if (visit.gift != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.card_giftcard_rounded, size: 14, color: AppColors.crm),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text('ของขวัญ: ${visit.gift}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.crm)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
