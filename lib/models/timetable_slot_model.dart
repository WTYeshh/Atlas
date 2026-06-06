class TimetableSlotModel {
  final String id;
  final String subjectId;
  final int dayOfWeek; // 1 = Monday, 7 = Sunday
  final String startTime; // HH:MM
  final String endTime; // HH:MM
  final String? classroom;

  TimetableSlotModel({
    required this.id,
    required this.subjectId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.classroom,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject_id': subjectId,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'classroom': classroom,
    };
  }

  factory TimetableSlotModel.fromMap(Map<String, dynamic> map) {
    return TimetableSlotModel(
      id: map['id'] as String,
      subjectId: map['subject_id'] as String,
      dayOfWeek: map['day_of_week'] as int,
      startTime: map['start_time'] as String,
      endTime: map['end_time'] as String,
      classroom: map['classroom'] as String?,
    );
  }

  TimetableSlotModel copyWith({
    String? id,
    String? subjectId,
    int? dayOfWeek,
    String? startTime,
    String? endTime,
    String? classroom,
  }) {
    return TimetableSlotModel(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      classroom: classroom ?? this.classroom,
    );
  }
}
