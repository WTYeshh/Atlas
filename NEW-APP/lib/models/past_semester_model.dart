class PastSemesterModel {
  final String id;
  final String name;
  final String startDate;
  final String endDate;
  final String compiledJson;

  PastSemesterModel({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.compiledJson,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'start_date': startDate,
      'end_date': endDate,
      'compiled_json': compiledJson,
    };
  }

  factory PastSemesterModel.fromMap(Map<String, dynamic> map) {
    return PastSemesterModel(
      id: map['id'] as String,
      name: map['name'] as String,
      startDate: map['start_date'] as String,
      endDate: map['end_date'] as String,
      compiledJson: map['compiled_json'] as String,
    );
  }
}
