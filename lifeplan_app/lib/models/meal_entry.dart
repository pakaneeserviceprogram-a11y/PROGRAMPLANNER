/// มื้ออาหารหนึ่งรายการ พร้อมคุณค่าทางโภชนาการที่ผู้ใช้บันทึกเอง
/// (แคลอรี่ • โปรตีน • แป้ง/คาร์โบไฮเดรต • ไขมัน • น้ำตาล • วิตามิน)
enum MealType { breakfast, lunch, dinner, snack }

/// ความสัมพันธ์ของมื้อนี้กับการออกกำลังกาย — ใช้แนะนำ "เวลา" ที่ควรกิน
enum WorkoutTiming { none, preWorkout, postWorkout }

/// วิตามินหลักที่ติดตามได้ในแต่ละมื้อ
enum Vitamin { a, b, c, d, e, k }

extension MealTypeX on MealType {
  String get label => switch (this) {
        MealType.breakfast => 'มื้อเช้า',
        MealType.lunch => 'มื้อกลางวัน',
        MealType.dinner => 'มื้อเย็น',
        MealType.snack => 'ของว่าง',
      };
}

extension WorkoutTimingX on WorkoutTiming {
  String get label => switch (this) {
        WorkoutTiming.none => 'ไม่เกี่ยวกับการออกกำลังกาย',
        WorkoutTiming.preWorkout => 'ก่อนออกกำลังกาย',
        WorkoutTiming.postWorkout => 'หลังออกกำลังกาย',
      };

  String get shortLabel => switch (this) {
        WorkoutTiming.none => '-',
        WorkoutTiming.preWorkout => 'ก่อนออก',
        WorkoutTiming.postWorkout => 'หลังออก',
      };
}

extension VitaminX on Vitamin {
  String get label => switch (this) {
        Vitamin.a => 'A',
        Vitamin.b => 'B',
        Vitamin.c => 'C',
        Vitamin.d => 'D',
        Vitamin.e => 'E',
        Vitamin.k => 'K',
      };

  /// แหล่งอาหารตัวอย่าง — โชว์ใต้ชิปวิตามินที่ยังขาดในวันนี้
  String get sourceHint => switch (this) {
        Vitamin.a => 'ฟักทอง แครอท ตับ',
        Vitamin.b => 'ข้าวกล้อง ไข่ ถั่ว',
        Vitamin.c => 'ส้ม ฝรั่ง พริกหวาน',
        Vitamin.d => 'ปลาทะเล ไข่แดง แดดเช้า',
        Vitamin.e => 'อัลมอนด์ น้ำมันมะกอก',
        Vitamin.k => 'ผักใบเขียว บรอกโคลี',
      };
}

class MealEntry {
  final String id;
  final String title;
  final MealType type;

  /// "HH:mm" เติมศูนย์ข้างหน้า เพื่อให้เรียงสตริง = เรียงเวลา
  final String time;

  /// วันของมื้อนี้ (ตัดเวลาออกให้เหลือแค่ปี-เดือน-วัน)
  final DateTime date;

  final int calories;
  final double proteinGrams;
  final double carbGrams;
  final double fatGrams;
  final double sugarGrams;
  final List<Vitamin> vitamins;
  final WorkoutTiming workoutTiming;

  MealEntry({
    required this.id,
    required this.title,
    required this.type,
    required this.time,
    required DateTime date,
    this.calories = 0,
    this.proteinGrams = 0,
    this.carbGrams = 0,
    this.fatGrams = 0,
    this.sugarGrams = 0,
    this.vitamins = const [],
    this.workoutTiming = WorkoutTiming.none,
  }) : date = DateTime(date.year, date.month, date.day);

  /// คีย์วันแบบ yyyy-MM-dd ใช้จับคู่มื้ออาหารกับบันทึกการดื่มน้ำของวันเดียวกัน
  static String dateKeyOf(DateTime date) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  String get dateKey => dateKeyOf(date);

  bool isOnDay(DateTime day) => dateKey == dateKeyOf(day);

  MealEntry copyWith({
    String? title,
    MealType? type,
    String? time,
    DateTime? date,
    int? calories,
    double? proteinGrams,
    double? carbGrams,
    double? fatGrams,
    double? sugarGrams,
    List<Vitamin>? vitamins,
    WorkoutTiming? workoutTiming,
  }) =>
      MealEntry(
        id: id,
        title: title ?? this.title,
        type: type ?? this.type,
        time: time ?? this.time,
        date: date ?? this.date,
        calories: calories ?? this.calories,
        proteinGrams: proteinGrams ?? this.proteinGrams,
        carbGrams: carbGrams ?? this.carbGrams,
        fatGrams: fatGrams ?? this.fatGrams,
        sugarGrams: sugarGrams ?? this.sugarGrams,
        vitamins: vitamins ?? this.vitamins,
        workoutTiming: workoutTiming ?? this.workoutTiming,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'type': type.name,
        'time': time,
        'date': date.toIso8601String(),
        'calories': calories,
        'proteinGrams': proteinGrams,
        'carbGrams': carbGrams,
        'fatGrams': fatGrams,
        'sugarGrams': sugarGrams,
        'vitamins': vitamins.map((v) => v.name).toList(),
        'workoutTiming': workoutTiming.name,
      };

  factory MealEntry.fromMap(Map<String, dynamic> map) => MealEntry(
        id: map['id'] as String,
        title: map['title'] as String,
        type: MealType.values.firstWhere((e) => e.name == map['type'], orElse: () => MealType.snack),
        time: map['time'] as String? ?? '00:00',
        date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
        calories: (map['calories'] as num?)?.toInt() ?? 0,
        proteinGrams: (map['proteinGrams'] as num?)?.toDouble() ?? 0,
        carbGrams: (map['carbGrams'] as num?)?.toDouble() ?? 0,
        fatGrams: (map['fatGrams'] as num?)?.toDouble() ?? 0,
        sugarGrams: (map['sugarGrams'] as num?)?.toDouble() ?? 0,
        vitamins: ((map['vitamins'] as List?) ?? const [])
            .expand<Vitamin>((name) => Vitamin.values.where((v) => v.name == name))
            .toList(),
        workoutTiming: WorkoutTiming.values
            .firstWhere((e) => e.name == map['workoutTiming'], orElse: () => WorkoutTiming.none),
      );
}

/// ผลรวมคุณค่าทางโภชนาการของมื้ออาหารกลุ่มหนึ่ง (ปกติคือทั้งวัน)
class NutritionTotals {
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double sugar;
  final Set<Vitamin> vitamins;
  final int mealCount;

  const NutritionTotals({
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.sugar = 0,
    this.vitamins = const {},
    this.mealCount = 0,
  });

  factory NutritionTotals.of(Iterable<MealEntry> meals) {
    var calories = 0;
    var protein = 0.0, carbs = 0.0, fat = 0.0, sugar = 0.0;
    final vitamins = <Vitamin>{};
    var count = 0;

    for (final m in meals) {
      calories += m.calories;
      protein += m.proteinGrams;
      carbs += m.carbGrams;
      fat += m.fatGrams;
      sugar += m.sugarGrams;
      vitamins.addAll(m.vitamins);
      count++;
    }

    return NutritionTotals(
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      sugar: sugar,
      vitamins: vitamins,
      mealCount: count,
    );
  }

  /// วิตามินที่ยังไม่ได้รับเลยในกลุ่มนี้
  List<Vitamin> get missingVitamins => Vitamin.values.where((v) => !vitamins.contains(v)).toList();

  bool get isEmpty => mealCount == 0;
}
