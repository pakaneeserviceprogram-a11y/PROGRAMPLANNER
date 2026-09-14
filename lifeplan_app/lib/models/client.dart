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

  const Client({
    required this.id,
    required this.name,
    required this.initials,
    required this.policyLabel,
    required this.stage,
    this.premiumAmount = 0,
  });

  String get statusLabel => stage.label;

  Client copyWith({ClientStage? stage}) => Client(
        id: id,
        name: name,
        initials: initials,
        policyLabel: policyLabel,
        stage: stage ?? this.stage,
        premiumAmount: premiumAmount,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'initials': initials,
        'policyLabel': policyLabel,
        'stage': stage.name,
        'premiumAmount': premiumAmount,
      };

  factory Client.fromMap(Map<String, dynamic> map) => Client(
        id: map['id'] as String,
        name: map['name'] as String,
        initials: map['initials'] as String,
        policyLabel: map['policyLabel'] as String,
        stage: ClientStage.values.firstWhere((e) => e.name == map['stage'], orElse: () => ClientStage.newLead),
        premiumAmount: (map['premiumAmount'] as num?)?.toDouble() ?? 0,
      );
}
