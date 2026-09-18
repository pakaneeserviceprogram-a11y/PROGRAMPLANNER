import '../models/meal_entry.dart';

/// เมนูอาหารไทยหนึ่งรายการ พร้อมคุณค่าโดยประมาณต่อหนึ่งหน่วยเสิร์ฟ
class ThaiFood {
  final String name;

  /// หน่วยเสิร์ฟที่ค่าต่าง ๆ อ้างอิงถึง เช่น "1 จาน (~350 ก.)"
  final String serving;

  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double sugar;
  final List<Vitamin> vitamins;

  const ThaiFood({
    required this.name,
    required this.serving,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.sugar = 0,
    this.vitamins = const [],
  });
}

/// รายการเมนูไทยที่เจอบ่อย ไว้ให้เลือกแทนการกรอกกรัมเอง
///
/// **ค่าทั้งหมดเป็นค่าประมาณต่อหนึ่งหน่วยเสิร์ฟ** จากสูตรทั่วไป ร้านแต่ละร้านต่างกันได้มาก
/// (น้ำมัน กะทิ ขนาดจาน) — ฟอร์มจึงเติมค่าให้เป็นจุดตั้งต้นแล้วผู้ใช้แก้ต่อได้เสมอ
/// ไม่ใช่ข้อมูลอ้างอิงทางโภชนาการที่ผ่านการตรวจสอบ
class ThaiFoodDatabase {
  ThaiFoodDatabase._();

  static const items = <ThaiFood>[
    // ข้าวจานเดียว
    ThaiFood(name: 'ข้าวมันไก่', serving: '1 จาน (~350 ก.)', calories: 600, protein: 26, carbs: 75, fat: 22, sugar: 3, vitamins: [Vitamin.b]),
    ThaiFood(name: 'ข้าวผัดกุ้ง', serving: '1 จาน (~300 ก.)', calories: 550, protein: 22, carbs: 70, fat: 19, sugar: 4, vitamins: [Vitamin.b, Vitamin.d]),
    ThaiFood(name: 'ข้าวกะเพราหมูสับไข่ดาว', serving: '1 จาน (~350 ก.)', calories: 700, protein: 30, carbs: 78, fat: 30, sugar: 5, vitamins: [Vitamin.a, Vitamin.k]),
    ThaiFood(name: 'ข้าวหมูกรอบ', serving: '1 จาน (~300 ก.)', calories: 680, protein: 24, carbs: 72, fat: 32, sugar: 4),
    ThaiFood(name: 'ข้าวขาหมู', serving: '1 จาน (~350 ก.)', calories: 700, protein: 28, carbs: 76, fat: 32, sugar: 6),
    ThaiFood(name: 'ข้าวคลุกกะปิ', serving: '1 จาน (~300 ก.)', calories: 560, protein: 18, carbs: 78, fat: 20, sugar: 8, vitamins: [Vitamin.a]),
    ThaiFood(name: 'ข้าวหน้าเป็ด', serving: '1 จาน (~320 ก.)', calories: 620, protein: 30, carbs: 74, fat: 22, sugar: 5),
    ThaiFood(name: 'ข้าวไข่เจียว', serving: '1 จาน (~250 ก.)', calories: 520, protein: 16, carbs: 62, fat: 24, sugar: 2, vitamins: [Vitamin.a, Vitamin.d]),
    ThaiFood(name: 'ข้าวกล้องอกไก่ย่าง', serving: '1 จาน (~300 ก.)', calories: 450, protein: 40, carbs: 55, fat: 8, sugar: 2, vitamins: [Vitamin.b]),
    ThaiFood(name: 'ข้าวเหนียวหมูปิ้ง', serving: 'ข้าวเหนียว 1 ห่อ + หมูปิ้ง 2 ไม้', calories: 520, protein: 22, carbs: 70, fat: 16, sugar: 8),

    // แกง / กับข้าว (นับรวมข้าวสวย 1 ทัพพี)
    ThaiFood(name: 'แกงเขียวหวานไก่ + ข้าว', serving: '1 ถ้วย + ข้าว 1 ทัพพี', calories: 560, protein: 24, carbs: 58, fat: 26, sugar: 8, vitamins: [Vitamin.a, Vitamin.k]),
    ThaiFood(name: 'แกงส้มผักรวมกุ้ง + ข้าว', serving: '1 ถ้วย + ข้าว 1 ทัพพี', calories: 400, protein: 22, carbs: 55, fat: 8, sugar: 9, vitamins: [Vitamin.a, Vitamin.c]),
    ThaiFood(name: 'ต้มยำกุ้งน้ำใส', serving: '1 ถ้วย (~300 มล.)', calories: 180, protein: 22, carbs: 10, fat: 6, sugar: 4, vitamins: [Vitamin.c]),
    ThaiFood(name: 'ต้มข่าไก่', serving: '1 ถ้วย (~300 มล.)', calories: 350, protein: 20, carbs: 12, fat: 26, sugar: 6, vitamins: [Vitamin.c]),
    ThaiFood(name: 'มัสมั่นไก่ + ข้าว', serving: '1 ถ้วย + ข้าว 1 ทัพพี', calories: 620, protein: 26, carbs: 62, fat: 30, sugar: 12, vitamins: [Vitamin.a]),
    ThaiFood(name: 'ผัดผักรวมมิตร', serving: '1 จาน (~200 ก.)', calories: 180, protein: 6, carbs: 18, fat: 10, sugar: 6, vitamins: [Vitamin.a, Vitamin.c, Vitamin.k]),
    ThaiFood(name: 'ไข่พะโล้', serving: '1 ถ้วย (ไข่ 1 ฟอง + หมู)', calories: 320, protein: 18, carbs: 14, fat: 22, sugar: 10, vitamins: [Vitamin.d]),
    ThaiFood(name: 'ปลาทูทอด', serving: '1 ตัว (~80 ก.)', calories: 190, protein: 20, carbs: 0, fat: 12, vitamins: [Vitamin.d]),
    ThaiFood(name: 'ปลากะพงนึ่งมะนาว', serving: '1 จาน (~250 ก.)', calories: 280, protein: 40, carbs: 6, fat: 10, sugar: 3, vitamins: [Vitamin.c, Vitamin.d]),
    ThaiFood(name: 'ส้มตำไทย', serving: '1 จาน (~200 ก.)', calories: 180, protein: 5, carbs: 28, fat: 5, sugar: 16, vitamins: [Vitamin.a, Vitamin.c]),
    ThaiFood(name: 'ลาบหมู', serving: '1 จาน (~200 ก.)', calories: 320, protein: 26, carbs: 10, fat: 20, sugar: 3, vitamins: [Vitamin.c]),
    ThaiFood(name: 'ยำวุ้นเส้นทะเล', serving: '1 จาน (~250 ก.)', calories: 300, protein: 22, carbs: 38, fat: 7, sugar: 10, vitamins: [Vitamin.c]),
    ThaiFood(name: 'ไก่ย่าง', serving: '1/4 ตัว (~150 ก.)', calories: 300, protein: 32, carbs: 4, fat: 17, sugar: 2),

    // เส้น
    ThaiFood(name: 'ผัดไทยกุ้งสด', serving: '1 จาน (~300 ก.)', calories: 600, protein: 22, carbs: 78, fat: 22, sugar: 14),
    ThaiFood(name: 'ก๋วยเตี๋ยวน้ำหมู', serving: '1 ชาม (~400 มล.)', calories: 350, protein: 20, carbs: 48, fat: 9, sugar: 5),
    ThaiFood(name: 'ก๋วยเตี๋ยวต้มยำ', serving: '1 ชาม (~400 มล.)', calories: 450, protein: 22, carbs: 55, fat: 15, sugar: 10),
    ThaiFood(name: 'เย็นตาโฟ', serving: '1 ชาม (~400 มล.)', calories: 400, protein: 20, carbs: 58, fat: 8, sugar: 14),
    ThaiFood(name: 'บะหมี่หมูแดง', serving: '1 ชาม (~350 ก.)', calories: 420, protein: 22, carbs: 56, fat: 12, sugar: 8),
    ThaiFood(name: 'ราดหน้าหมู', serving: '1 จาน (~350 ก.)', calories: 520, protein: 22, carbs: 66, fat: 18, sugar: 8, vitamins: [Vitamin.k]),
    ThaiFood(name: 'ผัดซีอิ๊ว', serving: '1 จาน (~300 ก.)', calories: 550, protein: 20, carbs: 70, fat: 20, sugar: 8, vitamins: [Vitamin.k]),
    ThaiFood(name: 'ข้าวซอยไก่', serving: '1 ชาม (~400 ก.)', calories: 650, protein: 26, carbs: 68, fat: 30, sugar: 8, vitamins: [Vitamin.a]),
    ThaiFood(name: 'สุกี้น้ำรวมมิตร', serving: '1 ชาม (~400 ก.)', calories: 320, protein: 24, carbs: 34, fat: 9, sugar: 8, vitamins: [Vitamin.a, Vitamin.k]),

    // เช้า / ของว่าง
    ThaiFood(name: 'โจ๊กหมูใส่ไข่', serving: '1 ถ้วย (~350 มล.)', calories: 320, protein: 18, carbs: 42, fat: 9, sugar: 2, vitamins: [Vitamin.d]),
    ThaiFood(name: 'ข้าวต้มหมู', serving: '1 ถ้วย (~350 มล.)', calories: 280, protein: 16, carbs: 40, fat: 6, sugar: 2),
    ThaiFood(name: 'ปาท่องโก๋ (2 ตัว)', serving: '2 ตัว', calories: 260, protein: 4, carbs: 30, fat: 14, sugar: 4),
    ThaiFood(name: 'ขนมปังปิ้งเนยน้ำตาล', serving: '2 แผ่น', calories: 300, protein: 6, carbs: 42, fat: 12, sugar: 16),
    ThaiFood(name: 'ไข่ต้ม', serving: '1 ฟอง', calories: 75, protein: 6, carbs: 1, fat: 5, vitamins: [Vitamin.a, Vitamin.d]),
    ThaiFood(name: 'กล้วยน้ำว้า', serving: '1 ผล', calories: 100, protein: 1, carbs: 26, fat: 0, sugar: 14, vitamins: [Vitamin.b, Vitamin.c]),
    ThaiFood(name: 'ส้มเขียวหวาน', serving: '1 ผล', calories: 60, protein: 1, carbs: 15, fat: 0, sugar: 12, vitamins: [Vitamin.c]),
    ThaiFood(name: 'มะม่วงน้ำดอกไม้สุก', serving: '1/2 ผล (~150 ก.)', calories: 100, protein: 1, carbs: 25, fat: 0, sugar: 22, vitamins: [Vitamin.a, Vitamin.c]),
    ThaiFood(name: 'ข้าวเหนียวมะม่วง', serving: '1 จาน', calories: 480, protein: 6, carbs: 82, fat: 14, sugar: 45, vitamins: [Vitamin.a, Vitamin.c]),
    ThaiFood(name: 'โยเกิร์ตรสธรรมชาติ', serving: '1 ถ้วย (~150 ก.)', calories: 90, protein: 8, carbs: 10, fat: 2, sugar: 8, vitamins: [Vitamin.b, Vitamin.d]),
    ThaiFood(name: 'อกไก่ต้ม', serving: '100 ก.', calories: 165, protein: 31, carbs: 0, fat: 4, vitamins: [Vitamin.b]),
    ThaiFood(name: 'สลัดผักน้ำใส', serving: '1 จาน (~200 ก.)', calories: 120, protein: 4, carbs: 14, fat: 5, sugar: 8, vitamins: [Vitamin.a, Vitamin.c, Vitamin.k]),

    // เครื่องดื่ม (ชื่อมีคำที่ระบบจับคาเฟอีนได้ ดูการ์ด "การนอนกับสิ่งที่กิน")
    ThaiFood(name: 'กาแฟดำไม่ใส่น้ำตาล', serving: '1 แก้ว (~240 มล.)', calories: 5, protein: 0, carbs: 1, fat: 0),
    ThaiFood(name: 'กาแฟเย็น', serving: '1 แก้ว (~350 มล.)', calories: 250, protein: 3, carbs: 35, fat: 10, sugar: 30),
    ThaiFood(name: 'ชาไทยเย็น', serving: '1 แก้ว (~350 มล.)', calories: 280, protein: 3, carbs: 42, fat: 10, sugar: 38),
    ThaiFood(name: 'ชาเขียวไม่หวาน', serving: '1 แก้ว (~350 มล.)', calories: 5, protein: 0, carbs: 1, fat: 0),
    ThaiFood(name: 'นมสดจืด', serving: '1 กล่อง (~250 มล.)', calories: 150, protein: 8, carbs: 12, fat: 8, sugar: 12, vitamins: [Vitamin.a, Vitamin.d]),
    ThaiFood(name: 'น้ำเปล่า', serving: '1 แก้ว (~250 มล.)', calories: 0, protein: 0, carbs: 0, fat: 0),
  ];

  /// ค้นเมนูจากชื่อ — ไม่สนช่องว่างและตัวพิมพ์ เพื่อให้พิมพ์ "ข้าวผัด" หรือ "ผัดไทย" ก็เจอ
  static List<ThaiFood> search(String query, {int limit = 6}) {
    final q = _normalize(query);
    if (q.isEmpty) return const [];
    final matches = items.where((f) => _normalize(f.name).contains(q)).toList();
    // ชื่อที่ "ขึ้นต้นด้วย" คำค้นน่าจะใช่กว่า จึงดันขึ้นก่อน
    matches.sort((a, b) {
      final aStarts = _normalize(a.name).startsWith(q);
      final bStarts = _normalize(b.name).startsWith(q);
      if (aStarts != bStarts) return aStarts ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return matches.take(limit).toList();
  }

  static String _normalize(String value) => value.toLowerCase().replaceAll(' ', '').trim();
}
