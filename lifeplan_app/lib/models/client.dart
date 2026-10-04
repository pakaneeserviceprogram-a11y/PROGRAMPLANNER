enum ClientStage { newLead, contacted, proposalSent, followUp, closedWon }

extension ClientStageX on ClientStage {
  String get label => switch (this) {
        ClientStage.newLead => 'ติดต่อกลับ',
        ClientStage.contacted => 'ติดต่อแล้ว',
        ClientStage.proposalSent => 'รอตอบกลับ',
        ClientStage.followUp => 'ติดตามวันนี้',
        ClientStage.closedWon => 'ปิดแล้ว',
      };

  ClientStage get next => switch (this) {
        ClientStage.newLead => ClientStage.contacted,
        ClientStage.contacted => ClientStage.proposalSent,
        ClientStage.proposalSent => ClientStage.followUp,
        ClientStage.followUp => ClientStage.closedWon,
        ClientStage.closedWon => ClientStage.closedWon,
      };
}

/// ลูกค้ารายนี้มาจากไหน — ใช้ดูว่าแหล่งไหนปิดการขายได้จริง (ต่อยอดรายงาน N = New Market)
enum ClientSource { unknown, referral, phonebook, businessCard, facebook, instagram, line, event, walkIn }

extension ClientSourceX on ClientSource {
  String get label => switch (this) {
        ClientSource.unknown => 'ไม่ได้ระบุ',
        ClientSource.referral => 'เพื่อน/ลูกค้าแนะนำ',
        ClientSource.phonebook => 'สมุดโทรศัพท์',
        ClientSource.businessCard => 'นามบัตร',
        ClientSource.facebook => 'Facebook',
        ClientSource.instagram => 'Instagram',
        ClientSource.line => 'LINE',
        ClientSource.event => 'งานอีเวนต์/ออกบูท',
        ClientSource.walkIn => 'ติดต่อเข้ามาเอง',
      };
}

/// สถานะของแผนประกันหนึ่งแผนกับลูกค้ารายนี้
enum PlanStatus { proposed, applied, active, declined }

extension PlanStatusX on PlanStatus {
  String get label => switch (this) {
        PlanStatus.proposed => 'เสนอแล้ว',
        PlanStatus.applied => 'ยื่นใบคำขอแล้ว',
        PlanStatus.active => 'กรมธรรม์มีผลแล้ว',
        PlanStatus.declined => 'ไม่สนใจ/ยกเลิก',
      };

  /// แผนที่ยังนับเป็นเบี้ยได้ (ไม่รวมที่ลูกค้าปฏิเสธ)
  bool get counts => this != PlanStatus.declined;
}

/// แผนประกันหนึ่งแผนที่เสนอ/ขายให้ลูกค้ารายนี้ — ลูกค้าหนึ่งคนมีได้หลายแผน
class InsurancePlan {
  final String id;
  final String name;

  /// ทุนประกัน (บาท) — 0 = ไม่ได้ระบุ
  final double sumInsured;

  /// เบี้ยต่อปี (บาท)
  final double annualPremium;
  final PlanStatus status;
  final String? note;

  const InsurancePlan({
    required this.id,
    required this.name,
    this.sumInsured = 0,
    this.annualPremium = 0,
    this.status = PlanStatus.proposed,
    this.note,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'sumInsured': sumInsured,
        'annualPremium': annualPremium,
        'status': status.name,
        'note': note,
      };

  factory InsurancePlan.fromMap(Map map) => InsurancePlan(
        id: map['id'] as String,
        name: map['name'] as String? ?? '',
        sumInsured: (map['sumInsured'] as num?)?.toDouble() ?? 0,
        annualPremium: (map['annualPremium'] as num?)?.toDouble() ?? 0,
        status: PlanStatus.values.firstWhere((e) => e.name == map['status'], orElse: () => PlanStatus.proposed),
        note: map['note'] as String?,
      );
}

/// บันทึกการเข้าพบลูกค้าหนึ่งครั้ง พร้อมของขวัญที่ให้ (ถ้ามี)
class ClientVisit {
  final String id;
  final DateTime date;
  final String? note;

  /// ของขวัญ/ของฝากที่ให้ครั้งนี้ — กันให้ของซ้ำ และใช้ดูว่าให้อะไรไปแล้วบ้าง
  final String? gift;

  ClientVisit({required this.id, required DateTime date, this.note, this.gift})
      : date = DateTime(date.year, date.month, date.day);

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'note': note,
        'gift': gift,
      };

  factory ClientVisit.fromMap(Map map) => ClientVisit(
        id: map['id'] as String,
        date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
        note: map['note'] as String?,
        gift: map['gift'] as String?,
      );
}

class Client {
  final String id;
  final String name;
  final String initials;
  final String policyLabel;
  final ClientStage stage;
  final double premiumAmount;

  /// เบอร์โทรที่ผู้ใช้กรอกเอง (null = ยังไม่มี) — กดโทรออกจากหน้าลูกค้าได้
  final String? phone;

  /// ลิงก์โปรไฟล์โซเชียล/เว็บไซต์ที่ผู้ใช้ **ค้นเจอเองแล้ววางไว้**
  /// แอปไม่ได้ไปค้นหรือดึงมาเอง (ดู `ContactSearch`)
  final String? profileUrl;

  /// แหล่งที่มาของลูกค้ารายนี้ (ค่าเริ่มต้น = ยังไม่ได้ระบุ)
  final ClientSource source;

  /// แผนประกันที่เสนอ/ขายให้ลูกค้ารายนี้
  final List<InsurancePlan> plans;

  /// ประวัติการเข้าพบ เรียงใหม่ → เก่า
  final List<ClientVisit> visits;

  /// วัน-เวลาที่ต้องติดตามลูกค้ารายนี้ครั้งถัดไป (null = ยังไม่ได้ตั้ง) — มีแจ้งเตือน
  final DateTime? followUpAt;
  final String? followUpNote;

  const Client({
    required this.id,
    required this.name,
    required this.initials,
    required this.policyLabel,
    required this.stage,
    this.premiumAmount = 0,
    this.phone,
    this.profileUrl,
    this.source = ClientSource.unknown,
    this.plans = const [],
    this.visits = const [],
    this.followUpAt,
    this.followUpNote,
  });

  String get statusLabel => stage.label;

  /// เบี้ยรวมต่อปีของแผนที่ยังไม่ถูกปฏิเสธ
  double get plansPremium =>
      plans.where((p) => p.status.counts).fold(0, (sum, p) => sum + p.annualPremium);

  /// การเข้าพบล่าสุด (null = ยังไม่เคยบันทึก)
  ClientVisit? get lastVisit => visits.isEmpty ? null : visits.first;

  /// เลยกำหนดติดตามแล้ว (ถึงเวลาแล้วแต่ยังไม่ได้เลื่อน/ล้าง)
  bool isFollowUpDue({DateTime? now}) =>
      followUpAt != null && !followUpAt!.isAfter(now ?? DateTime.now());

  Client copyWith({
    ClientStage? stage,
    String? phone,
    String? profileUrl,
    ClientSource? source,
    double? premiumAmount,
    List<InsurancePlan>? plans,
    List<ClientVisit>? visits,
    DateTime? followUpAt,
    String? followUpNote,
    bool clearFollowUp = false,
  }) =>
      Client(
        id: id,
        name: name,
        initials: initials,
        policyLabel: policyLabel,
        stage: stage ?? this.stage,
        premiumAmount: premiumAmount ?? this.premiumAmount,
        phone: phone ?? this.phone,
        profileUrl: profileUrl ?? this.profileUrl,
        source: source ?? this.source,
        plans: plans ?? this.plans,
        visits: visits ?? this.visits,
        followUpAt: clearFollowUp ? null : (followUpAt ?? this.followUpAt),
        followUpNote: clearFollowUp ? null : (followUpNote ?? this.followUpNote),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'initials': initials,
        'policyLabel': policyLabel,
        'stage': stage.name,
        'premiumAmount': premiumAmount,
        'phone': phone,
        'profileUrl': profileUrl,
        'source': source.name,
        'plans': plans.map((p) => p.toMap()).toList(),
        'visits': visits.map((v) => v.toMap()).toList(),
        'followUpAt': followUpAt?.toIso8601String(),
        'followUpNote': followUpNote,
      };

  factory Client.fromMap(Map<String, dynamic> map) => Client(
        id: map['id'] as String,
        name: map['name'] as String,
        initials: map['initials'] as String,
        policyLabel: map['policyLabel'] as String,
        stage: ClientStage.values.firstWhere((e) => e.name == map['stage'], orElse: () => ClientStage.newLead),
        premiumAmount: (map['premiumAmount'] as num?)?.toDouble() ?? 0,
        // ลูกค้าที่บันทึกก่อนมีช่องติดต่อยังไม่มีคีย์เหล่านี้
        phone: map['phone'] as String?,
        profileUrl: map['profileUrl'] as String?,
        source: ClientSource.values.firstWhere(
          (e) => e.name == map['source'],
          orElse: () => ClientSource.unknown,
        ),
        // ลูกค้าที่บันทึกก่อนมีแผน/การเข้าพบ/วันติดตาม ได้ค่าว่าง
        plans: [for (final p in (map['plans'] as List?) ?? const []) InsurancePlan.fromMap(p as Map)],
        visits: [for (final v in (map['visits'] as List?) ?? const []) ClientVisit.fromMap(v as Map)]
          ..sort((a, b) => b.date.compareTo(a.date)),
        followUpAt: DateTime.tryParse(map['followUpAt'] as String? ?? ''),
        followUpNote: map['followUpNote'] as String?,
      );
}
