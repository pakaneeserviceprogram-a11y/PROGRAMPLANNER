import 'package:flutter/material.dart';

import '../data/ingredient_database.dart';
import '../data/recipe_calculator.dart';
import '../data/repositories/goal_settings_repository.dart';
import '../data/repositories/meal_repository.dart';
import '../models/meal_entry.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/back_button_circle.dart';
import '../widgets/form_sheet.dart';
import '../widgets/progress_track.dart';
import '../widgets/section_heading.dart';

/// คำนวณสารอาหารจากวัตถุดิบที่ชั่งเป็นกรัม แล้วบันทึกเป็นมื้ออาหารได้
///
/// ค่าต่อ 100 ก. มาจากตารางที่ฝังในแอป (ดู `IngredientDatabase` เรื่องที่มาและข้อจำกัด)
class RecipeCalculatorScreen extends StatefulWidget {
  const RecipeCalculatorScreen({super.key});

  @override
  State<RecipeCalculatorScreen> createState() => _RecipeCalculatorScreenState();
}

class _RecipeCalculatorScreenState extends State<RecipeCalculatorScreen> {
  final _searchController = TextEditingController();
  final MealRepository _meals = MealRepository();
  final GoalSettingsRepository _goals = GoalSettingsRepository();

  final _items = <RecipeItem>[];

  @override
  void initState() {
    super.initState();
    // ผลค้นหาขึ้นกับข้อความในช่อง — ต้อง rebuild ทุกครั้งที่พิมพ์
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _add(Ingredient ingredient) {
    setState(() {
      // ใส่ซ้ำ = บวกน้ำหนักเข้าไปในบรรทัดเดิม ไม่สร้างบรรทัดใหม่ให้รก
      final index = _items.indexWhere((i) => i.ingredient.name == ingredient.name);
      final add = ingredient.unitGrams ?? 100;
      if (index >= 0) {
        _items[index] = _items[index].copyWith(grams: _items[index].grams + add);
      } else {
        _items.add(RecipeItem(ingredient: ingredient, grams: add));
      }
      _searchController.clear();
    });
  }

  Future<void> _editGrams(int index) async {
    final item = _items[index];
    final controller = TextEditingController(text: item.grams.toStringAsFixed(0));

    await showAppFormSheet(
      context: context,
      title: item.ingredient.name,
      submitLabel: 'ตกลง',
      bodyBuilder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuthField(
            key: const ValueKey('grams-field'),
            label: 'น้ำหนัก (กรัม)',
            hint: '100',
            controller: controller,
            keyboardType: TextInputType.number,
          ),
          if (item.ingredient.unitHint != null) ...[
            const SizedBox(height: 8),
            Text(item.ingredient.unitHint!,
                style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
          ],
        ],
      ),
      footerBuilder: (sheetCtx) => SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          onPressed: () {
            Navigator.of(sheetCtx).pop();
            setState(() => _items.removeAt(index));
          },
          style: TextButton.styleFrom(foregroundColor: formDangerColor, padding: const EdgeInsets.symmetric(vertical: 14)),
          icon: const Icon(Icons.delete_outline_rounded, size: 20),
          label: const Text('เอาออกจากจาน', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
      onSubmit: () {
        final grams = double.tryParse(controller.text.trim());
        if (grams != null && grams > 0) {
          setState(() => _items[index] = item.copyWith(grams: grams));
        }
        Navigator.of(context).pop();
      },
    );
  }

  Future<void> _saveAsMeal(RecipeTotals totals) async {
    final titleController = TextEditingController(text: RecipeCalculator.suggestTitle(_items));
    var type = _suggestMealType();

    await showAppFormSheet(
      context: context,
      title: 'บันทึกเป็นมื้ออาหาร',
      submitLabel: 'บันทึก',
      bodyBuilder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthField(
              key: const ValueKey('meal-title-field'),
              label: 'ชื่อมื้อ',
              hint: 'เช่น อกไก่ + ข้าวกล้อง',
              controller: titleController,
            ),
            const SizedBox(height: 14),
            LabeledDropdown<MealType>(
              label: 'มื้อ',
              value: type,
              options: MealType.values,
              display: (t) => t.label,
              onChanged: (v) => setSheetState(() => type = v!),
            ),
            const SizedBox(height: 12),
            Text('${totals.calories.round()} kcal • โปรตีน ${totals.protein.round()} ก. • '
                'แป้ง ${totals.carbs.round()} ก. • ไขมัน ${totals.fat.round()} ก.',
                style: const TextStyle(fontSize: 12, height: 1.5, color: AppColors.textMuted)),
          ],
        ),
      ),
      onSubmit: () async {
        final title = titleController.text.trim();
        if (title.isEmpty) return;

        final now = TimeOfDay.now();
        await _meals.put(RecipeCalculator.toMealEntry(
          _items,
          title: title,
          type: type,
          time: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        ));

        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('บันทึก “$title” ลงบันทึกโภชนาการแล้ว')),
        );
      },
    );
  }

  /// เดามื้อจากเวลาปัจจุบัน — ก่อน 10 โมงเป็นเช้า ก่อนบ่าย 3 เป็นกลางวัน
  MealType _suggestMealType() {
    final hour = TimeOfDay.now().hour;
    if (hour < 10) return MealType.breakfast;
    if (hour < 15) return MealType.lunch;
    if (hour < 21) return MealType.dinner;
    return MealType.snack;
  }

  @override
  Widget build(BuildContext context) {
    final totals = RecipeCalculator.totalsOf(_items);
    final goals = _goals.get();
    final matches = IngredientDatabase.search(_searchController.text);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const Row(
              children: [
                BackButtonCircle(),
                SizedBox(width: 12),
                Expanded(
                  child: Text('คำนวณจากวัตถุดิบ',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text('ใส่วัตถุดิบและน้ำหนักเป็นกรัม แอปจะรวมพลังงาน โปรตีน ไขมัน และวิตามินให้',
                style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textFaint)),
            const SizedBox(height: 18),

            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AuthField(
                    key: const ValueKey('ingredient-search-field'),
                    label: 'ค้นวัตถุดิบ',
                    hint: 'เช่น อกไก่ / เนื้อวัว / ไข่ไก่ / มะเขือเทศ',
                    controller: _searchController,
                  ),
                  if (_searchController.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    if (matches.isEmpty)
                      const Text('ไม่เจอวัตถุดิบนี้ในตาราง — ลองคำอื่น หรือใช้หน้าบันทึกมื้ออาหารกรอกเอง',
                          style: TextStyle(fontSize: 11.5, height: 1.4, color: AppColors.textFaint))
                    else
                      for (final ing in matches)
                        _SearchRow(ingredient: ing, onTap: () => _add(ing)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            if (_items.isEmpty)
              const AppCard(
                child: Text('ยังไม่ได้ใส่วัตถุดิบ — ค้นแล้วแตะเพื่อเพิ่มลงจาน แตะที่บรรทัดเพื่อแก้น้ำหนัก',
                    style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textFaint)),
              )
            else ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeading(title: 'ในจานนี้', action: 'รวม ${totals.grams.round()} ก.'),
                    const SizedBox(height: 8),
                    for (var i = 0; i < _items.length; i++) ...[
                      if (i != 0) const Divider(height: 18, color: AppColors.border),
                      _ItemRow(item: _items[i], onTap: () => _editGrams(i)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _TotalsCard(totals: totals, calorieTarget: goals.calorieTarget, proteinTarget: goals.proteinTarget),
              const SizedBox(height: 18),
              _VitaminCard(totals: totals),
              const SizedBox(height: 18),
              PrimaryButton(label: 'บันทึกเป็นมื้ออาหาร', onPressed: () => _saveAsMeal(totals)),
            ],
            const SizedBox(height: 16),
            const Text(
              'ค่าต่อ 100 กรัมเป็นค่าประมาณจากตารางคุณค่าอาหารมาตรฐาน ของจริงแกว่งตามส่วนของเนื้อและวิธีปรุง '
              '— ตัวเลขวิตามินเป็น % ของที่ควรได้ต่อวันสำหรับผู้ใหญ่ทั่วไป',
              style: TextStyle(fontSize: 11, height: 1.5, color: AppColors.textFaint),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchRow extends StatelessWidget {
  final Ingredient ingredient;
  final VoidCallback onTap;

  const _SearchRow({required this.ingredient, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('ingredient-${ingredient.name}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ingredient.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    '${ingredient.calories} kcal • โปรตีน ${ingredient.protein} ก. • ไขมัน ${ingredient.fat} ก. (ต่อ 100 ก.)',
                    style: const TextStyle(fontSize: 11, color: AppColors.textFaint),
                  ),
                ],
              ),
            ),
            const Icon(Icons.add_circle_outline_rounded, size: 20, color: AppColors.nutrition),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final RecipeItem item;
  final VoidCallback onTap;

  const _ItemRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('item-${item.ingredient.name}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.ingredient.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${item.grams.round()} ก. • ${item.calories.round()} kcal • โปรตีน ${item.protein.toStringAsFixed(1)} ก.',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.edit_outlined, size: 16, color: AppColors.textFaint),
          ],
        ),
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  final RecipeTotals totals;
  final int calorieTarget;
  final double proteinTarget;

  const _TotalsCard({required this.totals, required this.calorieTarget, required this.proteinTarget});

  @override
  Widget build(BuildContext context) {
    final split = totals.energySplit;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(title: 'รวมทั้งจาน'),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${totals.calories.round()}',
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.nutrition)),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(bottom: 5),
                child: Text('kcal', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
              ),
              const Spacer(),
              if (calorieTarget > 0)
                Text('${(totals.calories / calorieTarget * 100).round()}% ของเป้าวันนี้',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 14),
          _MacroLine(label: 'โปรตีน', grams: totals.protein, ratio: split.protein, color: AppColors.nutrition),
          const SizedBox(height: 10),
          _MacroLine(label: 'แป้ง / คาร์โบไฮเดรต', grams: totals.carbs, ratio: split.carbs, color: AppColors.crm),
          const SizedBox(height: 10),
          _MacroLine(label: 'ไขมัน', grams: totals.fat, ratio: split.fat, color: AppColors.finance),
          const SizedBox(height: 12),
          Text('น้ำตาล ${totals.sugar.toStringAsFixed(1)} ก.',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          if (proteinTarget > 0) ...[
            const SizedBox(height: 6),
            Text('จานนี้ให้โปรตีน ${(totals.protein / proteinTarget * 100).round()}% ของที่ควรได้ทั้งวัน',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ],
      ),
    );
  }
}

class _MacroLine extends StatelessWidget {
  final String label;
  final double grams;

  /// สัดส่วนพลังงานที่มาจากสารอาหารนี้ (0–1)
  final double ratio;
  final Color color;

  const _MacroLine({required this.label, required this.grams, required this.ratio, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
            Text('${grams.toStringAsFixed(1)} ก.',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Text('${(ratio * 100).round()}% ของพลังงาน',
                style: const TextStyle(fontSize: 11, color: AppColors.textFaint)),
          ],
        ),
        const SizedBox(height: 6),
        ProgressTrack(value: ratio, color: color),
      ],
    );
  }
}

class _VitaminCard extends StatelessWidget {
  final RecipeTotals totals;

  const _VitaminCard({required this.totals});

  @override
  Widget build(BuildContext context) {
    final notable = totals.notableVitamins();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(title: 'วิตามินที่ได้จากจานนี้'),
          const SizedBox(height: 4),
          const Text('เทียบกับปริมาณที่ผู้ใหญ่ควรได้ต่อวัน',
              style: TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
          const SizedBox(height: 12),
          if (notable.isEmpty)
            const Text('จานนี้ยังไม่ให้วิตามินตัวไหนถึง 15% ของวัน — เพิ่มผักหรือผลไม้เข้าไปอีกหน่อย',
                style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textFaint))
          else
            for (final entry in notable) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('วิตามิน ${entry.key.label}',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                        ),
                        Text('${entry.value.round()}%',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: entry.value >= 100 ? AppColors.exercise : AppColors.text)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ProgressTrack(
                      value: (entry.value / 100).clamp(0, 1).toDouble(),
                      color: entry.value >= 100 ? AppColors.exercise : AppColors.nutrition,
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}
