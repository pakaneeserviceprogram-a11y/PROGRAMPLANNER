/// ยาแบ่งเป็นสองประเภทตามวิธีใช้จริง — คนละเรื่องกันทั้งความเคร่งของเวลาและความเสี่ยงถ้าลืม
enum MedicationKind {
  /// วิตามิน/อาหารเสริม/ยาบำรุง — ลืมบ้างไม่เป็นไรมาก
  supplement,

  /// ยารักษาโรค — ต้องกินตรงเวลา ลืมแล้วมีผลต่อการรักษา
  treatment,
}

/// ความสัมพันธ์กับมื้ออาหาร — บนฉลากยาไทยเขียนไว้เกือบทุกตัว
enum DoseTiming { beforeMeal, afterMeal, withMeal, bedtime, anytime }

extension MedicationKindX on MedicationKind {
  String get label => switch (this) {
        MedicationKind.supplement => 'วิตามิน / ยาบำรุง',
        MedicationKind.treatment => 'ยารักษาโรค',
      };

  String get shortLabel => switch (this) {
        MedicationKind.supplement => 'บำรุง',
        MedicationKind.treatment => 'รักษาโรค',
      };
}

extension DoseTimingX on DoseTiming {
  String get label => switch (this) {
        DoseTiming.beforeMeal => 'ก่อนอาหาร',
        DoseTiming.afterMeal => 'หลังอาหาร',
        DoseTiming.withMeal => 'พร้อมอาหาร',
        DoseTiming.bedtime => 'ก่อนนอน',
        DoseTiming.anytime => 'เวลาใดก็ได้',
      };
}

/// ตัวยา/สารสำคัญหนึ่งตัวบนฉลาก เช่น "Paracetamol 500 mg"
class MedIngredient {
  final String name;

  /// ปริมาณพร้อมหน่วยตามที่อยู่บนฉลาก เช่น "500 mg" (null = ฉลากไม่ได้ระบุ/อ่านไม่ออก)
  final String? strength;

  const MedIngredient({required this.name, this.strength});

  String get label => strength == null ? name : '$name $strength';

  Map<String, dynamic> toMap() => {'name': name, 'strength': strength};

  factory MedIngredient.fromMap(Map<String, dynamic> map) => MedIngredient(
        name: map['name'] as String? ?? '',
        strength: map['strength'] as String?,
      );
}

/// ยาหนึ่งรายการที่ผู้ใช้บันทึกไว้เอง
///
/// **ข้อมูลทั้งหมดมาจากผู้ใช้** (พิมพ์เอง หรือสแกนจากกล่องยาของตัวเอง)
/// แอปไม่ได้แนะนำยา ไม่ได้ตรวจปฏิกิริยาระหว่างยา และไม่ได้คำนวณขนาดยาให้
class Medication {
  final String id;
  final String name;

  /// ยี่ห้อ/ชื่อการค้า ถ้าต่างจากชื่อที่เรียก (null = ไม่ได้ระบุ)
  final String? brand;

  final MedicationKind kind;

  /// โรค/อาการที่กินยานี้ — ใช้กับยารักษาโรค เช่น "ความดันโลหิตสูง"
  /// (วิตามินปล่อยว่างได้ หรือใส่เป้าหมาย เช่น "บำรุงกระดูก")
  final String? conditionLabel;

  final List<MedIngredient> ingredients;

  /// ขนาดที่กินต่อครั้ง ตามที่ฉลากเขียน เช่น "1 เม็ด"
  final String dose;

  /// เวลาที่ต้องกินในหนึ่งวัน "HH:mm" (เรียงแล้ว) — ว่าง = ยังไม่ตั้งเตือน
  final List<String> times;

  final DoseTiming timing;
  final String? note;

  /// ปิดชั่วคราวโดยไม่ต้องลบ (เช่น ยาที่กินเป็นคอร์สแล้วจบไปแล้ว)
  final bool active;

  const Medication({
    required this.id,
    required this.name,
    this.brand,
    required this.kind,
    this.conditionLabel,
    this.ingredients = const [],
    this.dose = '1 เม็ด',
    this.times = const [],
    this.timing = DoseTiming.afterMeal,
    this.note,
    this.active = true,
  });

  /// จำนวนครั้งที่ต้องกินต่อวัน
  int get dosesPerDay => times.length;

  String get ingredientSummary => ingredients.map((i) => i.label).join(' • ');

  Medication copyWith({
    String? name,
    String? brand,
    MedicationKind? kind,
    String? conditionLabel,
    List<MedIngredient>? ingredients,
    String? dose,
    List<String>? times,
    DoseTiming? timing,
    String? note,
    bool? active,
  }) =>
      Medication(
        id: id,
        name: name ?? this.name,
        brand: brand ?? this.brand,
        kind: kind ?? this.kind,
        conditionLabel: conditionLabel ?? this.conditionLabel,
        ingredients: ingredients ?? this.ingredients,
        dose: dose ?? this.dose,
        times: times ?? this.times,
        timing: timing ?? this.timing,
        note: note ?? this.note,
        active: active ?? this.active,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'brand': brand,
        'kind': kind.name,
        'conditionLabel': conditionLabel,
        'ingredients': ingredients.map((i) => i.toMap()).toList(),
        'dose': dose,
        'times': times,
        'timing': timing.name,
        'note': note,
        'active': active,
      };

  factory Medication.fromMap(Map<String, dynamic> map) => Medication(
        id: map['id'] as String,
        name: map['name'] as String,
        brand: map['brand'] as String?,
        kind: MedicationKind.values.firstWhere(
          (e) => e.name == map['kind'],
          orElse: () => MedicationKind.supplement,
        ),
        conditionLabel: map['conditionLabel'] as String?,
        ingredients: ((map['ingredients'] as List?) ?? const [])
            .map((e) => MedIngredient.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        dose: map['dose'] as String? ?? '1 เม็ด',
        times: ((map['times'] as List?) ?? const []).map((e) => '$e').toList(),
        timing: DoseTiming.values.firstWhere(
          (e) => e.name == map['timing'],
          orElse: () => DoseTiming.afterMeal,
        ),
        note: map['note'] as String?,
        active: map['active'] as bool? ?? true,
      );
}
