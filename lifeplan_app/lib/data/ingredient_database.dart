import '../models/meal_entry.dart';

/// หมวดวัตถุดิบ ใช้จัดกลุ่มในหน้าเลือก
enum IngredientGroup { meat, seafood, egg, dairy, vegetable, fruit, grain, fat, other }

extension IngredientGroupX on IngredientGroup {
  String get label => switch (this) {
        IngredientGroup.meat => 'เนื้อสัตว์',
        IngredientGroup.seafood => 'อาหารทะเล/ปลา',
        IngredientGroup.egg => 'ไข่',
        IngredientGroup.dairy => 'นม/ชีส',
        IngredientGroup.vegetable => 'ผัก',
        IngredientGroup.fruit => 'ผลไม้',
        IngredientGroup.grain => 'ข้าว/แป้ง',
        IngredientGroup.fat => 'น้ำมัน/ถั่ว',
        IngredientGroup.other => 'อื่น ๆ',
      };
}

/// วัตถุดิบหนึ่งอย่าง — **ค่าทั้งหมดต่อ 100 กรัมของส่วนที่กินได้**
class Ingredient {
  final String name;
  final IngredientGroup group;

  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double sugar;

  /// วิตามินที่วัตถุดิบนี้ให้ — เก็บเป็น **% ของที่ควรได้ต่อวันต่อ 100 ก.**
  /// ใส่เฉพาะตัวที่ให้ตั้งแต่ราว 10% ขึ้นไป (ต่ำกว่านั้นไม่มีผลในทางปฏิบัติ)
  final Map<Vitamin, double> vitaminPercent;

  /// หน่วยที่คนไทยใช้จริง เช่น "1 ฟอง ≈ 50 ก." — ไว้ช่วยกะปริมาณ
  final String? unitHint;

  /// น้ำหนักของ 1 หน่วยข้างต้น (กรัม) — null = ไม่มีหน่วยนับ
  final double? unitGrams;

  const Ingredient({
    required this.name,
    required this.group,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.sugar = 0,
    this.vitaminPercent = const {},
    this.unitHint,
    this.unitGrams,
  });
}

/// ตารางคุณค่าวัตถุดิบที่ฝังมากับแอป
///
/// **ที่มาและข้อจำกัดของตัวเลข**
/// - เป็นค่าประมาณต่อ 100 ก. อิงค่ากลางจากตารางคุณค่าอาหารมาตรฐาน (แนว USDA FoodData Central
///   ซึ่งเป็นข้อมูลสาธารณสมบัติ) ปัดให้จำง่าย
/// - ของจริงแกว่งตามสายพันธุ์ ส่วนของเนื้อ วิธีปรุง และปริมาณน้ำที่เสียไปตอนทำให้สุก
///   (เช่น อกไก่ดิบ 100 ก. เมื่อย่างแล้วเหลือราว 70 ก. แต่โปรตีนเท่าเดิม)
/// - **ไม่ใช่ข้อมูลทางการแพทย์** ผู้ที่ต้องคุมสารอาหารเคร่งครัดควรใช้ค่าจากนักกำหนดอาหาร
///
/// **ถ้าจะต่อฐานข้อมูลจริงภายหลัง**: ทำ implementation ใหม่ที่ยิง USDA FoodData Central API
/// (ต้องสมัคร API key ฟรี) แล้วให้หน้าจอค้นผ่านตัวกลางแทน `search` — โครงตรงนี้ไม่ต้องแก้
class IngredientDatabase {
  IngredientDatabase._();

  static const items = <Ingredient>[
    // ---------- เนื้อสัตว์ (ดิบ ส่วนที่กินได้) ----------
    Ingredient(
      name: 'อกไก่ไม่มีหนัง',
      group: IngredientGroup.meat,
      calories: 120, protein: 23, carbs: 0, fat: 2.6,
      vitaminPercent: {Vitamin.b: 40},
      unitHint: '1 ชิ้นกลาง ≈ 120 ก.', unitGrams: 120,
    ),
    Ingredient(
      name: 'สะโพกไก่ติดหนัง',
      group: IngredientGroup.meat,
      calories: 215, protein: 18, carbs: 0, fat: 15,
      vitaminPercent: {Vitamin.b: 25},
      unitHint: '1 ชิ้น ≈ 100 ก.', unitGrams: 100,
    ),
    Ingredient(
      name: 'น่องไก่',
      group: IngredientGroup.meat,
      calories: 172, protein: 18, carbs: 0, fat: 10,
      vitaminPercent: {Vitamin.b: 25},
      unitHint: '1 น่อง ≈ 90 ก.', unitGrams: 90,
    ),
    Ingredient(
      name: 'เนื้อวัวสันใน',
      group: IngredientGroup.meat,
      calories: 150, protein: 22, carbs: 0, fat: 6.5,
      vitaminPercent: {Vitamin.b: 45},
    ),
    Ingredient(
      name: 'เนื้อวัวติดมัน (สไลซ์)',
      group: IngredientGroup.meat,
      calories: 250, protein: 19, carbs: 0, fat: 19,
      vitaminPercent: {Vitamin.b: 35},
    ),
    Ingredient(
      name: 'หมูสันนอก',
      group: IngredientGroup.meat,
      calories: 145, protein: 21, carbs: 0, fat: 6,
      vitaminPercent: {Vitamin.b: 55},
    ),
    Ingredient(
      name: 'หมูสับ (ติดมันปานกลาง)',
      group: IngredientGroup.meat,
      calories: 260, protein: 17, carbs: 0, fat: 21,
      vitaminPercent: {Vitamin.b: 35},
    ),
    Ingredient(
      name: 'หมูสามชั้น',
      group: IngredientGroup.meat,
      calories: 395, protein: 14, carbs: 0, fat: 37,
      vitaminPercent: {Vitamin.b: 25},
    ),
    Ingredient(
      name: 'ตับหมู',
      group: IngredientGroup.meat,
      calories: 134, protein: 21, carbs: 2.5, fat: 3.7,
      vitaminPercent: {Vitamin.a: 600, Vitamin.b: 200, Vitamin.c: 25},
    ),

    // ---------- ปลา/ทะเล ----------
    Ingredient(
      name: 'ปลาทู',
      group: IngredientGroup.seafood,
      calories: 160, protein: 22, carbs: 0, fat: 7.5,
      vitaminPercent: {Vitamin.d: 60, Vitamin.b: 40},
      unitHint: '1 ตัว ≈ 80 ก.', unitGrams: 80,
    ),
    Ingredient(
      name: 'ปลาแซลมอน',
      group: IngredientGroup.seafood,
      calories: 208, protein: 20, carbs: 0, fat: 13,
      vitaminPercent: {Vitamin.d: 110, Vitamin.b: 50, Vitamin.e: 25},
    ),
    Ingredient(
      name: 'ปลานิล',
      group: IngredientGroup.seafood,
      calories: 96, protein: 20, carbs: 0, fat: 1.7,
      vitaminPercent: {Vitamin.b: 30, Vitamin.d: 15},
    ),
    Ingredient(
      name: 'ปลากะพง',
      group: IngredientGroup.seafood,
      calories: 97, protein: 20, carbs: 0, fat: 2,
      vitaminPercent: {Vitamin.b: 25, Vitamin.d: 20},
    ),
    Ingredient(
      name: 'กุ้งขาว',
      group: IngredientGroup.seafood,
      calories: 85, protein: 20, carbs: 0, fat: 0.5,
      vitaminPercent: {Vitamin.b: 20, Vitamin.e: 15},
    ),
    Ingredient(
      name: 'ปลาหมึกกล้วย',
      group: IngredientGroup.seafood,
      calories: 92, protein: 16, carbs: 3, fat: 1.4,
      vitaminPercent: {Vitamin.b: 20},
    ),
    Ingredient(
      name: 'ปลาทูน่าในน้ำเกลือ',
      group: IngredientGroup.seafood,
      calories: 116, protein: 26, carbs: 0, fat: 1,
      vitaminPercent: {Vitamin.b: 45, Vitamin.d: 20},
      unitHint: '1 กระป๋อง ≈ 165 ก.', unitGrams: 165,
    ),

    // ---------- ไข่ / นม ----------
    Ingredient(
      name: 'ไข่ไก่',
      group: IngredientGroup.egg,
      calories: 143, protein: 12.6, carbs: 0.7, fat: 9.5,
      vitaminPercent: {Vitamin.a: 20, Vitamin.b: 45, Vitamin.d: 20, Vitamin.e: 10},
      unitHint: '1 ฟอง ≈ 50 ก.', unitGrams: 50,
    ),
    Ingredient(
      name: 'ไข่เป็ด',
      group: IngredientGroup.egg,
      calories: 185, protein: 13, carbs: 1.5, fat: 14,
      vitaminPercent: {Vitamin.a: 25, Vitamin.b: 60, Vitamin.d: 30},
      unitHint: '1 ฟอง ≈ 70 ก.', unitGrams: 70,
    ),
    Ingredient(
      name: 'ไข่ขาว',
      group: IngredientGroup.egg,
      calories: 52, protein: 11, carbs: 0.7, fat: 0.2,
      vitaminPercent: {Vitamin.b: 15},
      unitHint: 'ไข่ 1 ฟองให้ไข่ขาว ≈ 33 ก.', unitGrams: 33,
    ),
    Ingredient(
      name: 'นมสดรสจืด',
      group: IngredientGroup.dairy,
      calories: 61, protein: 3.2, carbs: 4.8, fat: 3.3, sugar: 4.8,
      vitaminPercent: {Vitamin.a: 10, Vitamin.b: 20, Vitamin.d: 15},
      unitHint: '1 กล่อง ≈ 250 ก.', unitGrams: 250,
    ),
    Ingredient(
      name: 'โยเกิร์ตรสธรรมชาติ',
      group: IngredientGroup.dairy,
      calories: 61, protein: 3.5, carbs: 4.7, fat: 3.3, sugar: 4.7,
      vitaminPercent: {Vitamin.b: 25, Vitamin.d: 10},
      unitHint: '1 ถ้วย ≈ 150 ก.', unitGrams: 150,
    ),
    Ingredient(
      name: 'ชีสเชดดาร์',
      group: IngredientGroup.dairy,
      calories: 403, protein: 25, carbs: 1.3, fat: 33, sugar: 0.5,
      vitaminPercent: {Vitamin.a: 25, Vitamin.b: 30, Vitamin.d: 10},
      unitHint: '1 แผ่น ≈ 20 ก.', unitGrams: 20,
    ),
    Ingredient(
      name: 'เต้าหู้ขาวอ่อน',
      group: IngredientGroup.other,
      calories: 76, protein: 8, carbs: 1.9, fat: 4.8,
      vitaminPercent: {Vitamin.b: 10, Vitamin.k: 10},
    ),

    // ---------- ผัก ----------
    Ingredient(
      name: 'มะเขือเทศ',
      group: IngredientGroup.vegetable,
      calories: 18, protein: 0.9, carbs: 3.9, fat: 0.2, sugar: 2.6,
      vitaminPercent: {Vitamin.a: 20, Vitamin.c: 25, Vitamin.k: 10, Vitamin.e: 10},
      unitHint: '1 ลูกกลาง ≈ 120 ก.', unitGrams: 120,
    ),
    Ingredient(
      name: 'แครอท',
      group: IngredientGroup.vegetable,
      calories: 41, protein: 0.9, carbs: 9.6, fat: 0.2, sugar: 4.7,
      vitaminPercent: {Vitamin.a: 180, Vitamin.k: 15, Vitamin.c: 10},
    ),
    Ingredient(
      name: 'บรอกโคลี',
      group: IngredientGroup.vegetable,
      calories: 34, protein: 2.8, carbs: 6.6, fat: 0.4, sugar: 1.7,
      vitaminPercent: {Vitamin.c: 150, Vitamin.k: 130, Vitamin.a: 12},
    ),
    Ingredient(
      name: 'คะน้า',
      group: IngredientGroup.vegetable,
      calories: 35, protein: 2.5, carbs: 5.5, fat: 0.5, sugar: 1.3,
      vitaminPercent: {Vitamin.c: 110, Vitamin.k: 250, Vitamin.a: 50},
    ),
    Ingredient(
      name: 'ผักบุ้ง',
      group: IngredientGroup.vegetable,
      calories: 19, protein: 2.6, carbs: 3.1, fat: 0.2,
      vitaminPercent: {Vitamin.a: 60, Vitamin.c: 60, Vitamin.k: 30},
    ),
    Ingredient(
      name: 'ฟักทอง',
      group: IngredientGroup.vegetable,
      calories: 26, protein: 1, carbs: 6.5, fat: 0.1, sugar: 2.8,
      vitaminPercent: {Vitamin.a: 100, Vitamin.c: 15, Vitamin.e: 10},
    ),
    Ingredient(
      name: 'พริกหวาน',
      group: IngredientGroup.vegetable,
      calories: 31, protein: 1, carbs: 6, fat: 0.3, sugar: 4.2,
      vitaminPercent: {Vitamin.c: 210, Vitamin.a: 35, Vitamin.e: 15},
    ),
    Ingredient(
      name: 'แตงกวา',
      group: IngredientGroup.vegetable,
      calories: 15, protein: 0.7, carbs: 3.6, fat: 0.1, sugar: 1.7,
      vitaminPercent: {Vitamin.k: 20},
    ),
    Ingredient(
      name: 'กะหล่ำปลี',
      group: IngredientGroup.vegetable,
      calories: 25, protein: 1.3, carbs: 5.8, fat: 0.1, sugar: 3.2,
      vitaminPercent: {Vitamin.c: 40, Vitamin.k: 70},
    ),
    Ingredient(
      name: 'เห็ดฟาง',
      group: IngredientGroup.vegetable,
      calories: 30, protein: 3, carbs: 4.5, fat: 0.3,
      vitaminPercent: {Vitamin.b: 20, Vitamin.d: 15},
    ),
    Ingredient(
      name: 'ผักกาดหอม',
      group: IngredientGroup.vegetable,
      calories: 15, protein: 1.4, carbs: 2.9, fat: 0.2,
      vitaminPercent: {Vitamin.a: 40, Vitamin.k: 100},
    ),

    // ---------- ผลไม้ ----------
    Ingredient(
      name: 'กล้วยน้ำว้า',
      group: IngredientGroup.fruit,
      calories: 89, protein: 1.1, carbs: 23, fat: 0.3, sugar: 12,
      vitaminPercent: {Vitamin.b: 20, Vitamin.c: 12},
      unitHint: '1 ผล ≈ 60 ก.', unitGrams: 60,
    ),
    Ingredient(
      name: 'ส้ม',
      group: IngredientGroup.fruit,
      calories: 47, protein: 0.9, carbs: 12, fat: 0.1, sugar: 9,
      vitaminPercent: {Vitamin.c: 90, Vitamin.a: 10},
      unitHint: '1 ผล ≈ 130 ก.', unitGrams: 130,
    ),
    Ingredient(
      name: 'มะละกอสุก',
      group: IngredientGroup.fruit,
      calories: 43, protein: 0.5, carbs: 11, fat: 0.3, sugar: 8,
      vitaminPercent: {Vitamin.c: 70, Vitamin.a: 25},
    ),
    Ingredient(
      name: 'ฝรั่ง',
      group: IngredientGroup.fruit,
      calories: 68, protein: 2.6, carbs: 14, fat: 1, sugar: 9,
      vitaminPercent: {Vitamin.c: 250, Vitamin.a: 12},
    ),
    Ingredient(
      name: 'อะโวคาโด',
      group: IngredientGroup.fruit,
      calories: 160, protein: 2, carbs: 8.5, fat: 15, sugar: 0.7,
      vitaminPercent: {Vitamin.e: 15, Vitamin.k: 25, Vitamin.c: 12, Vitamin.b: 20},
    ),

    // ---------- ข้าว/แป้ง ----------
    Ingredient(
      name: 'ข้าวสวย',
      group: IngredientGroup.grain,
      calories: 130, protein: 2.7, carbs: 28, fat: 0.3,
      unitHint: '1 ทัพพี ≈ 60 ก.', unitGrams: 60,
    ),
    Ingredient(
      name: 'ข้าวกล้องสุก',
      group: IngredientGroup.grain,
      calories: 123, protein: 2.7, carbs: 26, fat: 1,
      vitaminPercent: {Vitamin.b: 15},
      unitHint: '1 ทัพพี ≈ 60 ก.', unitGrams: 60,
    ),
    Ingredient(
      name: 'ข้าวเหนียวนึ่ง',
      group: IngredientGroup.grain,
      calories: 169, protein: 3.5, carbs: 37, fat: 0.3,
      unitHint: '1 ห่อ ≈ 100 ก.', unitGrams: 100,
    ),
    Ingredient(
      name: 'เส้นก๋วยเตี๋ยวลวก',
      group: IngredientGroup.grain,
      calories: 109, protein: 1.8, carbs: 25, fat: 0.2,
    ),
    Ingredient(
      name: 'ขนมปังโฮลวีต',
      group: IngredientGroup.grain,
      calories: 247, protein: 13, carbs: 41, fat: 3.4, sugar: 5,
      vitaminPercent: {Vitamin.b: 20},
      unitHint: '1 แผ่น ≈ 30 ก.', unitGrams: 30,
    ),

    // ---------- ไขมัน/ถั่ว ----------
    Ingredient(
      name: 'น้ำมันพืช',
      group: IngredientGroup.fat,
      calories: 884, protein: 0, carbs: 0, fat: 100,
      vitaminPercent: {Vitamin.e: 60, Vitamin.k: 20},
      unitHint: '1 ช้อนโต๊ะ ≈ 14 ก.', unitGrams: 14,
    ),
    Ingredient(
      name: 'น้ำมันมะกอก',
      group: IngredientGroup.fat,
      calories: 884, protein: 0, carbs: 0, fat: 100,
      vitaminPercent: {Vitamin.e: 95, Vitamin.k: 50},
      unitHint: '1 ช้อนโต๊ะ ≈ 14 ก.', unitGrams: 14,
    ),
    Ingredient(
      name: 'กะทิ',
      group: IngredientGroup.fat,
      calories: 230, protein: 2.3, carbs: 5.5, fat: 24, sugar: 3.3,
      unitHint: '1 ถ้วย ≈ 240 ก.', unitGrams: 240,
    ),
    Ingredient(
      name: 'ถั่วลิสงคั่ว',
      group: IngredientGroup.fat,
      calories: 567, protein: 26, carbs: 16, fat: 49, sugar: 4,
      vitaminPercent: {Vitamin.e: 55, Vitamin.b: 60},
    ),
    Ingredient(
      name: 'อัลมอนด์',
      group: IngredientGroup.fat,
      calories: 579, protein: 21, carbs: 22, fat: 50, sugar: 4.4,
      vitaminPercent: {Vitamin.e: 170, Vitamin.b: 30},
    ),
  ];

  /// ค้นด้วยชื่อ — ไม่สนช่องว่างและตัวพิมพ์ ชื่อที่ขึ้นต้นด้วยคำค้นมาก่อน
  static List<Ingredient> search(String query, {int limit = 8}) {
    final q = _normalize(query);
    if (q.isEmpty) return const [];
    final matches = items.where((i) => _normalize(i.name).contains(q)).toList();
    matches.sort((a, b) {
      final aStarts = _normalize(a.name).startsWith(q);
      final bStarts = _normalize(b.name).startsWith(q);
      if (aStarts != bStarts) return aStarts ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return matches.take(limit).toList();
  }

  static List<Ingredient> byGroup(IngredientGroup group) =>
      items.where((i) => i.group == group).toList();

  static String _normalize(String value) => value.toLowerCase().replaceAll(' ', '').trim();
}
