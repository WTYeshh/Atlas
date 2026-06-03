class NoteModel {
  final String id;
  final String title;
  final String? content;
  final String type; // text, pdf, image, doc
  final String? subject;
  final String? category;
  final String? summary;
  final String? filePath;
  final String? driveFileId;
  final String updatedAt;
  final List<String> tags;

  NoteModel({
    required this.id,
    required this.title,
    this.content,
    required this.type,
    this.subject,
    this.category,
    this.summary,
    this.filePath,
    this.driveFileId,
    required this.updatedAt,
    this.tags = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'type': type,
      'subject': subject,
      'category': category,
      'summary': summary,
      'file_path': filePath,
      'drive_file_id': driveFileId,
      'updated_at': updatedAt,
    };
  }

  factory NoteModel.fromMap(Map<String, dynamic> map, {List<String> tags = const []}) {
    return NoteModel(
      id: map['id'] as String,
      title: map['title'] as String,
      content: map['content'] as String?,
      type: map['type'] as String,
      subject: map['subject'] as String?,
      category: map['category'] as String?,
      summary: map['summary'] as String?,
      filePath: map['file_path'] as String?,
      driveFileId: map['drive_file_id'] as String?,
      updatedAt: map['updated_at'] as String,
      tags: tags,
    );
  }

  NoteModel copyWith({
    String? id,
    String? title,
    String? content,
    String? type,
    String? subject,
    String? category,
    String? summary,
    String? filePath,
    String? driveFileId,
    String? updatedAt,
    List<String>? tags,
  }) {
    return NoteModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      subject: subject ?? this.subject,
      category: category ?? this.category,
      summary: summary ?? this.summary,
      filePath: filePath ?? this.filePath,
      driveFileId: driveFileId ?? this.driveFileId,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
    );
  }
}
