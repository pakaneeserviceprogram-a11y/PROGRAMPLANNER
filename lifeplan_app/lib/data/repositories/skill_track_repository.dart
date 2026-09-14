import 'package:hive_flutter/hive_flutter.dart';

import '../../models/skill_track.dart';
import '../hive_boxes.dart';
import '../hive_repository.dart';

class SkillTrackRepository extends HiveRepository<SkillTrack> {
  SkillTrackRepository()
      : super(
          box: Hive.box<Map>(HiveBoxes.skillTracks),
          fromMap: SkillTrack.fromMap,
          toMap: (t) => t.toMap(),
          idOf: (t) => t.id,
        );
}
