import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/id_gen.dart';
import '../data/repositories/client_repository.dart';
import '../data/repositories/goal_settings_repository.dart';
import '../data/repositories/user_repository.dart';
import '../data/repositories/weekly_report_repository.dart';
import '../models/client.dart';
import '../models/weekly_report.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/back_button_circle.dart';
import '../widgets/form_sheet.dart';
import '../widgets/progress_track.dart';
import '../widgets/section_heading.dart';

class CrmScreen extends StatelessWidget {
  const CrmScreen({super.key});

  Color _avatarColor(ClientStage stage) {
    switch (stage) {
      case ClientStage.followUp:
        return AppColors.crm;
      case ClientStage.proposalSent:
        return AppColors.work;
      case ClientStage.closedWon:
        return AppColors.exercise;
      case ClientStage.newLead:
      case ClientStage.contacted:
        return AppColors.learning;
    }
  }

  String _initialsOf(String name) {
    final clean = name.replaceAll(RegExp('คุณ'), '').trim();
    return clean.isEmpty ? '?' : clean.characters.take(2).toString();
  }

  static String _moneyText(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  /// ฟอร์มเดียวใช้ทั้งเพิ่มลูกค้าใหม่ (existing = null) และแก้ไขลูกค้าเดิม
  ///
  /// ตอนแก้ไขเลือกสถานะได้เอง — แตะที่รายชื่อเลื่อนไปข้างหน้าได้อย่างเดียว ถ้าแตะเกินจะย้อนกลับได้จากที่นี่
  Future<void> _openClientForm(BuildContext context, ClientRepository repo, {Client? existing}) async {
    final nameController = TextEditingController(text: existing?.name);
    final policyController = TextEditingController(text: existing?.policyLabel);
    final premiumController = TextEditingController(
        text: existing != null && existing.premiumAmount > 0 ? _moneyText(existing.premiumAmount) : null);
    ClientStage selectedStage = existing?.stage ?? ClientStage.newLead;

    await showAppFormSheet(
      context: context,
      title: existing == null ? 'เพิ่มลูกค้า' : 'แก้ไขข้อมูลลูกค้า',
      submitLabel: 'บันทึก',
      footerBuilder: existing == null
          ? null
          : (sheetCtx) => FormDeleteButton(
                pageContext: context,
                label: 'ลบลูกค้ารายนี้',
                confirmTitle: 'ลบลูกค้ารายนี้?',
                confirmMessage: '“${existing.name}” จะถูกลบออกจากรายชื่อ (รายงานประจำสัปดาห์ไม่หาย)',
                doneMessage: 'ลบ “${existing.name}” แล้ว',
                onDelete: () => repo.delete(existing.id),
              ),
      bodyBuilder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthField(label: 'ชื่อลูกค้า', hint: 'เช่น คุณสมชาย ใจดี', controller: nameController),
            const SizedBox(height: 14),
            AuthField(
              label: existing == null ? 'ความสนใจ' : 'รายละเอียด',
              hint: 'เช่น ประกันสุขภาพ',
              controller: policyController,
            ),
            if (existing != null) ...[
              const SizedBox(height: 14),
              LabeledDropdown<ClientStage>(
                label: 'สถานะ',
                value: selectedStage,
                options: ClientStage.values,
                display: (s) => s.label,
                onChanged: (v) => setState(() => selectedStage = v!),
              ),
            ],
            const SizedBox(height: 14),
            AuthField(label: 'มูลค่าเบี้ยประกันโดยประมาณ (บาท)', hint: '0', controller: premiumController, keyboardType: TextInputType.number),
          ],
        ),
      ),
      onSubmit: () async {
        final name = nameController.text.trim();
        if (name.isEmpty) return;
        final policy = policyController.text.trim();
        final premium = double.tryParse(premiumController.text.replaceAll(',', '').trim()) ?? 0;
        await repo.put(Client(
          id: existing?.id ?? newId(),
          name: name,
          initials: _initialsOf(name),
          policyLabel: existing == null
              ? '${policy.isEmpty ? 'ลูกค้าใหม่' : policy} • ลูกค้าใหม่'
              : (policy.isEmpty ? existing.policyLabel : policy),
          stage: selectedStage,
          premiumAmount: premium,
        ));
        if (context.mounted) Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ClientRepository();
    final goalsRepo = GoalSettingsRepository();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([repo.listenable(), goalsRepo.listenable()]),
          builder: (context, _) {
            final goals = goalsRepo.get();
            final clients = repo.getAll();
            final newLeads = clients.where((c) => c.stage == ClientStage.newLead).length;
            final appointments = clients.where((c) => c.stage == ClientStage.contacted || c.stage == ClientStage.proposalSent || c.stage == ClientStage.followUp).length;
            final closedWon = clients.where((c) => c.stage == ClientStage.closedWon).toList();
            final achievedPremium = closedWon.fold<double>(0, (sum, c) => sum + c.premiumAmount);
            final progress = (achievedPremium / goals.salesTarget).clamp(0, 1).toDouble();

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                const Row(
                  children: [
                    BackButtonCircle(),
                    SizedBox(width: 12),
                    Expanded(child: Text('ลูกค้า & ขายประกัน', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4))),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.crm, Color(0xFFDB6A1E)],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('เป้าหมายเบี้ยประกันเดือนนี้', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70)),
                      const SizedBox(height: 6),
                      Text.rich(TextSpan(children: [
                        TextSpan(text: '฿${achievedPremium.toStringAsFixed(0)} ', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                        TextSpan(text: '/ ฿${goals.salesTarget.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white70)),
                      ])),
                      const SizedBox(height: 10),
                      ProgressTrack(value: progress, color: Colors.white, trackColor: Colors.white.withValues(alpha: 0.25)),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _CrmStat(value: '$newLeads', label: 'ลูกค้าใหม่'),
                          _CrmStat(value: '$appointments', label: 'นัดหมาย'),
                          _CrmStat(value: '${closedWon.length}', label: 'ปิดการขาย'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const WeeklyReportSection(),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ลูกค้าที่ต้องติดตาม', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    GestureDetector(
                      onTap: () => _openClientForm(context, repo),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10)),
                        alignment: Alignment.center,
                        child: const Icon(Icons.add_rounded, size: 16, color: AppColors.text),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('แตะที่รายชื่อเพื่อเลื่อนสถานะไปขั้นถัดไป • กดรูปดินสอเพื่อแก้ไขหรือลบ', style: TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
                ),
                if (clients.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('ยังไม่มีลูกค้า — กดปุ่ม + เพื่อเพิ่ม', style: TextStyle(fontSize: 12.5, color: AppColors.textFaint)),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        for (int i = 0; i < clients.length; i++) ...[
                          if (i != 0) const Divider(height: 1, color: AppColors.border),
                          _ClientRow(
                            client: clients[i],
                            color: _avatarColor(clients[i].stage),
                            onTap: () => repo.put(clients[i].copyWith(stage: clients[i].stage.next)),
                            onEdit: () => _openClientForm(context, repo, existing: clients[i]),
                          ),
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

class _CrmStat extends StatelessWidget {
  final String value;
  final String label;

  const _CrmStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }
}

class _ClientRow extends StatelessWidget {
  final Client client;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _ClientRow({required this.client, required this.color, required this.onTap, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(client.initials, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(client.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(client.policyLabel, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: AppColors.crmSoft, borderRadius: BorderRadius.circular(999)),
              child: Text(client.statusLabel, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.crm)),
            ),
            const SizedBox(width: 2),
            RowEditButton(onTap: onEdit),
          ],
        ),
      ),
    );
  }
}

/// รายงานผลงานประจำสัปดาห์ P-A-S-R-F-N-T
/// (Prospect • Appointment • Sales • Referal • Follow • New Market • Team)
///
/// ใช้สรุปงานขายของแต่ละสัปดาห์เพื่อส่งให้หัวหน้า และย้อนดูสัปดาห์เก่าเพื่อ
/// ตามความคืบหน้าของตัวเองได้ — ปุ่ม “คัดลอกส่งหัวหน้า” ให้ข้อความพร้อมวางในไลน์
class WeeklyReportSection extends StatefulWidget {
  const WeeklyReportSection({super.key});

  @override
  State<WeeklyReportSection> createState() => _WeeklyReportSectionState();
}

class _WeeklyReportSectionState extends State<WeeklyReportSection> {
  final WeeklyReportRepository _repo = WeeklyReportRepository();

  late DateTime _weekStart = WeeklyReport.startOfWeek(DateTime.now());

  DateTime get _currentWeekStart => WeeklyReport.startOfWeek(DateTime.now());

  /// ไม่ให้เลื่อนไปกรอกรายงานของสัปดาห์ที่ยังมาไม่ถึง
  bool get _canGoForward => _weekStart.isBefore(_currentWeekStart);

  void _shiftWeek(int weeks) =>
      setState(() => _weekStart = _weekStart.add(Duration(days: 7 * weeks)));

  Future<void> _copyToClipboard(WeeklyReport report) async {
    await Clipboard.setData(ClipboardData(text: report.toReportText()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('คัดลอกรายงานแล้ว — วางส่งหัวหน้าได้เลย')),
    );
  }

  Future<void> _openHistory() async {
    final reports = _repo.getAllSorted();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(999)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('รายงานที่บันทึกไว้', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('แตะเพื่อเปิดดูรายงานของสัปดาห์นั้น',
                  style: TextStyle(fontSize: 12, color: AppColors.textFaint)),
              const SizedBox(height: 8),
              if (reports.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('ยังไม่มีรายงานที่บันทึกไว้', style: TextStyle(fontSize: 12.5, color: AppColors.textFaint)),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: reports.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (_, i) {
                      final r = reports[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('สัปดาห์ที่ ${r.weekRangeLabel}',
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          ActivityCode.values.map((c) => '${c.letter} ${r.countOf(c)}').join(' • '),
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          setState(() => _weekStart = r.weekStart);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEditForm(WeeklyReport report) async {
    final fallbackOwner = UserRepository().getCurrent()?.name ?? '';
    final ownerController =
        TextEditingController(text: report.ownerName.isEmpty ? fallbackOwner : report.ownerName);
    final premiumController = TextEditingController(
        text: report.salesPremium > 0 ? report.salesPremium.toStringAsFixed(0) : '');
    final countControllers = {
      for (final c in ActivityCode.values)
        c: TextEditingController(text: report.countOf(c) == 0 ? '' : '${report.countOf(c)}'),
    };
    final noteControllers = {
      for (final c in ActivityCode.values) c: TextEditingController(text: report.noteOf(c)),
    };

    await showAppFormSheet(
      context: context,
      title: 'รายงานสัปดาห์ที่ ${report.weekRangeLabel}',
      submitLabel: 'บันทึกรายงาน',
      bodyBuilder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuthField(label: 'ชื่อที่ขึ้นหัวรายงาน', hint: 'เช่น เอ๋', controller: ownerController),
          const SizedBox(height: 16),
          for (final code in ActivityCode.values) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 78,
                  child: AuthField(
                    label: code.letter,
                    hint: '0',
                    controller: countControllers[code],
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AuthField(
                    label: '${code.label} (${code.englishLabel})',
                    hint: code.noteHint,
                    controller: noteControllers[code],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (code == ActivityCode.sales) ...[
              AuthField(
                label: 'เบี้ยประกันโดยประมาณของ S (บาท)',
                hint: '0',
                controller: premiumController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 14),
            ],
          ],
        ],
      ),
      onSubmit: () async {
        await _repo.put(report.copyWith(
          ownerName: ownerController.text.trim(),
          salesPremium: double.tryParse(premiumController.text.replaceAll(',', '').trim()) ?? 0,
          activities: {
            for (final code in ActivityCode.values)
              code: WeeklyActivity(
                count: int.tryParse(countControllers[code]!.text.trim()) ?? 0,
                note: noteControllers[code]!.text.trim(),
              ),
          },
        ));
        if (mounted) Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _repo.listenable(),
      builder: (context, _) {
        final report = _repo.getForWeek(_weekStart);
        final isCurrentWeek = _weekStart == _currentWeekStart;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeading(
              title: 'รายงานผลงานประจำสัปดาห์',
              action: 'แก้ไข',
              onAction: () => _openEditForm(report),
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'P = Prospect, A = Appointment, S = Sales, R = Referal, F = Follow, N = New Market, T = Team',
                style: TextStyle(fontSize: 11.5, color: AppColors.textFaint, height: 1.5),
              ),
            ),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _WeekArrow(icon: Icons.chevron_left_rounded, onTap: () => _shiftWeek(-1)),
                      Expanded(
                        child: Column(
                          children: [
                            Text('สัปดาห์ที่ ${report.weekRangeLabel}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(
                              report.isBlank
                                  ? (isCurrentWeek ? 'สัปดาห์นี้ • ยังไม่ได้บันทึก' : 'ยังไม่ได้บันทึก')
                                  : (isCurrentWeek ? 'สัปดาห์นี้ • บันทึกแล้ว' : 'บันทึกแล้ว'),
                              style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint),
                            ),
                          ],
                        ),
                      ),
                      _WeekArrow(
                        icon: Icons.chevron_right_rounded,
                        onTap: _canGoForward ? () => _shiftWeek(1) : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const spacing = 8.0;
                      final tileWidth = (constraints.maxWidth - spacing * 3) / 4;
                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          for (final code in ActivityCode.values)
                            SizedBox(
                              width: tileWidth,
                              child: _ActivityTile(code: code, count: report.countOf(code)),
                            ),
                        ],
                      );
                    },
                  ),
                  if (report.salesPremium > 0) ...[
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('เบี้ยประกันโดยประมาณ',
                            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                        Text('฿${WeeklyReport.formatMoney(report.salesPremium)}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.crm)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (report.isBlank)
                    const Text('ยังไม่ได้กรอกรายงานของสัปดาห์นี้ — กด “แก้ไข” เพื่อบันทึก P-A-S-R-F-N-T',
                        style: TextStyle(fontSize: 12, color: AppColors.textFaint, height: 1.5))
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        report.toReportText(),
                        style: const TextStyle(fontSize: 12, color: AppColors.text, height: 1.7),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _copyToClipboard(report),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(color: AppColors.crm, borderRadius: BorderRadius.circular(14)),
                            alignment: Alignment.center,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.copy_rounded, size: 16, color: Colors.white),
                                SizedBox(width: 8),
                                Text('คัดลอกส่งหัวหน้า',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _openHistory,
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          alignment: Alignment.center,
                          child: const Row(
                            children: [
                              Icon(Icons.history_rounded, size: 16, color: AppColors.text),
                              SizedBox(width: 6),
                              Text('ย้อนหลัง',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WeekArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _WeekArrow({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: onTap == null ? AppColors.textFaint : AppColors.text),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final ActivityCode code;
  final int count;

  const _ActivityTile({required this.code, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(color: AppColors.crmSoft, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Text(code.letter,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.crm)),
          const SizedBox(height: 2),
          Text('$count', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text)),
          const SizedBox(height: 2),
          Text(
            code.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
