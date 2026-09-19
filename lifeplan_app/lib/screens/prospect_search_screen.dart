import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/contact_search.dart';
import '../data/id_gen.dart';
import '../data/repositories/client_repository.dart';
import '../models/client.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/back_button_circle.dart';
import '../widgets/section_heading.dart';
import 'business_card_scan_screen.dart';
import 'contacts_import_screen.dart';

/// ค้นหาผู้มุ่งหวัง/บริษัท แล้วบันทึกเข้ารายชื่อลูกค้าได้ในหน้าเดียว
///
/// แอปเปิดหน้าค้นหาของเว็บนั้นให้ ไม่ได้ดึงข้อมูลมาเก็บเอง (เหตุผลอยู่ใน `ContactSearch`)
class ProspectSearchScreen extends StatefulWidget {
  /// เปิดลิงก์จริง — เทสต์ส่งฟังก์ชันของตัวเองเข้ามาแทน
  final Future<bool> Function(Uri url)? onOpenUrl;

  const ProspectSearchScreen({super.key, this.onOpenUrl});

  @override
  State<ProspectSearchScreen> createState() => _ProspectSearchScreenState();
}

class _ProspectSearchScreenState extends State<ProspectSearchScreen> {
  final _queryController = TextEditingController();
  final ClientRepository _clients = ClientRepository();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _search(ContactSource source) async {
    final url = ContactSearch.urlFor(source, _queryController.text);
    if (url == null) {
      _toast('พิมพ์ชื่อบริษัทหรือชื่อคนที่จะค้นก่อน');
      return;
    }

    final open = widget.onOpenUrl ?? (u) => launchUrl(u, mode: LaunchMode.externalApplication);
    if (!await open(url)) _toast('เปิดลิงก์ไม่สำเร็จ — ลองตรวจว่าเครื่องมีเบราว์เซอร์');
  }

  Future<void> _saveAsClient() async {
    final name = _queryController.text.trim();
    if (name.isEmpty) {
      _toast('พิมพ์ชื่อที่จะบันทึกก่อน');
      return;
    }

    final clean = name.replaceAll(RegExp('คุณ'), '').trim();
    await _clients.put(Client(
      id: newId(),
      name: name,
      initials: clean.isEmpty ? '?' : clean.characters.take(2).toString(),
      policyLabel: 'จากการค้นหา • ลูกค้าใหม่',
      stage: ClientStage.newLead,
    ));
    _toast('บันทึก “$name” เข้ารายชื่อลูกค้าแล้ว');
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
                  child: Text('ค้นหาผู้มุ่งหวัง',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text('พิมพ์ชื่อบริษัทหรือชื่อคน แล้วเลือกแหล่งที่จะค้น',
                style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textFaint)),
            const SizedBox(height: 18),

            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AuthField(
                    key: const ValueKey('prospect-query-field'),
                    label: 'ชื่อบริษัท / ชื่อคน',
                    hint: 'เช่น บริษัท ตัวอย่าง จำกัด',
                    controller: _queryController,
                  ),
                  const SizedBox(height: 14),
                  for (final source in ContactSource.values) ...[
                    _SourceButton(
                      source: source,
                      onTap: () => _search(source),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 2),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const ValueKey('save-as-client'),
                      onPressed: _saveAsClient,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.crm,
                        side: const BorderSide(color: AppColors.crm, width: 1.4),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.person_add_alt_rounded, size: 19),
                      label: const Text('บันทึกชื่อนี้เข้ารายชื่อลูกค้า',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            GestureDetector(
              key: const ValueKey('open-contacts-import'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ContactsImportScreen()),
              ),
              child: AppCard(
                child: Row(
                  children: [
                    const Icon(Icons.contacts_rounded, size: 22, color: AppColors.crm),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('นำเข้าจากสมุดโทรศัพท์',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                          SizedBox(height: 2),
                          Text('ติ๊กเลือกคนที่จะเพิ่มเป็นผู้มุ่งหวัง พร้อมเบอร์โทร',
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            GestureDetector(
              key: const ValueKey('open-card-scan'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BusinessCardScanScreen()),
              ),
              child: AppCard(
                child: Row(
                  children: [
                    const Icon(Icons.document_scanner_rounded, size: 22, color: AppColors.crm),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('สแกนนามบัตร',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                          SizedBox(height: 2),
                          Text('ถ่ายรูปแล้วแอปอ่านเบอร์/อีเมล/บริษัทให้ในเครื่อง',
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeading(title: 'สิ่งที่แอปทำและไม่ทำ'),
                  const SizedBox(height: 10),
                  const _Bullet('แอปเปิดหน้าค้นหาของเว็บนั้นให้เท่านั้น ไม่ได้ดึงรายชื่อหรือโปรไฟล์มาเก็บเอง'),
                  const _Bullet('Facebook และ Instagram ไม่เปิดให้แอปภายนอกค้นหารายชื่อคนอัตโนมัติ '
                      '(ปิดตั้งแต่ปี 2018) จึงต้องค้นและคัดเองในแอปนั้น'),
                  const _Bullet('ข้อมูลที่คุณคัดมาบันทึกเอง จะเก็บอยู่ในเครื่องนี้เท่านั้น — '
                      'เก็บเท่าที่จำเป็นต่อการติดต่อ และลบเมื่อไม่ได้ใช้แล้ว'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  final ContactSource source;
  final VoidCallback onTap;

  const _SourceButton({required this.source, required this.onTap});

  IconData get _icon => switch (source) {
        ContactSource.dbd => Icons.domain_rounded,
        ContactSource.google => Icons.travel_explore_rounded,
        ContactSource.facebook => Icons.groups_rounded,
        ContactSource.instagram => Icons.photo_camera_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('search-source-${source.name}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(_icon, size: 20, color: AppColors.crm),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(source.label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(source.hint,
                      style: const TextStyle(fontSize: 11.5, height: 1.35, color: AppColors.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.textFaint),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 8),
            child: SizedBox(
              width: 5,
              height: 5,
              child: DecoratedBox(decoration: BoxDecoration(color: AppColors.textFaint, shape: BoxShape.circle)),
            ),
          ),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12, height: 1.5, color: AppColors.textMuted)),
          ),
        ],
      ),
    );
  }
}
