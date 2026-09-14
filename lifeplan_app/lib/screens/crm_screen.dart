import 'package:flutter/material.dart';

import '../data/id_gen.dart';
import '../data/repositories/client_repository.dart';
import '../data/targets.dart';
import '../models/client.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/back_button_circle.dart';
import '../widgets/form_sheet.dart';
import '../widgets/progress_track.dart';

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

  Future<void> _openAddForm(BuildContext context, ClientRepository repo) async {
    final nameController = TextEditingController();
    final policyController = TextEditingController();
    final premiumController = TextEditingController();

    await showAppFormSheet(
      context: context,
      title: 'เพิ่มลูกค้า',
      submitLabel: 'บันทึก',
      bodyBuilder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuthField(label: 'ชื่อลูกค้า', hint: 'เช่น คุณสมชาย ใจดี', controller: nameController),
          const SizedBox(height: 14),
          AuthField(label: 'ความสนใจ', hint: 'เช่น ประกันสุขภาพ', controller: policyController),
          const SizedBox(height: 14),
          AuthField(label: 'มูลค่าเบี้ยประกันโดยประมาณ (บาท)', hint: '0', controller: premiumController, keyboardType: TextInputType.number),
        ],
      ),
      onSubmit: () async {
        final name = nameController.text.trim();
        if (name.isEmpty) return;
        await repo.put(Client(
          id: newId(),
          name: name,
          initials: _initialsOf(name),
          policyLabel: '${policyController.text.trim().isEmpty ? 'ลูกค้าใหม่' : policyController.text.trim()} • ลูกค้าใหม่',
          stage: ClientStage.newLead,
          premiumAmount: double.tryParse(premiumController.text.trim()) ?? 0,
        ));
        if (context.mounted) Navigator.of(context).pop();
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
          builder: (context, _, _) {
            final clients = repo.getAll();
            final newLeads = clients.where((c) => c.stage == ClientStage.newLead).length;
            final appointments = clients.where((c) => c.stage == ClientStage.contacted || c.stage == ClientStage.proposalSent || c.stage == ClientStage.followUp).length;
            final closedWon = clients.where((c) => c.stage == ClientStage.closedWon).toList();
            final achievedPremium = closedWon.fold<double>(0, (sum, c) => sum + c.premiumAmount);
            final progress = (achievedPremium / kSalesTarget).clamp(0, 1).toDouble();

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
                        TextSpan(text: '/ ฿${kSalesTarget.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white70)),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ลูกค้าที่ต้องติดตาม', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    GestureDetector(
                      onTap: () => _openAddForm(context, repo),
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
                  child: Text('แตะที่รายชื่อเพื่อเลื่อนสถานะไปขั้นถัดไป', style: TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
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

  const _ClientRow({required this.client, required this.color, required this.onTap});

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
          ],
        ),
      ),
    );
  }
}
