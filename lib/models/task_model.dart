class TaskModel {
  final String id;
  final String title;
  final String dueDate; // YYYY-MM-DD
  final String priority; // low, medium, high
  final String? subject;
  final String status; // pending, completed
  final int? reminderId;
  final String updatedAt;
  final int rescheduledCount;

  TaskModel({
    required this.id,
    required this.title,
    required this.dueDate,
    required this.priority,
    this.subject,
    required this.status,
    this.reminderId,
    required this.updatedAt,
    this.rescheduledCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'due_date': dueDate,
      'priority': priority,
      'subject': subject,
      'status': status,
      'reminder_id': reminderId,
      'updated_at': updatedAt,
      'rescheduled_count': rescheduledCount,
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'] as String,
      title: map['title'] as String,
      dueDate: map['due_date'] as String,
      priority: map['priority'] as String,
      subject: map['subject'] as String?,
      status: map['status'] as String,
      reminderId: map['reminder_id'] as int?,
      updatedAt: map['updated_at'] as String,
      rescheduledCount: map['rescheduled_count'] as int? ?? 0,
    );
  }

  TaskModel copyWith({
    String? id,
    String? title,
    String? dueDate,
    String? priority,
    String? subject,
    String? status,
    int? reminderId,
    String? updatedAt,
    int? rescheduledCount,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      subject: subject ?? this.subject,
      status: status ?? this.status,
      reminderId: reminderId ?? this.reminderId,
      updatedAt: updatedAt ?? this.updatedAt,
      rescheduledCount: rescheduledCount ?? this.rescheduledCount,
    );
  }
}

