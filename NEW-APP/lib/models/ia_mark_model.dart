class IaMarkModel {
  final String id;
  final String subjectId;
  final int iaNumber; // 1, 2, or 3
  final double obtained; // raw marks obtained out of 50

  IaMarkModel({
    required this.id,
    required this.subjectId,
    required this.iaNumber,
    required this.obtained,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject_id': subjectId,
      'ia_number': iaNumber,
      'obtained': obtained,
    };
  }

  factory IaMarkModel.fromMap(Map<String, dynamic> map) {
    return IaMarkModel(
      id: map['id'] as String,
      subjectId: map['subject_id'] as String,
      iaNumber: map['ia_number'] as int,
      obtained: (map['obtained'] as num).toDouble(),
    );
  }

  IaMarkModel copyWith({
    String? id,
    String? subjectId,
    int? iaNumber,
    double? obtained,
  }) {
    return IaMarkModel(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      iaNumber: iaNumber ?? this.iaNumber,
      obtained: obtained ?? this.obtained,
    );
  }
}
