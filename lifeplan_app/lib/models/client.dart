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

  const Client({
    required this.id,
    required this.name,
    required this.initials,
    required this.policyLabel,
    required this.stage,
    this.premiumAmount = 0,
    this.phone,
    this.profileUrl,
  });

  String get statusLabel => stage.label;

  Client copyWith({ClientStage? stage, String? phone, String? profileUrl}) => Client(
        id: id,
        name: name,
        initials: initials,
        policyLabel: policyLabel,
        stage: stage ?? this.stage,
        premiumAmount: premiumAmount,
        phone: phone ?? this.phone,
        profileUrl: profileUrl ?? this.profileUrl,
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
      );
}
