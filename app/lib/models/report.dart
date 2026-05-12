class Report {
  final String id;
  final String targetType; // 'USER' | 'ROOM' | 'CHAT_MESSAGE'
  final String targetId;
  final String reason;
  final String? description;
  final String status;
  final String? createdAt;

  Report({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.reason,
    this.description,
    required this.status,
    this.createdAt,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] ?? '',
      targetType: json['targetType'] ?? '',
      targetId: json['targetId'] ?? '',
      reason: json['reason'] ?? '',
      description: json['description'],
      status: json['status'] ?? '',
      createdAt: json['createdAt'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'targetType': targetType,
        'targetId': targetId,
        'reason': reason,
        'description': description,
        'status': status,
        'createdAt': createdAt,
      };
}
