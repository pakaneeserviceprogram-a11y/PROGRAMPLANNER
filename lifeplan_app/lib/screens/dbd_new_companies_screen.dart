import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/calendar_utils.dart';
import '../data/contact_search.dart';
import '../data/dbd_open_data.dart';
import '../data/repositories/client_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/back_button_circle.dart';

/// บริษัทจดทะเบียนใหม่จากข้อมูลเปิดของ DBD — กรองตามทุน/จังหวัด/ประเภท แล้วเรียงตามทุนจดทะเบียน
///
/// กลุ่มเป้าหมายประกันกลุ่ม อุบัติเหตุพนักงาน และประกันคนสำคัญของกรรมการ
class DbdNewCompaniesScreen extends StatefulWidget {
  /// เปลี่ยนได้ในเทสต์ — ค่าจริงเปิดลิงก์ด้วยแอปภายนอก
  final Future<bool> Function(Uri uri)? onOpenUrl;

  const DbdNewCompaniesScreen({super.key, this.onOpenUrl});

  @override
  State<DbdNewCompaniesScreen> createState() => _DbdNewCompaniesScreenState();
}

class _DbdNewCompaniesScreenState extends State<DbdNewCompaniesScreen> {
  static const _capitalSteps = <double>[0, 1000000, 5000000, 10000000, 50000000];

  final _clients = ClientRepository();
  final _searchController = TextEditingController();

  DbdMonthData? _data;
  List<(int, int)> _cachedMonths = const [];
  bool _loading = true;
  String? _status;
  DbdFilter _filter = const DbdFilter();

  @override
  void initState() {
    super.initState();
    _openNewestCached();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _openNewestCached() async {
    try {
      final months = await DbdOpenData.cachedMonths();
      DbdMonthData? data;
      if (months.isNotEmpty) data = await DbdOpenData.loadCached(months.first.$1, months.first.$2);
      if (!mounted) return;
      setState(() {
        _cachedMonths = months;
        _data = data;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// ปุ่มอัปเดต: หาเดือนล่าสุดที่ DBD ออกไฟล์แล้ว โหลดเก็บไว้ และเปิดเดือนนั้น
  Future<void> _update() async {
    setState(() {
      _loading = true;
      _status = 'กำลังโหลดข้อมูลล่าสุดจาก DBD (ประมาณ 6 MB)…';
    });
    try {
      final data = await DbdOpenData.downloadLatest();
      final months = await DbdOpenData.cachedMonths();
      if (!mounted) return;
      setState(() {
        _cachedMonths = months;
        if (data != null) _data = data;
      });
      _toast(data == null
          ? 'ยังไม่พบไฟล์ใหม่จาก DBD ลองใหม่ภายหลัง'
          : 'อัปเดตแล้ว: ${data.label} ${data.companies.length} ราย');
    } catch (_) {
      if (mounted) _toast('โหลดข้อมูลไม่สำเร็จ — ตรวจอินเทอร์เน็ตแล้วลองอีกครั้ง');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _status = null;
        });
      }
    }
  }

  /// เปิดเดือนอื่น — มีในเครื่องแล้วเปิดเลย ยังไม่มีก็โหลด
  Future<void> _openMonth(int year, int month) async {
    setState(() {
      _loading = true;
      _status = 'กำลังเปิดข้อมูล ${DbdOpenData.monthLabel(year, month)}…';
    });
    try {
      final data = await DbdOpenData.loadCached(year, month) ?? await DbdOpenData.download(year, month);
      final months = await DbdOpenData.cachedMonths();
      if (!mounted) return;
      setState(() {
        _cachedMonths = months;
        if (data != null) _data = data;
      });
      if (data == null) _toast('DBD ยังไม่ออกข้อมูลของ ${DbdOpenData.monthLabel(year, month)}');
    } catch (_) {
      if (mounted) _toast('โหลดข้อมูลไม่สำเร็จ — ตรวจอินเทอร์เน็ตแล้วลองอีกครั้ง');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _status = null;
        });
      }
    }
  }

  /// 12 เดือนล่าสุดให้เลือก (DBD ออกไฟล์เดือนที่แล้วช่วงต้นเดือน)
  List<(int, int)> get _monthOptions {
    final now = DateTime.now();
    final options = [for (var i = 1; i <= 12; i++) (DateTime(now.year, now.month - i).year, DateTime(now.year, now.month - i).month)];
    final current = _data == null ? null : (_data!.year, _data!.month);
    if (current != null && !options.contains(current)) options.insert(0, current);
    return options;
  }

  bool _alreadyAdded(String name) => _clients.getAll().any((c) => c.name.trim() == name.trim());

  Future<void> _addAsProspect(DbdCompany company) async {
    await _clients.put(DbdOpenData.toClient(company));
    if (!mounted) return;
    setState(() {});
    _toast('เพิ่ม “${company.name}” เป็นผู้มุ่งหวังแล้ว');
  }

  Future<void> _openDetails(DbdCompany c, int rank) async {
    final open = widget.onOpenUrl ?? (u) => launchUrl(u, mode: LaunchMode.externalApplication);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final added = _alreadyAdded(c.name);
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('อันดับ $rank ตามทุนจดทะเบียน', style: const TextStyle(fontSize: 12, color: AppColors.textFaint)),
                  const SizedBox(height: 4),
                  Text(c.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  _Detail('ทุนจดทะเบียน', '${DbdOpenData.formatCapital(c.capital)} (${_baht(c.capital)} บาท)'),
                  _Detail('จดทะเบียนเมื่อ', _thaiRegDate(c.regDate)),
                  _Detail('ประเภทธุรกิจ', '${c.objective} (รหัส ${c.objectiveCode})'),
                  _Detail('ที่ตั้ง', '${c.address} ${c.district} ${c.province}'.trim()),
                  _Detail('เลขทะเบียน', c.regNo),
                  const SizedBox(height: 6),
                  const Text('ข้อมูลเปิดของ DBD ไม่มีเบอร์โทรหรืออีเมล — กดค้นหาเพื่อหาช่องทางติดต่อ',
                      style: TextStyle(fontSize: 11.5, height: 1.4, color: AppColors.textFaint)),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton.icon(
                      key: const ValueKey('dbd-add-prospect'),
                      onPressed: added
                          ? null
                          : () async {
                              await _addAsProspect(c);
                              setSheet(() {});
                            },
                      icon: Icon(added ? Icons.check_rounded : Icons.person_add_alt_rounded),
                      label: Text(added ? 'อยู่ในรายชื่อลูกค้าแล้ว' : 'เพิ่มเป็นผู้มุ่งหวัง',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const ValueKey('dbd-search-contact'),
                      onPressed: () => open(ContactSearch.urlFor(ContactSource.google, '${c.name} ${c.provinceName} เบอร์โทร')!),
                      icon: const Icon(Icons.search_rounded, size: 18),
                      label: const Text('ค้นหาเบอร์ติดต่อใน Google'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static String _baht(double v) =>
      v.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  /// "2569-09-09" → "9 ก.ย. 2569"
  static String _thaiRegDate(String s) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
    if (m == null) return s;
    final month = int.parse(m.group(2)!);
    if (month < 1 || month > 12) return s;
    return '${int.parse(m.group(3)!)} ${CalendarUtils.monthShort[month - 1]} ${m.group(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final results = data == null ? const <DbdCompany>[] : _filter.apply(data.companies);
    final provinces = data == null
        ? const <String>[]
        : (data.companies.map((c) => c.provinceName).where((p) => p.isNotEmpty).toSet().toList()..sort());

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  const BackButtonCircle(),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('บริษัทตั้งใหม่ (DBD)',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                  ),
                  FilledButton.tonalIcon(
                    key: const ValueKey('dbd-update'),
                    onPressed: _loading ? null : _update,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('อัปเดต'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Text(
                data == null
                    ? 'รายชื่อบริษัทที่จดทะเบียนใหม่รายเดือนจากข้อมูลเปิดของกรมพัฒนาธุรกิจการค้า'
                    : 'ข้อมูล${data.label} • ${_baht(data.companies.length.toDouble())} ราย • '
                        'โหลดเมื่อ ${CalendarUtils.thaiDateShort(data.downloadedAt)}',
                key: const ValueKey('dbd-status'),
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
            if (_loading)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      if (_status != null) ...[
                        const SizedBox(height: 12),
                        Text(_status!, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                      ],
                    ],
                  ),
                ),
              )
            else if (data == null)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.apartment_rounded, size: 48, color: AppColors.textFaint),
                        const SizedBox(height: 12),
                        const Text('ยังไม่มีข้อมูลในเครื่อง',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        const Text('กด "อัปเดต" เพื่อโหลดรายชื่อบริษัทตั้งใหม่เดือนล่าสุดจาก DBD (ประมาณ 6 MB ครั้งเดียว)',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              _Filters(
                monthOptions: _monthOptions,
                cachedMonths: _cachedMonths,
                selectedMonth: (data.year, data.month),
                onMonth: (m) => _openMonth(m.$1, m.$2),
                capitalSteps: _capitalSteps,
                filter: _filter,
                provinces: provinces,
                searchController: _searchController,
                onChanged: (f) => setState(() => _filter = f),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
                child: Text('พบ ${_baht(results.length.toDouble())} ราย • เรียงตามทุนจดทะเบียน มาก → น้อย',
                    key: const ValueKey('dbd-result-count'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.crm)),
              ),
              Expanded(
                child: results.isEmpty
                    ? const Center(
                        child: Text('ไม่พบบริษัทที่ตรงเงื่อนไข', style: TextStyle(color: AppColors.textFaint)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: results.length,
                        separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
                        itemBuilder: (_, i) => _CompanyRow(
                          rank: i + 1,
                          company: results[i],
                          onTap: () => _openDetails(results[i], i + 1),
                        ),
                      ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('ที่มา: ข้อมูลเปิด DBD (opendata.dbd.go.th) สัญญาอนุญาต Open Data Common',
                    style: TextStyle(fontSize: 10.5, color: AppColors.textFaint)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  final List<(int, int)> monthOptions;
  final List<(int, int)> cachedMonths;
  final (int, int) selectedMonth;
  final ValueChanged<(int, int)> onMonth;
  final List<double> capitalSteps;
  final DbdFilter filter;
  final List<String> provinces;
  final TextEditingController searchController;
  final ValueChanged<DbdFilter> onChanged;

  const _Filters({
    required this.monthOptions,
    required this.cachedMonths,
    required this.selectedMonth,
    required this.onMonth,
    required this.capitalSteps,
    required this.filter,
    required this.provinces,
    required this.searchController,
    required this.onChanged,
  });

  static String _capitalLabel(double v) => v == 0 ? 'ทุกทุน' : '≥ ${DbdOpenData.formatCapital(v)}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<(int, int)>(
                  key: const ValueKey('dbd-month'),
                  initialValue: selectedMonth,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'เดือนที่จดทะเบียน', isDense: true),
                  items: [
                    for (final m in monthOptions)
                      DropdownMenuItem(
                        value: m,
                        child: Text('${DbdOpenData.monthLabel(m.$1, m.$2)}${cachedMonths.contains(m) ? '' : ' (ต้องโหลด)'}'),
                      ),
                  ],
                  onChanged: (m) {
                    if (m != null && m != selectedMonth) onMonth(m);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  key: const ValueKey('dbd-province'),
                  initialValue: filter.province,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'จังหวัด', isDense: true),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('ทุกจังหวัด')),
                    for (final p in provinces) DropdownMenuItem<String?>(value: p, child: Text(p)),
                  ],
                  onChanged: (p) => onChanged(p == null ? filter.copyWith(clearProvince: true) : filter.copyWith(province: p)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('dbd-keyword'),
            controller: searchController,
            onChanged: (v) => onChanged(filter.copyWith(keyword: v)),
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search_rounded, size: 20),
              hintText: 'ค้นชื่อหรือประเภทธุรกิจ เช่น ก่อสร้าง ร้านอาหาร ขนส่ง',
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final step in capitalSteps) ...[
                  ChoiceChip(
                    key: ValueKey('dbd-capital-${step.toInt()}'),
                    label: Text(_capitalLabel(step)),
                    selected: filter.minCapital == step,
                    onSelected: (_) => onChanged(filter.copyWith(minCapital: step)),
                  ),
                  const SizedBox(width: 6),
                ],
                const SizedBox(width: 6),
                for (final kind in const [null, 'บจ', 'บมจ', 'หจ', 'หส']) ...[
                  ChoiceChip(
                    key: ValueKey('dbd-kind-${kind ?? 'all'}'),
                    label: Text(kind == null ? 'ทุกประเภท' : '$kind.'),
                    selected: filter.kind == kind,
                    onSelected: (_) => onChanged(kind == null ? filter.copyWith(clearKind: true) : filter.copyWith(kind: kind)),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanyRow extends StatelessWidget {
  final int rank;
  final DbdCompany company;
  final VoidCallback onTap;

  const _CompanyRow({required this.rank, required this.company, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 34,
              child: Text('$rank', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textFaint)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(company.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(company.objective,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  Text('${company.district} ${company.provinceName}'.trim(),
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(DbdOpenData.formatCapital(company.capital),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.crm)),
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  final String label;
  final String value;

  const _Detail(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 104, child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textFaint))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12.5, height: 1.4))),
        ],
      ),
    );
  }
}
