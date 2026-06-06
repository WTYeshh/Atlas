class SemesterModel {
  final String id;
  final String name;
  final double? targetGpa;

  SemesterModel({
    required this.id,
    required this.name,
    this.targetGpa,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'target_gpa': targetGpa,
    };
  }

  factory SemesterModel.fromMap(Map<String, dynamic> map) {
    return SemesterModel(
      id: map['id'] as String,
      name: map['name'] as String,
      targetGpa: (map['target_gpa'] as num?)?.toDouble(),
    );
  }

  SemesterModel copyWith({
    String? id,
    String? name,
    double? targetGpa,
  }) {
    return SemesterModel(
      id: id ?? this.id,
      name: name ?? this.name,
      targetGpa: targetGpa ?? this.targetGpa,
    );
  }
}
