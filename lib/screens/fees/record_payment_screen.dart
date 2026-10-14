import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/student.dart';
import '../../models/fee_payment.dart';
import '../../models/centre_profile.dart';
import '../../database/db_helper.dart';
import 'fee_receipt_screen.dart';

class RecordPaymentScreen extends StatefulWidget {
  final Student? initialStudent;
  final String? initialMonth;

  const RecordPaymentScreen({
    super.key,
    this.initialStudent,
    this.initialMonth,
  });

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _receiptNoController;
  late TextEditingController _amountController;
  late TextEditingController _paymentDateController;
  late TextEditingController _notesController;

  CentreProfile _centreProfile = CentreProfile.defaultProfile();
  Student? _selectedStudent;
  List<Student> _allStudents = [];
  late String _selectedMonth;
  String _selectedMethod = AppConstants.paymentMethods.first;

  // Month-specific fee calculation states
  double _monthlyFee = 0.0;
  double _monthPaid = 0.0;
  double _monthPending = 0.0;
  double _overallDue = 0.0;
  double _overallTotalPaid = 0.0;

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

    _selectedMonth = widget.initialMonth ?? DateFormat('MMMM yyyy').format(DateTime.now());

    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final autoReceipt = await DBHelper.instance.generateReceiptNumber();
    final students = await DBHelper.instance.getStudents(onlyActive: true);
    final profile = await DBHelper.instance.getCentreProfile();

    _centreProfile = profile;
    _receiptNoController.text = autoReceipt;

    Student? targetStudent;
    if (widget.initialStudent != null) {
      // Find matching student by ID from the active students list
      try {
        targetStudent = students.firstWhere((s) => s.id == widget.initialStudent!.id);
      } catch (_) {
        targetStudent = widget.initialStudent;
      }
    } else if (students.isNotEmpty) {
      targetStudent = students.first;
    }

    _allStudents = students;
    _selectedStudent = targetStudent;

    if (targetStudent != null) {
      await _calculateFeesForStudentAndMonth(targetStudent, _selectedMonth, isFirstLoad: true);
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _calculateFeesForStudentAndMonth(
    Student student,
    String month, {
    bool isFirstLoad = false,
  }) async {
    final summary = await DBHelper.instance.getStudentMonthlyFeeSummary(student.id!, month);

    if (mounted) {
      final monthlyFee = summary['monthlyFee'] ?? student.monthlyFees;
      final monthPaid = summary['monthPaid'] ?? 0.0;
      final monthPending = summary['monthPending'] ?? 0.0;
      final overallDue = summary['overallBalanceDue'] ?? 0.0;
      final overallTotalPaid = summary['overallTotalPaid'] ?? 0.0;

      setState(() {
        _selectedStudent = student;
        _selectedMonth = month;
        _monthlyFee = monthlyFee;
        _monthPaid = monthPaid;
        _monthPending = monthPending;
        _overallDue = overallDue;
        _overallTotalPaid = overallTotalPaid;
        _isLoading = false;

        // Auto pre-fill amount with the exact pending amount for this selected month!
        if (monthPending > 0) {
          _amountController.text = monthPending.toStringAsFixed(0);
        } else if (monthPaid >= monthlyFee && monthlyFee > 0) {
          _amountController.text = '0';
        } else if (_amountController.text.isEmpty && monthlyFee > 0) {
          _amountController.text = monthlyFee.toStringAsFixed(0);
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
    // Generate past 12 months up to next 6 months
    for (int i = -12; i <= 6; i++) {
      final date = DateTime(now.year, now.month + i, 1);
      months.add(DateFormat('MMMM yyyy').format(date));
    }
    // Make sure currently selected month is included
    if (!months.contains(_selectedMonth)) {
      months.insert(0, _selectedMonth);
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

    final enteredAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (enteredAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid payment amount greater than 0'), backgroundColor: AppColors.warning),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final payment = FeePayment(
        studentId: _selectedStudent!.id!,
        receiptNo: _receiptNoController.text.trim(),
        amount: enteredAmount,
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

        // Calculate remaining balance after this payment
        final remainingForMonth = (_monthPending - enteredAmount) > 0 ? (_monthPending - enteredAmount) : 0.0;

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
              'Fee payment of Rs. ${enteredAmount.toStringAsFixed(0)} for ${_selectedStudent!.fullName} for the month of $_selectedMonth recorded successfully.\n\nRemaining pending for $_selectedMonth: Rs. ${remainingForMonth.toStringAsFixed(0)}.\n\nWould you like to view/share the official PDF bill receipt?',
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
                        balanceDue: remainingForMonth,
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
    final double enteredAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final bool isMonthFullyPaid = _monthPending <= 0 && _monthPaid >= _monthlyFee && _monthlyFee > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          '${_centreProfile.centreName} - Billing',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
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
              // Header Card with Receipt Number
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
                          Text(
                            '${_centreProfile.centreName} - Fee Collection',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryBlue),
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

              // 1. SELECT STUDENT (Rock-solid ID mapping so clicked student is ALWAYS selected)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Select Student *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  if (_selectedStudent != null)
                    Text(
                      'Class: ${_selectedStudent!.gradeClass}',
                      style: const TextStyle(fontSize: 12, color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
              const SizedBox(height: 6),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedStudent?.id,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryBlue),
                    items: _allStudents.map((s) {
                      return DropdownMenuItem<int>(
                        value: s.id,
                        child: Text(
                          '${s.fullName} (${s.studentId} - ${s.gradeClass})',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                    onChanged: (id) {
                      if (id != null) {
                        final student = _allStudents.firstWhere((s) => s.id == id);
                        _calculateFeesForStudentAndMonth(student, _selectedMonth);
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 2. FEE MONTH DROPDOWN (Intelligently changes calculations immediately when changed!)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Fee Month *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(
                    'Viewing: $_selectedMonth',
                    style: const TextStyle(fontSize: 11, color: AppColors.darkYellow, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
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
                    value: _selectedMonth,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryBlue),
                    items: monthOptions.map((m) {
                      return DropdownMenuItem<String>(
                        value: m,
                        child: Text(m, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      );
                    }).toList(),
                    onChanged: (newMonth) {
                      if (newMonth != null && _selectedStudent != null) {
                        _calculateFeesForStudentAndMonth(_selectedStudent!, newMonth);
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // 3. MONTH-SPECIFIC FEE BREAKDOWN CARD (Updates dynamically for selected month!)
              if (_selectedStudent != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isMonthFullyPaid ? AppColors.successLight : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isMonthFullyPaid ? AppColors.success : AppColors.border,
                      width: isMonthFullyPaid ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Fee Status for $_selectedMonth',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          if (isMonthFullyPaid)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'PAID IN FULL',
                                style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _feeSummaryItem(
                            'Monthly Fee',
                            currency.format(_monthlyFee),
                            AppColors.textPrimary,
                          ),
                          _feeSummaryItem(
                            'Paid for Month',
                            currency.format(_monthPaid),
                            AppColors.primaryBlue,
                          ),
                          _feeSummaryItem(
                            'Pending for Month',
                            currency.format(_monthPending),
                            _monthPending > 0 ? AppColors.error : AppColors.success,
                          ),
                        ],
                      ),
                      if (_overallDue > 0 && _overallDue != _monthPending) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.lightYellow,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.darkYellow),
                              const SizedBox(width: 6),
                              Text(
                                'Total pending across all months: ${currency.format(_overallDue)}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.darkYellow),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Quick Fill Shortcut Chips (Full Due, Half, Clear)
              if (_monthPending > 0) ...[
                Row(
                  children: [
                    const Text('Quick Fill: ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    ActionChip(
                      label: Text('Full Due (${currency.format(_monthPending)})'),
                      labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                      backgroundColor: AppColors.lightBlue,
                      padding: const EdgeInsets.all(2),
                      onPressed: () {
                        setState(() {
                          _amountController.text = _monthPending.toStringAsFixed(0);
                        });
                      },
                    ),
                    const SizedBox(width: 6),
                    if (_monthPending >= 200) ...[
                      ActionChip(
                        label: Text('Half (${currency.format(_monthPending / 2)})'),
                        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.darkYellow),
                        backgroundColor: AppColors.lightYellow,
                        padding: const EdgeInsets.all(2),
                        onPressed: () {
                          setState(() {
                            _amountController.text = (_monthPending / 2).toStringAsFixed(0);
                          });
                        },
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
              ],

              // 4. AMOUNT PAID & PAYMENT DATE
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
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

              // Live Balance Preview after this payment
              if (enteredAmount > 0) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.calculate_outlined, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        (_monthPending - enteredAmount) <= 0
                            ? '✅ This payment clears the full fee for $_selectedMonth!'
                            : 'Remaining for $_selectedMonth after this payment: ${currency.format(_monthPending - enteredAmount)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: (_monthPending - enteredAmount) <= 0 ? AppColors.success : AppColors.darkYellow,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // 5. PAYMENT MODE
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

              // 6. NOTES
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Payment Remarks (Optional)',
                  hintText: 'e.g. UPI Ref / GPay Transaction ID / Cheque No',
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

              const SizedBox(height: 28),

              // 7. SAVE BUTTON
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
                      : Text(
                          'Save Payment of ${currency.format(enteredAmount)}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
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
