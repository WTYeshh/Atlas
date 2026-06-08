class AttendanceLogModel {
  final String id;
  final String subjectId;
  final String date; // YYYY-MM-DD
  final String status; // 'present', 'absent', 'cancelled'
  final String updatedAt;
  final String? slotId;

  AttendanceLogModel({
    required this.id,
    required this.subjectId,
    required this.date,
    required this.status,
    required this.updatedAt,
    this.slotId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject_id': subjectId,
      'date': date,
      'status': status,
      'updated_at': updatedAt,
      'slot_id': slotId,
    };
  }

  factory AttendanceLogModel.fromMap(Map<String, dynamic> map) {
    return AttendanceLogModel(
      id: map['id'] as String,
      subjectId: map['subject_id'] as String,
      date: map['date'] as String,
      status: map['status'] as String,
      updatedAt: map['updated_at'] as String,
      slotId: map['slot_id'] as String?,
    );
  }

  AttendanceLogModel copyWith({
    String? id,
    String? subjectId,
    String? date,
    String? status,
    String? updatedAt,
    String? slotId,
  }) {
    return AttendanceLogModel(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      date: date ?? this.date,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      slotId: slotId ?? this.slotId,
    );
  }
}
