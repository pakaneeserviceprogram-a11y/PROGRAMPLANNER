enum TransactionType { income, expense }

enum ExpenseCategory { food, transport, investmentSaving, other }

extension ExpenseCategoryX on ExpenseCategory {
  String get label => switch (this) {
        ExpenseCategory.food => 'อาหาร',
        ExpenseCategory.transport => 'การเดินทาง',
        ExpenseCategory.investmentSaving => 'ลงทุน / ออม',
        ExpenseCategory.other => 'อื่น ๆ',
      };
}

class FinanceTransaction {
  final String id;
  final String title;
  final DateTime date;
  final double amount;
  final TransactionType type;
  final ExpenseCategory category;

  const FinanceTransaction({
    required this.id,
    required this.title,
    required this.date,
    required this.amount,
    required this.type,
    this.category = ExpenseCategory.other,
  });

  String get dateLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'วันนี้ ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    if (diff == 1) return 'เมื่อวาน';
    return '$diff วันก่อน';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'date': date.toIso8601String(),
        'amount': amount,
        'type': type.name,
        'category': category.name,
      };

  factory FinanceTransaction.fromMap(Map<String, dynamic> map) => FinanceTransaction(
        id: map['id'] as String,
        title: map['title'] as String,
        date: DateTime.parse(map['date'] as String),
        amount: (map['amount'] as num).toDouble(),
        type: TransactionType.values.firstWhere((e) => e.name == map['type'], orElse: () => TransactionType.expense),
        category: ExpenseCategory.values.firstWhere((e) => e.name == map['category'], orElse: () => ExpenseCategory.other),
      );
}

class BudgetCategory {
  final String label;
  final double amount;
  final double percentOfTotal;

  const BudgetCategory({
    required this.label,
    required this.amount,
    required this.percentOfTotal,
  });
}
