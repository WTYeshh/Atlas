class CourseModel {
  final String id;
  final String semesterId;
  final String name;
  final double credits;
  final double? gradePoint;
  final bool isCompleted; // true = actual/graded, false = simulation/What-If course

  CourseModel({
    required this.id,
    required this.semesterId,
    required this.name,
    required this.credits,
    this.gradePoint,
    this.isCompleted = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'semester_id': semesterId,
      'name': name,
      'credits': credits,
      'grade_point': gradePoint,
      'is_completed': isCompleted ? 1 : 0,
    };
  }

  factory CourseModel.fromMap(Map<String, dynamic> map) {
    return CourseModel(
      id: map['id'] as String,
      semesterId: map['semester_id'] as String,
      name: map['name'] as String,
      credits: (map['credits'] as num).toDouble(),
      gradePoint: (map['grade_point'] as num?)?.toDouble(),
      isCompleted: (map['is_completed'] as int? ?? 1) == 1,
    );
  }

  CourseModel copyWith({
    String? id,
    String? semesterId,
    String? name,
    double? credits,
    double? gradePoint,
    bool? isCompleted,
  }) {
    return CourseModel(
      id: id ?? this.id,
      semesterId: semesterId ?? this.semesterId,
      name: name ?? this.name,
      credits: credits ?? this.credits,
      gradePoint: gradePoint ?? this.gradePoint,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
