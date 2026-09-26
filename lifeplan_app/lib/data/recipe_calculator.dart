import '../models/meal_entry.dart';
import 'id_gen.dart';
import 'ingredient_database.dart';

/// วัตถุดิบหนึ่งบรรทัดในจาน พร้อมน้ำหนักที่ใส่จริง
class RecipeItem {
  final Ingredient ingredient;
  final double grams;

  const RecipeItem({required this.ingredient, required this.grams});

  /// ตัวคูณจากค่า "ต่อ 100 ก." ไปเป็นน้ำหนักจริง
  double get _factor => grams / 100;

  double get calories => ingredient.calories * _factor;
  double get protein => ingredient.protein * _factor;
  double get carbs => ingredient.carbs * _factor;
  double get fat => ingredient.fat * _factor;
  double get sugar => ingredient.sugar * _factor;

  /// วิตามินที่ได้จากบรรทัดนี้ (% ของที่ควรได้ต่อวัน)
  Map<Vitamin, double> get vitaminPercent =>
      ingredient.vitaminPercent.map((k, v) => MapEntry(k, v * _factor));

  RecipeItem copyWith({double? grams}) => RecipeItem(ingredient: ingredient, grams: grams ?? this.grams);
}

/// ผลรวมของทั้งจาน
class RecipeTotals {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double sugar;
  final double grams;

  /// รวมวิตามินเป็น % ของที่ควรได้ต่อวัน (ยังไม่ตัดเพดาน — ตัดตอนแสดงผล)
  final Map<Vitamin, double> vitaminPercent;

  const RecipeTotals({
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.sugar = 0,
    this.grams = 0,
    this.vitaminPercent = const {},
  });

  bool get isEmpty => grams == 0;

  /// สัดส่วนพลังงานที่มาจากโปรตีน/คาร์บ/ไขมัน (รวมกันได้ ~1)
  ///
  /// ใช้ดูว่าจานนี้ "มันเกินไปไหม" ได้เร็วกว่าดูกรัมดิบ ๆ
  ({double protein, double carbs, double fat}) get energySplit {
    final fromProtein = protein * 4;
    final fromCarbs = carbs * 4;
    final fromFat = fat * 9;
    final total = fromProtein + fromCarbs + fromFat;
    if (total <= 0) return (protein: 0, carbs: 0, fat: 0);
    return (protein: fromProtein / total, carbs: fromCarbs / total, fat: fromFat / total);
  }

  /// วิตามินที่ได้ถึง [threshold]% ขึ้นไป เรียงจากมากไปน้อย — ใช้สรุปว่า "จานนี้เด่นวิตามินอะไร"
  List<MapEntry<Vitamin, double>> notableVitamins({double threshold = 15}) {
    final list = vitaminPercent.entries.where((e) => e.value >= threshold).toList();
    list.sort((a, b) => b.value.compareTo(a.value));
    return list;
  }
}

/// คำนวณคุณค่าอาหารจากวัตถุดิบที่ชั่งเป็นกรัม — ฟังก์ชันล้วน เทสต์ได้ตรง ๆ
class RecipeCalculator {
  RecipeCalculator._();

  static RecipeTotals totalsOf(Iterable<RecipeItem> items) {
    var calories = 0.0, protein = 0.0, carbs = 0.0, fat = 0.0, sugar = 0.0, grams = 0.0;
    final vitamins = <Vitamin, double>{};

    for (final item in items) {
      calories += item.calories;
      protein += item.protein;
      carbs += item.carbs;
      fat += item.fat;
      sugar += item.sugar;
      grams += item.grams;
      item.vitaminPercent.forEach((k, v) => vitamins[k] = (vitamins[k] ?? 0) + v);
    }

    return RecipeTotals(
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      sugar: sugar,
      grams: grams,
      vitaminPercent: vitamins,
    );
  }

  /// แปลงทั้งจานเป็นมื้ออาหารหนึ่งรายการเพื่อบันทึกลงบันทึกโภชนาการ
  ///
  /// วิตามินที่ได้ถึง [vitaminThreshold]% ของวันถึงจะติดธงว่า "ได้วิตามินนี้"
  /// (ได้นิดหน่อยแล้วเคลมว่าครบจะทำให้การ์ดวิตามินบนหน้าโภชนาการหลอกตัวเอง)
  static MealEntry toMealEntry(
    Iterable<RecipeItem> items, {
    required String title,
    required MealType type,
    required String time,
    DateTime? date,
    double vitaminThreshold = 15,
  }) {
    final totals = totalsOf(items);
    return MealEntry(
      id: newId(),
      title: title,
      type: type,
      time: time,
      date: date ?? DateTime.now(),
      calories: totals.calories.round(),
      proteinGrams: _round1(totals.protein),
      carbGrams: _round1(totals.carbs),
      fatGrams: _round1(totals.fat),
      sugarGrams: _round1(totals.sugar),
      vitamins: totals.notableVitamins(threshold: vitaminThreshold).map((e) => e.key).toList(),
    );
  }

  /// ชื่อมื้อที่เดาให้จากวัตถุดิบหลัก (น้ำหนักมากสุดก่อน) เช่น "อกไก่ไม่มีหนัง + ข้าวสวย"
  static String suggestTitle(Iterable<RecipeItem> items, {int take = 2}) {
    final sorted = items.toList()..sort((a, b) => b.grams.compareTo(a.grams));
    if (sorted.isEmpty) return '';
    return sorted.take(take).map((i) => i.ingredient.name).join(' + ');
  }

  static double _round1(double value) => double.parse(value.toStringAsFixed(1));
}
