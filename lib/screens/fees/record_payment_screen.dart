import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/student.dart';
import '../../models/fee_payment.dart';
import '../../database/db_helper.dart';
import 'fee_receipt_screen.dart';

class RecordPaymentScreen extends StatefulWidget {
  final Student? initialStudent;

  const RecordPaymentScreen({super.key, this.initialStudent});

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _receiptNoController;
  late TextEditingController _amountController;
  late TextEditingController _paymentDateController;
  late TextEditingController _notesController;

  Student? _selectedStudent;
  List<Student> _allStudents = [];
  String _selectedMonth = DateFormat('MMMM yyyy').format(DateTime.now());
  String _selectedMethod = AppConstants.paymentMethods.first;

  Map<String, double> _currentFeeSummary = {'totalPaid': 0.0, 'monthlyFee': 0.0, 'balanceDue': 0.0};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _receiptNoController = TextEditingController();
    _amountController = TextEditingController();
    _paymentDateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    _notesController = TextEditingController();

    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final autoReceipt = await DBHelper.instance.generateReceiptNumber();
    final students = await DBHelper.instance.getStudents(onlyActive: true);

    _receiptNoController.text = autoReceipt;

    Student? defaultStudent;
    if (widget.initialStudent != null) {
      defaultStudent = widget.initialStudent;
    } else if (students.isNotEmpty) {
      defaultStudent = students.first;
    }

    if (mounted) {
      setState(() {
        _allStudents = students;
        _selectedStudent = defaultStudent;
        _isLoading = false;
      });
      if (defaultStudent != null) {
        _onStudentSelected(defaultStudent);
      }
    }
  }

  Future<void> _onStudentSelected(Student student) async {
    final summary = await DBHelper.instance.getStudentFeeSummary(student.id!);
    if (mounted) {
      setState(() {
        _selectedStudent = student;
        _currentFeeSummary = summary;
        // Pre-fill amount with monthly fee or balance if positive
        if (_amountController.text.isEmpty) {
          _amountController.text = student.monthlyFees > 0
              ? student.monthlyFees.toStringAsFixed(0)
              : '';
        }
      });
    }
  }

  @override
  void dispose() {
    _receiptNoController.dispose();
    _amountController.dispose();
    _paymentDateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickPaymentDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _paymentDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  List<String> _generateMonthOptions() {
    final now = DateTime.now();
    final List<String> months = [];
    for (int i = -3; i <= 3; i++) {
      final date = DateTime(now.year, now.month + i, 1);
      months.add(DateFormat('MMMM yyyy').format(date));
    }
    return months;
  }

  Future<void> _savePayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a student'), backgroundColor: AppColors.warning),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final amount = double.parse(_amountController.text.trim());
      final payment = FeePayment(
        studentId: _selectedStudent!.id!,
        receiptNo: _receiptNoController.text.trim(),
        amount: amount,
        paymentDate: _paymentDateController.text.trim(),
        feeMonth: _selectedMonth,
        paymentMethod: _selectedMethod,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        createdAt: DateTime.now().toIso8601String(),
        studentName: _selectedStudent!.fullName,
        studentCode: _selectedStudent!.studentId,
        gradeClass: _selectedStudent!.gradeClass,
      );

      await DBHelper.instance.insertFeePayment(payment);

      if (mounted) {
        setState(() => _isSaving = false);

        // Calculate updated remaining balance
        final newBalance = (_currentFeeSummary['balanceDue'] ?? 0) - amount;
        final updatedBalance = newBalance > 0 ? newBalance : 0.0;

        // Show dialog asking to view or share receipt
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
                SizedBox(width: 10),
                Text('Payment Recorded!'),
              ],
            ),
            content: Text(
              'Fee payment of Rs. ${amount.toStringAsFixed(0)} for ${_selectedStudent!.fullName} recorded successfully.\n\nWould you like to view/share the official PDF bill receipt?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop(true);
                },
                child: const Text('Later', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => FeeReceiptScreen(
                        payment: payment,
                        student: _selectedStudent!,
                        balanceDue: updatedBalance,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                label: const Text('View PDF Bill'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving payment: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
      );
    }

    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ');
    final monthOptions = _generateMonthOptions();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Record Fee Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: AppColors.primaryBlue, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tuition Fee Collection Entry',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryBlue),
                          ),
                          Text(
                            'Receipt #${_receiptNoController.text}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),
              const Text('Select Student *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),

              // Student Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Student>(
                    value: _selectedStudent,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryBlue),
                    items: _allStudents.map((s) {
                      return DropdownMenuItem<Student>(
                        value: s,
                        child: Text(
                          '${s.fullName} (${s.studentId} - ${s.gradeClass})',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) _onStudentSelected(val);
                    },
                  ),
                ),
              ),

              // Current Balance Info Card
              if (_selectedStudent != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _feeSummaryItem('Monthly Fee', currency.format(_selectedStudent!.monthlyFees), AppColors.textPrimary),
                      _feeSummaryItem('Paid Till Now', currency.format(_currentFeeSummary['totalPaid'] ?? 0), AppColors.primaryBlue),
                      _feeSummaryItem(
                        'Pending Due',
                        currency.format(_currentFeeSummary['balanceDue'] ?? 0),
                        (_currentFeeSummary['balanceDue'] ?? 0) > 0 ? AppColors.error : AppColors.success,
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // Fee Month Selector
              const Text('Fee Month *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: monthOptions.contains(_selectedMonth) ? _selectedMonth : monthOptions.first,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryBlue),
                    items: monthOptions.map((m) {
                      return DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13)));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedMonth = val);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Amount & Date
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Enter amount';
                        final num = double.tryParse(val);
                        if (num == null || num <= 0) return 'Invalid amount';
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Amount Paid (Rs.) *',
                        prefixIcon: const Icon(Icons.currency_rupee_rounded, color: AppColors.primaryBlue, size: 20),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: TextFormField(
                      controller: _paymentDateController,
                      readOnly: true,
                      onTap: _pickPaymentDate,
                      decoration: InputDecoration(
                        labelText: 'Payment Date',
                        prefixIcon: const Icon(Icons.calendar_today_rounded, color: AppColors.primaryBlue, size: 18),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Payment Method Selector
              const Text('Payment Mode *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppConstants.paymentMethods.map((mode) {
                  final isSelected = _selectedMethod == mode;
                  return ChoiceChip(
                    label: Text(mode),
                    selected: isSelected,
                    selectedColor: AppColors.primaryBlue,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedMethod = mode);
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Payment Remarks (Optional)',
                  hintText: 'e.g. UPI Ref / Cheque No / Advance',
                  prefixIcon: const Icon(Icons.notes_rounded, color: AppColors.primaryBlue, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _savePayment,
                  icon: _isSaving
                      ? const SizedBox.shrink()
                      : const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                  label: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Save Payment & Generate Bill',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _feeSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}
