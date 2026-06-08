class CourseModel {
  final String id;
  final String semesterId;
  final String name;
  final double credits;
  final double? gradePoint;
  final double? marks;
  final bool isCompleted; // true = actual/graded, false = simulation/What-If course

  CourseModel({
    required this.id,
    required this.semesterId,
    required this.name,
    required this.credits,
    this.gradePoint,
    this.marks,
    this.isCompleted = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'semester_id': semesterId,
      'name': name,
      'credits': credits,
      'grade_point': gradePoint,
      'marks': marks,
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
      marks: (map['marks'] as num?)?.toDouble(),
      isCompleted: (map['is_completed'] as int? ?? 1) == 1,
    );
  }

  CourseModel copyWith({
    String? id,
    String? semesterId,
    String? name,
    double? credits,
    double? gradePoint,
    double? marks,
    bool? isCompleted,
  }) {
    return CourseModel(
      id: id ?? this.id,
      semesterId: semesterId ?? this.semesterId,
      name: name ?? this.name,
      credits: credits ?? this.credits,
      gradePoint: gradePoint ?? this.gradePoint,
      marks: marks ?? this.marks,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  double? get calculatedGradePoint {
    if (marks != null) {
      if (marks! >= 90) return 10.0;
      if (marks! >= 80) return 9.0;
      if (marks! >= 70) return 8.0;
      if (marks! >= 60) return 7.0;
      if (marks! >= 50) return 6.0;
      if (marks! >= 40) return 5.0;
      return 0.0;
    }
    return gradePoint;
  }

  String get calculatedGrade {
    if (marks != null) {
      if (marks! >= 90) return 'S';
      if (marks! >= 80) return 'A';
      if (marks! >= 70) return 'B';
      if (marks! >= 60) return 'C';
      if (marks! >= 50) return 'D';
      if (marks! >= 40) return 'E';
      return 'F';
    }
    if (gradePoint != null) {
      if (gradePoint! >= 10.0) return 'S';
      if (gradePoint! >= 9.0) return 'A';
      if (gradePoint! >= 8.0) return 'B';
      if (gradePoint! >= 7.0) return 'C';
      if (gradePoint! >= 6.0) return 'D';
      if (gradePoint! >= 5.0) return 'E';
      return 'F';
    }
    return 'Ungraded';
  }
}
