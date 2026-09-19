import 'package:flutter/material.dart';

import '../data/contacts_import.dart';
import '../data/repositories/client_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/back_button_circle.dart';

/// นำเข้าผู้มุ่งหวังจากสมุดโทรศัพท์ — ติ๊กเลือกเองทีละคน
///
/// อ่านรายชื่อมาแสดงเฉย ๆ **บันทึกเฉพาะคนที่ติ๊ก** คนที่ไม่ได้เลือกไม่ถูกเก็บไว้ที่ไหน
/// และไม่มีข้อมูลออกนอกเครื่อง
class ContactsImportScreen extends StatefulWidget {
  /// ใส่แหล่งข้อมูลปลอมได้ในเทสต์ (ค่าเริ่มต้นคือสมุดโทรศัพท์จริง)
  final ContactsSource? source;

  const ContactsImportScreen({super.key, this.source});

  @override
  State<ContactsImportScreen> createState() => _ContactsImportScreenState();
}

enum _LoadState { loading, denied, ready, failed }

class _ContactsImportScreenState extends State<ContactsImportScreen> {
  final _searchController = TextEditingController();
  final ClientRepository _clients = ClientRepository();
  final _selected = <String>{};

  _LoadState _state = _LoadState.loading;
  List<DeviceContact> _contacts = const [];
  String _error = '';

  ContactsSource get _source => widget.source ?? ContactsSource.instance;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _state = _LoadState.loading);
    try {
      if (!await _source.requestPermission()) {
        if (mounted) setState(() => _state = _LoadState.denied);
        return;
      }

      final all = await _source.fetchAll();
      final suggestions = ContactsImport.suggest(all, _clients.getAll());
      if (!mounted) return;
      setState(() {
        _contacts = suggestions;
        _state = _LoadState.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _state = _LoadState.failed;
      });
    }
  }

  Future<void> _import() async {
    final picked = _contacts.where((c) => _selected.contains(c.id)).toList();
    if (picked.isEmpty) return;

    for (final contact in picked) {
      await _clients.put(ContactsImport.toClient(contact));
    }
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('นำเข้า ${picked.length} รายชื่อเป็นลูกค้าใหม่แล้ว')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final visible = ContactsImport.search(_contacts, _searchController.text);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      BackButtonCircle(),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text('นำเข้าจากสมุดโทรศัพท์',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('ติ๊กเลือกคนที่จะเพิ่มเป็นผู้มุ่งหวัง — เฉพาะคนที่เลือกเท่านั้นที่ถูกบันทึก',
                      style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textFaint)),
                  const SizedBox(height: 14),
                  if (_state == _LoadState.ready)
                    AuthField(
                      key: const ValueKey('contact-search-field'),
                      label: 'ค้นหาในรายชื่อ',
                      hint: 'ชื่อหรือเบอร์',
                      controller: _searchController,
                    ),
                ],
              ),
            ),
            Expanded(child: _buildBody(visible)),
            if (_state == _LoadState.ready && _selected.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: PrimaryButton(label: 'นำเข้า ${_selected.length} รายชื่อ', onPressed: _import),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<DeviceContact> visible) {
    switch (_state) {
      case _LoadState.loading:
        return const Center(child: CircularProgressIndicator());

      case _LoadState.denied:
        return _Message(
          icon: Icons.lock_outline_rounded,
          title: 'ยังไม่ได้รับสิทธิ์อ่านรายชื่อ',
          detail: 'เปิดสิทธิ์ "รายชื่อติดต่อ" ให้ LifePlan ในการตั้งค่าของเครื่อง แล้วกดลองใหม่',
          actionLabel: 'ลองใหม่',
          onAction: _load,
        );

      case _LoadState.failed:
        return _Message(
          icon: Icons.error_outline_rounded,
          title: 'อ่านรายชื่อไม่สำเร็จ',
          detail: _error,
          actionLabel: 'ลองใหม่',
          onAction: _load,
        );

      case _LoadState.ready:
        if (_contacts.isEmpty) {
          return const _Message(
            icon: Icons.contacts_outlined,
            title: 'ไม่มีรายชื่อใหม่ให้เพิ่ม',
            detail: 'รายชื่อในเครื่องถูกเพิ่มเป็นลูกค้าไปแล้ว หรือสมุดโทรศัพท์ยังว่าง',
          );
        }
        if (visible.isEmpty) {
          return const _Message(icon: Icons.search_off_rounded, title: 'ไม่เจอรายชื่อที่ค้น', detail: 'ลองพิมพ์คำอื่น');
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          itemCount: visible.length,
          itemBuilder: (context, i) {
            final contact = visible[i];
            final checked = _selected.contains(contact.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Checkbox(
                      key: ValueKey('contact-check-${contact.id}'),
                      value: checked,
                      activeColor: AppColors.crm,
                      onChanged: (v) => setState(() {
                        if (v ?? false) {
                          _selected.add(contact.id);
                        } else {
                          _selected.remove(contact.id);
                        }
                      }),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(contact.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(contact.phone ?? 'ไม่มีเบอร์ในรายชื่อ',
                              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
    }
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Message({
    required this.icon,
    required this.title,
    required this.detail,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: AppColors.textFaint),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(detail,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textMuted)),
            if (actionLabel != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.crm,
                  side: const BorderSide(color: AppColors.crm, width: 1.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(actionLabel!, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
