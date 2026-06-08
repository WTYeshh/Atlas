class EventModel {
  final String id;
  final String title;
  final String date; // YYYY-MM-DD
  final String time; // HH:MM
  final String? description;
  final String? category;
  final int? reminderId;
  final String? googleEventId;
  final String updatedAt;

  EventModel({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    this.description,
    this.category,
    this.reminderId,
    this.googleEventId,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'date': date,
      'time': time,
      'description': description,
      'category': category,
      'reminder_id': reminderId,
      'google_event_id': googleEventId,
      'updated_at': updatedAt,
    };
  }

  factory EventModel.fromMap(Map<String, dynamic> map) {
    return EventModel(
      id: map['id'] as String,
      title: map['title'] as String,
      date: map['date'] as String,
      time: map['time'] as String,
      description: map['description'] as String?,
      category: map['category'] as String?,
      reminderId: map['reminder_id'] as int?,
      googleEventId: map['google_event_id'] as String?,
      updatedAt: map['updated_at'] as String,
    );
  }

  EventModel copyWith({
    String? id,
    String? title,
    String? date,
    String? time,
    String? description,
    String? category,
    int? reminderId,
    String? googleEventId,
    String? updatedAt,
  }) {
    return EventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      time: time ?? this.time,
      description: description ?? this.description,
      category: category ?? this.category,
      reminderId: reminderId ?? this.reminderId,
      googleEventId: googleEventId ?? this.googleEventId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
