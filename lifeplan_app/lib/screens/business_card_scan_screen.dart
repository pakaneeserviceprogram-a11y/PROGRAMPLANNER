import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/business_card_scanner.dart';
import '../data/repositories/client_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/back_button_circle.dart';

/// สแกนนามบัตร → แกะข้อมูล → ให้ผู้ใช้ตรวจ/แก้ → บันทึกเป็นลูกค้าใหม่
///
/// ข้อความอ่านในเครื่องด้วย ML Kit ไม่ได้ส่งรูปขึ้นคลาวด์
/// **ไม่รองรับภาษาไทย** — ชื่อไทยจะอ่านไม่ออก ผู้ใช้พิมพ์เองได้ในขั้นตรวจทาน
class BusinessCardScanScreen extends StatefulWidget {
  /// เทสต์ส่งตัวอ่านปลอมเข้ามาแทน ML Kit
  final CardTextRecognizer? recognizer;

  /// เทสต์ส่งฟังก์ชันเลือกรูปของตัวเองเข้ามา (คืน path ของรูป, null = ผู้ใช้ยกเลิก)
  final Future<String?> Function(ImageSource source)? pickImage;

  const BusinessCardScanScreen({super.key, this.recognizer, this.pickImage});

  @override
  State<BusinessCardScanScreen> createState() => _BusinessCardScanScreenState();
}

class _BusinessCardScanScreenState extends State<BusinessCardScanScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _companyController = TextEditingController();
  final ClientRepository _clients = ClientRepository();

  BusinessCardFields? _fields;
  bool _busy = false;
  String _error = '';

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String?> _pick(ImageSource source) async {
    if (widget.pickImage != null) return widget.pickImage!(source);
    final file = await ImagePicker().pickImage(source: source, imageQuality: 90);
    return file?.path;
  }

  Future<void> _scan(ImageSource source) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = '';
    });

    try {
      final path = await _pick(source);
      if (path == null) return; // ผู้ใช้ยกเลิก — ไม่ต้องขึ้น error

      final recognizer = widget.recognizer ?? CardTextRecognizer.instance;
      final fields = BusinessCardParser.parse(await recognizer.recognize(path));
      if (!mounted) return;

      setState(() {
        _fields = fields;
        _nameController.text = fields.name ?? '';
        _phoneController.text = fields.phone ?? '';
        _companyController.text = fields.company ?? '';
      });

      if (fields.isEmpty) _toast('อ่านข้อมูลจากรูปไม่ได้ — ลองถ่ายใหม่ให้ชัดขึ้น หรือพิมพ์เอง');
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _toast('ใส่ชื่อลูกค้าก่อนบันทึก');
      return;
    }

    final base = _fields ?? const BusinessCardFields();
    final company = _companyController.text.trim();
    await _clients.put(BusinessCardParser.toClient(
      BusinessCardFields(
        name: name,
        phone: _phoneController.text.trim(),
        email: base.email,
        company: company.isEmpty ? null : company,
        website: base.website,
      ),
      nameOverride: name,
      phoneOverride: _phoneController.text.trim(),
    ));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('บันทึก “$name” เข้ารายชื่อลูกค้าแล้ว')));
    Navigator.of(context).pop();
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
                  child: Text('สแกนนามบัตร',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text('ถ่ายรูปนามบัตร แอปจะอ่านข้อมูลให้ในเครื่อง (ไม่ส่งรูปขึ้นคลาวด์) แล้วให้คุณตรวจก่อนบันทึก',
                style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textFaint)),
            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: _ScanButton(
                    key: const ValueKey('scan-camera'),
                    icon: Icons.photo_camera_rounded,
                    label: 'ถ่ายรูป',
                    onTap: _busy ? null : () => _scan(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ScanButton(
                    key: const ValueKey('scan-gallery'),
                    icon: Icons.image_rounded,
                    label: 'เลือกจากคลังรูป',
                    onTap: _busy ? null : () => _scan(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            if (_busy) ...[
              const SizedBox(height: 18),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('อ่านรูปไม่สำเร็จ: $_error',
                  style: const TextStyle(fontSize: 12, height: 1.5, color: Color(0xFFB3401E))),
            ],
            const SizedBox(height: 18),

            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ตรวจข้อมูลก่อนบันทึก',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('ชื่อภาษาไทยมักอ่านไม่ออก (ตัวอ่านรองรับอักษรละติน) พิมพ์เพิ่มเองได้',
                      style: TextStyle(fontSize: 11.5, height: 1.4, color: AppColors.textFaint)),
                  const SizedBox(height: 14),
                  AuthField(
                    key: const ValueKey('card-name-field'),
                    label: 'ชื่อลูกค้า',
                    hint: 'เช่น คุณสมชาย ใจดี',
                    controller: _nameController,
                  ),
                  const SizedBox(height: 14),
                  AuthField(
                    key: const ValueKey('card-phone-field'),
                    label: 'เบอร์โทร',
                    hint: '08x-xxx-xxxx',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),
                  AuthField(
                    key: const ValueKey('card-company-field'),
                    label: 'บริษัท / รายละเอียด',
                    hint: 'เช่น บริษัท ตัวอย่าง จำกัด',
                    controller: _companyController,
                  ),
                  if (_fields?.email != null) ...[
                    const SizedBox(height: 10),
                    Text('อีเมลที่อ่านได้: ${_fields!.email}',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                  ],
                  if (_fields?.website != null) ...[
                    const SizedBox(height: 4),
                    Text('เว็บไซต์ที่อ่านได้: ${_fields!.website}',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                  ],
                  const SizedBox(height: 18),
                  PrimaryButton(label: 'บันทึกเป็นลูกค้าใหม่', onPressed: _save),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ScanButton({super.key, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: enabled ? AppColors.crmSoft : AppColors.surface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: enabled ? AppColors.crm : AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: enabled ? AppColors.crm : AppColors.textFaint),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: enabled ? AppColors.crm : AppColors.textFaint)),
          ],
        ),
      ),
    );
  }
}
