class SubjectModel {
  final String id;
  final String name;
  final String? code;
  final double minPercentage;

  SubjectModel({
    required this.id,
    required this.name,
    this.code,
    this.minPercentage = 75.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'min_percentage': minPercentage,
    };
  }

  factory SubjectModel.fromMap(Map<String, dynamic> map) {
    return SubjectModel(
      id: map['id'] as String,
      name: map['name'] as String,
      code: map['code'] as String?,
      minPercentage: (map['min_percentage'] as num?)?.toDouble() ?? 75.0,
    );
  }

  SubjectModel copyWith({
    String? id,
    String? name,
    String? code,
    double? minPercentage,
  }) {
    return SubjectModel(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      minPercentage: minPercentage ?? this.minPercentage,
    );
  }
}
