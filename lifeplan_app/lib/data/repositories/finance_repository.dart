import 'package:hive_flutter/hive_flutter.dart';

import '../../models/finance_transaction.dart';
import '../hive_boxes.dart';
import '../hive_repository.dart';

class FinanceRepository extends HiveRepository<FinanceTransaction> {
  FinanceRepository()
      : super(
          box: Hive.box<Map>(HiveBoxes.financeTransactions),
          fromMap: FinanceTransaction.fromMap,
          toMap: (t) => t.toMap(),
          idOf: (t) => t.id,
        );
}
