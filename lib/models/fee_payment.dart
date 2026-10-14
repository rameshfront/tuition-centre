class FeePayment {
  final int? id;
  final int studentId;
  final String receiptNo;
  final double amount;
  final String paymentDate; // yyyy-MM-dd
  final String feeMonth; // e.g. "October 2026"
  final String paymentMethod; // Cash, UPI, etc.
  final String? notes;
  final String createdAt;

  // Joined fields for display
  final String? studentName;
  final String? studentCode;
  final String? gradeClass;
  final double? studentMonthlyFee;

  FeePayment({
    this.id,
    required this.studentId,
    required this.receiptNo,
    required this.amount,
    required this.paymentDate,
    required this.feeMonth,
    required this.paymentMethod,
    this.notes,
    required this.createdAt,
    this.studentName,
    this.studentCode,
    this.gradeClass,
    this.studentMonthlyFee,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'receipt_no': receiptNo,
      'amount': amount,
      'payment_date': paymentDate,
      'fee_month': feeMonth,
      'payment_method': paymentMethod,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  factory FeePayment.fromMap(Map<String, dynamic> map) {
    return FeePayment(
      id: map['id'] as int?,
      studentId: map['student_id'] as int,
      receiptNo: map['receipt_no'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      paymentDate: map['payment_date'] as String? ?? '',
      feeMonth: map['fee_month'] as String? ?? '',
      paymentMethod: map['payment_method'] as String? ?? 'Cash',
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      studentName: map['full_name'] as String?,
      studentCode: map['student_id_code'] as String? ?? map['student_id'] as String?,
      gradeClass: map['grade_class'] as String?,
      studentMonthlyFee: (map['monthly_fees'] as num?)?.toDouble(),
    );
  }
}
