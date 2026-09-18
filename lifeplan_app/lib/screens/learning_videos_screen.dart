import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/video_search.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/back_button_circle.dart';
import '../widgets/form_sheet.dart';
import '../widgets/section_heading.dart';

/// ค้นคลิปความรู้บน YouTube ตามหัวข้อ แล้วเปิดผลลัพธ์ที่เรียงตามที่เลือก
///
/// แอปไม่ได้ดึงรายชื่อคลิปมาเอง (ต้องใช้ API key) แต่ส่งคำค้น + คำสั่งเรียงลำดับ
/// ไปให้ YouTube จัดอันดับให้ — ดูเหตุผลใน `VideoSearch`
class LearningVideosScreen extends StatefulWidget {
  /// เปิดลิงก์จริง — เทสต์ส่งฟังก์ชันของตัวเองเข้ามาแทนเพื่อดักว่าเปิด URL อะไร
  final Future<bool> Function(Uri url)? onOpenUrl;

  const LearningVideosScreen({super.key, this.onOpenUrl});

  @override
  State<LearningVideosScreen> createState() => _LearningVideosScreenState();
}

class _LearningVideosScreenState extends State<LearningVideosScreen> {
  final _queryController = TextEditingController();
  VideoSort _sort = VideoSort.viewCount;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _open(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('พิมพ์เรื่องที่อยากเรียน หรือเลือกจากหัวข้อด้านล่าง')),
      );
      return;
    }

    final url = VideoSearch.searchUrl(clean, sort: _sort);
    final open = widget.onOpenUrl ?? (u) => launchUrl(u, mode: LaunchMode.externalApplication);
    final opened = await open(url);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เปิด YouTube ไม่สำเร็จ — ลองตรวจว่าเครื่องมีแอป YouTube หรือเบราว์เซอร์')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  child: Text('ค้นคลิปความรู้',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text('พิมพ์เรื่องที่อยากเรียน แล้วแอปจะเปิด YouTube ให้โดยเรียงผลตามที่เลือกไว้',
                style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textFaint)),
            const SizedBox(height: 18),

            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AuthField(
                    key: const ValueKey('video-query-field'),
                    label: 'เรื่องที่อยากเรียน',
                    hint: 'เช่น วิเคราะห์หุ้น / วางแผนภาษี',
                    controller: _queryController,
                  ),
                  const SizedBox(height: 14),
                  LabeledDropdown<VideoSort>(
                    label: 'เรียงผลลัพธ์',
                    value: _sort,
                    options: VideoSort.values,
                    display: (s) => s.label,
                    onChanged: (v) => setState(() => _sort = v!),
                  ),
                  const SizedBox(height: 6),
                  Text(_sort.hint, style: const TextStyle(fontSize: 11.5, height: 1.4, color: AppColors.textFaint)),
                  const SizedBox(height: 14),
                  PrimaryButton(label: 'ค้นบน YouTube', onPressed: () => _open(_queryController.text)),
                ],
              ),
            ),
            const SizedBox(height: 18),

            const SectionHeading(title: 'หัวข้อแนะนำ'),
            const SizedBox(height: 4),
            const Text('แตะคำค้นเพื่อเปิดผลลัพธ์ทันที',
                style: TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
            const SizedBox(height: 12),
            for (final topic in VideoSearch.topics) ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(topic.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final query in topic.queries)
                          GestureDetector(
                            key: ValueKey('query-chip-$query'),
                            onTap: () => _open(query),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.learningSoft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.play_circle_outline_rounded, size: 15, color: AppColors.learning),
                                  const SizedBox(width: 6),
                                  Text(query,
                                      style: const TextStyle(
                                          fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.learning)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 4),
            const Text(
              'หมายเหตุ: การเรียง "ยอดดูมากที่สุด" ใช้ระบบจัดอันดับของ YouTube เอง '
              'แอปไม่ได้เก็บหรือคำนวณยอดวิว และคลิปที่คนดูเยอะไม่ได้แปลว่าถูกต้องเสมอไป',
              style: TextStyle(fontSize: 11, height: 1.5, color: AppColors.textFaint),
            ),
          ],
        ),
      ),
    );
  }
}
