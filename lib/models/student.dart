class Student {
  final int? id;
  final String studentId; // Unique admission / ID number like STU-001
  final String fullName;
  final String? photoPath;
  final String dob; // yyyy-MM-dd
  final String gender; // Male, Female, Other
  final String parentName;
  final String mobile;
  final String? address;
  final String gradeClass;
  final String? schoolName;
  final String subjects; // Comma separated string e.g. "Maths, Science"
  final String admissionDate; // yyyy-MM-dd
  final double monthlyFees;
  final String? notes;
  final bool isActive;
  final String createdAt;

  Student({
    this.id,
    required this.studentId,
    required this.fullName,
    this.photoPath,
    required this.dob,
    required this.gender,
    required this.parentName,
    required this.mobile,
    this.address,
    required this.gradeClass,
    this.schoolName,
    required this.subjects,
    required this.admissionDate,
    required this.monthlyFees,
    this.notes,
    this.isActive = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'full_name': fullName,
      'photo_path': photoPath,
      'dob': dob,
      'gender': gender,
      'parent_name': parentName,
      'mobile': mobile,
      'address': address,
      'grade_class': gradeClass,
      'school_name': schoolName,
      'subjects': subjects,
      'admission_date': admissionDate,
      'monthly_fees': monthlyFees,
      'notes': notes,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
    };
  }

  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'] as int?,
      studentId: map['student_id'] as String? ?? '',
      fullName: map['full_name'] as String? ?? '',
      photoPath: map['photo_path'] as String?,
      dob: map['dob'] as String? ?? '',
      gender: map['gender'] as String? ?? 'Male',
      parentName: map['parent_name'] as String? ?? '',
      mobile: map['mobile'] as String? ?? '',
      address: map['address'] as String?,
      gradeClass: map['grade_class'] as String? ?? '',
      schoolName: map['school_name'] as String?,
      subjects: map['subjects'] as String? ?? '',
      admissionDate: map['admission_date'] as String? ?? '',
      monthlyFees: (map['monthly_fees'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  Student copyWith({
    int? id,
    String? studentId,
    String? fullName,
    String? photoPath,
    String? dob,
    String? gender,
    String? parentName,
    String? mobile,
    String? address,
    String? gradeClass,
    String? schoolName,
    String? subjects,
    String? admissionDate,
    double? monthlyFees,
    String? notes,
    bool? isActive,
    String? createdAt,
  }) {
    return Student(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      fullName: fullName ?? this.fullName,
      photoPath: photoPath ?? this.photoPath,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      parentName: parentName ?? this.parentName,
      mobile: mobile ?? this.mobile,
      address: address ?? this.address,
      gradeClass: gradeClass ?? this.gradeClass,
      schoolName: schoolName ?? this.schoolName,
      subjects: subjects ?? this.subjects,
      admissionDate: admissionDate ?? this.admissionDate,
      monthlyFees: monthlyFees ?? this.monthlyFees,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
