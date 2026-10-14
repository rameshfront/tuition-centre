class Attendance {
  final int? id;
  final int studentId;
  final String date; // yyyy-MM-dd
  final String status; // Present, Absent, Leave
  final String? notes;
  final String createdAt;

  // Joined fields for display convenience
  final String? studentName;
  final String? studentCode;
  final String? gradeClass;

  Attendance({
    this.id,
    required this.studentId,
    required this.date,
    required this.status,
    this.notes,
    required this.createdAt,
    this.studentName,
    this.studentCode,
    this.gradeClass,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'date': date,
      'status': status,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  factory Attendance.fromMap(Map<String, dynamic> map) {
    return Attendance(
      id: map['id'] as int?,
      studentId: map['student_id'] as int,
      date: map['date'] as String? ?? '',
      status: map['status'] as String? ?? 'Present',
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      studentName: map['full_name'] as String?,
      studentCode: map['student_code_str'] as String? ?? map['student_id_str'] as String?,
      gradeClass: map['grade_class'] as String?,
    );
  }
}
