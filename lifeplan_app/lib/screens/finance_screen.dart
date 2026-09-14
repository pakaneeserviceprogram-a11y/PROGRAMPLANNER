import 'package:flutter/material.dart';

import '../data/id_gen.dart';
import '../data/repositories/finance_repository.dart';
import '../data/targets.dart';
import '../models/finance_transaction.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/back_button_circle.dart';
import '../widgets/form_sheet.dart';
import '../widgets/progress_track.dart';
import '../widgets/section_heading.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  Future<void> _openAddForm(BuildContext context, FinanceRepository repo) async {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    TransactionType selectedType = TransactionType.expense;
    ExpenseCategory selectedCategory = ExpenseCategory.other;

    await showAppFormSheet(
      context: context,
      title: 'เพิ่มรายการ',
      submitLabel: 'บันทึก',
      bodyBuilder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LabeledDropdown<TransactionType>(
              label: 'ประเภท',
              value: selectedType,
              options: TransactionType.values,
              display: (t) => t == TransactionType.income ? 'รายรับ' : 'รายจ่าย',
              onChanged: (v) => setState(() => selectedType = v!),
            ),
            const SizedBox(height: 14),
            AuthField(label: 'รายการ', hint: 'เช่น ข้าวกลางวัน', controller: titleController),
            const SizedBox(height: 14),
            AuthField(label: 'จำนวนเงิน (บาท)', hint: '0', controller: amountController, keyboardType: TextInputType.number),
            if (selectedType == TransactionType.expense) ...[
              const SizedBox(height: 14),
              LabeledDropdown<ExpenseCategory>(
                label: 'หมวดหมู่',
                value: selectedCategory,
                options: ExpenseCategory.values,
                display: (c) => c.label,
                onChanged: (v) => setState(() => selectedCategory = v!),
              ),
            ],
          ],
        ),
      ),
      onSubmit: () async {
        final title = titleController.text.trim();
        final amount = double.tryParse(amountController.text.trim()) ?? 0;
        if (title.isEmpty || amount <= 0) return;
        await repo.put(FinanceTransaction(
          id: newId(),
          title: title,
          date: DateTime.now(),
          amount: amount,
          type: selectedType,
          category: selectedCategory,
        ));
        if (context.mounted) Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = FinanceRepository();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: repo.listenable(),
          builder: (context, _, _) {
            final txs = repo.getAll()..sort((a, b) => b.date.compareTo(a.date));
            final income = txs.where((t) => t.type == TransactionType.income).fold<double>(0, (s, t) => s + t.amount);
            final expense = txs.where((t) => t.type == TransactionType.expense).fold<double>(0, (s, t) => s + t.amount);
            final savingsCurrent = txs
                .where((t) => t.type == TransactionType.expense && t.category == ExpenseCategory.investmentSaving)
                .fold<double>(0, (s, t) => s + t.amount);
            final savingsProgress = (savingsCurrent / kSavingTarget).clamp(0, 1).toDouble();
            final remaining = (kSavingTarget - savingsCurrent).clamp(0, kSavingTarget);

            final expenseTxs = txs.where((t) => t.type == TransactionType.expense).toList();
            final byCategory = <ExpenseCategory, double>{};
            for (final t in expenseTxs) {
              byCategory[t.category] = (byCategory[t.category] ?? 0) + t.amount;
            }
            final totalExpenseForBreakdown = byCategory.values.fold<double>(0, (s, v) => s + v);

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Row(
                  children: [
                    const BackButtonCircle(),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('การเงิน', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4))),
                    GestureDetector(
                      onTap: () => _openAddForm(context, repo),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
                        alignment: Alignment.center,
                        child: const Icon(Icons.add_rounded, size: 20, color: AppColors.text),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: AppCard(
                        padding: const EdgeInsets.all(15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('รายรับทั้งหมด', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                            const SizedBox(height: 6),
                            Text('฿${income.toStringAsFixed(0)}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF2E8B4E))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppCard(
                        padding: const EdgeInsets.all(15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('รายจ่ายทั้งหมด', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                            const SizedBox(height: 6),
                            Text('฿${expense.toStringAsFixed(0)}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFFC0432A))),
                          ],
                        ),
                      ),
                    ),
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
                      colors: [AppColors.finance, Color(0xFF1F6C7C)],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('เป้าหมายออม', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70)),
                      const SizedBox(height: 6),
                      Text.rich(TextSpan(children: [
                        TextSpan(text: '฿${savingsCurrent.toStringAsFixed(0)} ', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                        TextSpan(text: '/ ฿${kSavingTarget.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white70)),
                      ])),
                      const SizedBox(height: 10),
                      ProgressTrack(value: savingsProgress, color: Colors.white, trackColor: Colors.white.withValues(alpha: 0.25)),
                      const SizedBox(height: 10),
                      Text(
                        remaining <= 0 ? 'ถึงเป้าหมายแล้ว 🎉' : 'เหลืออีก ฿${remaining.toStringAsFixed(0)} เพื่อให้ถึงเป้าหมาย',
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeading(title: 'สัดส่วนค่าใช้จ่าย'),
                      const SizedBox(height: 12),
                      if (byCategory.isEmpty)
                        const Text('ยังไม่มีรายการรายจ่าย', style: TextStyle(fontSize: 12.5, color: AppColors.textFaint))
                      else
                        for (final entry in byCategory.entries) ...[
                          _BudgetRow(
                            label: entry.key.label,
                            amount: entry.value,
                            percent: totalExpenseForBreakdown == 0 ? 0 : entry.value / totalExpenseForBreakdown,
                            color: _categoryColor(entry.key),
                          ),
                          if (entry.key != byCategory.keys.last) const SizedBox(height: 12),
                        ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeading(title: 'รายการล่าสุด'),
                      const SizedBox(height: 6),
                      if (txs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('ยังไม่มีรายการ — กดปุ่ม + เพื่อเพิ่ม', style: TextStyle(fontSize: 12.5, color: AppColors.textFaint)),
                        )
                      else
                        for (final t in txs.take(10)) ...[
                          const Divider(height: 24, color: AppColors.border),
                          _TransactionRow(tx: t),
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

  Color _categoryColor(ExpenseCategory c) => switch (c) {
        ExpenseCategory.food => AppColors.crm,
        ExpenseCategory.transport => AppColors.work,
        ExpenseCategory.investmentSaving => AppColors.finance,
        ExpenseCategory.other => AppColors.textFaint,
      };
}

class _BudgetRow extends StatelessWidget {
  final String label;
  final double amount;
  final double percent;
  final Color color;

  const _BudgetRow({required this.label, required this.amount, required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text('฿${amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
          ],
        ),
        const SizedBox(height: 6),
        ProgressTrack(value: percent, color: color),
      ],
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final FinanceTransaction tx;

  const _TransactionRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isIncome = tx.type == TransactionType.income;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isIncome ? AppColors.exerciseSoft : AppColors.crmSoft,
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: Icon(
            isIncome ? Icons.trending_up_rounded : Icons.receipt_long_rounded,
            size: 17,
            color: isIncome ? AppColors.exercise : AppColors.crm,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tx.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(tx.dateLabel, style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
            ],
          ),
        ),
        Text(
          '${isIncome ? '+' : '-'}฿${tx.amount.toStringAsFixed(0)}',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isIncome ? const Color(0xFF2E8B4E) : const Color(0xFFC0432A)),
        ),
      ],
    );
  }
}
