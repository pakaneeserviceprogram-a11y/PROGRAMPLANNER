import '../models/medication.dart';

/// ผลที่แกะได้จากรูปกล่อง/ฉลากยา
class MedicineLabel {
  /// ชื่อที่เดาว่าเป็นชื่อการค้า (บรรทัดเด่นบรรทัดแรกที่ไม่ใช่ตัวยา/ข้อความมาตรฐาน)
  final String? brand;

  final List<MedIngredient> ingredients;

  /// ข้อความดิบทั้งหมด เผื่อผู้ใช้อยากอ่านส่วนที่แอปแกะไม่ได้
  final String rawText;

  const MedicineLabel({this.brand, this.ingredients = const [], this.rawText = ''});

  bool get isEmpty => brand == null && ingredients.isEmpty;
}

/// แกะตัวยาจากข้อความบนฉลาก
///
/// **ข้อมูลมาจากกล่องยาของผู้ใช้เอง** ไม่ได้ไปค้นจากฐานข้อมูลยาที่ไหน
/// (ไม่มี API เปิดที่เชื่อถือได้สำหรับยาไทย และการเดาส่วนประกอบยาเองอันตราย)
///
/// ฉลากยาไทยเกือบทั้งหมดพิมพ์ชื่อตัวยาเป็นอักษรละติน เช่น `Paracetamol 500 mg`
/// ซึ่งตรงกับที่ ML Kit อ่านได้ ส่วนข้อความไทยรอบ ๆ จะอ่านไม่ออก (ดู `MlKitCardTextRecognizer`)
class MedicineLabelParser {
  MedicineLabelParser._();

  /// ชื่อตัวยา (ละติน) ตามด้วยปริมาณและหน่วย — รองรับ 500mg, 500 mg, 1.5 g, 400 IU, 50 mcg
  static final _ingredientPattern = RegExp(
    r'([A-Za-z][A-Za-z0-9\-\s\.]{2,40}?)\s*[:\-]?\s*(\d+(?:[.,]\d+)?)\s*(mg|mcg|µg|ug|g|ml|iu|%)\b',
    caseSensitive: false,
  );

  /// คำที่อยู่บนกล่องยาแทบทุกกล่องแต่ไม่ใช่ชื่อยา — กันไม่ให้กลายเป็นชื่อการค้า
  static const _skipWords = [
    'tablet', 'tablets', 'capsule', 'capsules', 'softgel', 'film coated', 'sugar coated',
    'mg', 'mcg', 'each', 'contains', 'composition', 'ingredients', 'dietary supplement',
    'reg no', 'reg. no', 'batch', 'exp', 'mfg', 'lot', 'made in', 'keep out of reach',
    'store below', 'store at', 'dosage', 'direction', 'warning',
  ];

  static MedicineLabel parse(String rawText) {
    final lines = rawText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    final ingredients = <MedIngredient>[];
    final seen = <String>{};
    for (final line in lines) {
      for (final match in _ingredientPattern.allMatches(line)) {
        final name = _cleanName(match.group(1)!);
        if (name.length < 3) continue;
        if (_skipWords.any((w) => name.toLowerCase() == w)) continue;

        final amount = match.group(2)!.replaceAll(',', '.');
        final unit = _normalizeUnit(match.group(3)!);
        final key = name.toLowerCase();
        if (!seen.add(key)) continue;
        ingredients.add(MedIngredient(name: name, strength: '$amount $unit'));
      }
    }

    return MedicineLabel(
      brand: _guessBrand(lines, ingredients),
      ingredients: ingredients,
      rawText: rawText,
    );
  }

  /// ชื่อการค้ามักเป็นบรรทัดบนสุดที่เป็นตัวอักษรล้วน ไม่มีตัวเลขปริมาณ และไม่ใช่คำมาตรฐานบนกล่อง
  static String? _guessBrand(List<String> lines, List<MedIngredient> ingredients) {
    final ingredientNames = ingredients.map((i) => i.name.toLowerCase()).toSet();
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (_ingredientPattern.hasMatch(line)) continue;
      if (_skipWords.any(lower.contains)) continue;
      if (ingredientNames.contains(lower)) continue;
      if (!RegExp(r'[A-Za-zก-๙]').hasMatch(line)) continue;
      if (line.length < 3 || line.length > 40) continue;
      return line;
    }
    return null;
  }

  static String _cleanName(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'^[^A-Za-z]+|[^A-Za-z0-9)\s]+$'), '').trim();

  static String _normalizeUnit(String unit) {
    final u = unit.toLowerCase();
    if (u == 'iu') return 'IU';
    if (u == 'ug' || u == 'µg') return 'mcg';
    return u;
  }
}
