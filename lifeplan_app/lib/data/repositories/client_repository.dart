import 'package:hive_flutter/hive_flutter.dart';

import '../../models/client.dart';
import '../hive_boxes.dart';
import '../hive_repository.dart';

class ClientRepository extends HiveRepository<Client> {
  ClientRepository()
      : super(
          box: Hive.box<Map>(HiveBoxes.clients),
          fromMap: Client.fromMap,
          toMap: (t) => t.toMap(),
          idOf: (t) => t.id,
        );
}
