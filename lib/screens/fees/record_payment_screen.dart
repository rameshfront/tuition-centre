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

  // Multi-Month Support
  List<String> _candidateMonths = [];
  List<String> _selectedMonths = [];
  Map<String, double> _monthPaidMap = {};
  Map<String, double> _monthPendingMap = {};

  String get _selectedMonth => _selectedMonths.isNotEmpty
      ? _selectedMonths.first
      : DateFormat('MMMM yyyy').format(DateTime.now());

  String _selectedMethod = AppConstants.paymentMethods.first;

  double _monthlyFee = 0.0;
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

    if (widget.initialMonth != null) {
      _selectedMonths = [widget.initialMonth!];
    }

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
      await _calculateFeesForStudent(targetStudent, initialSelectedMonth: widget.initialMonth);
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _calculateFeesForStudent(Student student, {String? initialSelectedMonth}) async {
    final now = DateTime.now();

    // Determine starting month from feeStartDate or admissionDate
    final startStr = (student.feeStartDate != null && student.feeStartDate!.isNotEmpty)
        ? student.feeStartDate!
        : student.admissionDate;

    DateTime startMonth = DateTime(now.year, now.month - 3, 1);
    if (startStr.isNotEmpty) {
      try {
        final parsed = DateTime.parse(startStr);
        startMonth = DateTime(parsed.year, parsed.month, 1);
      } catch (_) {}
    }

    // Limit to max 24 months back and up to 3 months forward
    final earliest = DateTime(now.year, now.month - 24, 1);
    if (startMonth.isBefore(earliest)) startMonth = earliest;
    final endMonth = DateTime(now.year, now.month + 3, 1);

    final List<String> candidateMonths = [];
    DateTime pointer = startMonth;
    while (!pointer.isAfter(endMonth)) {
      candidateMonths.add(DateFormat('MMMM yyyy').format(pointer));
      pointer = DateTime(pointer.year, pointer.month + 1, 1);
    }

    // Query all existing payments for this student
    final studentPayments = await DBHelper.instance.getPaymentsForStudent(student.id!);
    final Map<String, double> paidMap = {};
    for (final p in studentPayments) {
      paidMap[p.feeMonth] = (paidMap[p.feeMonth] ?? 0.0) + p.amount;
    }

    final Map<String, double> pendingMap = {};
    for (final m in candidateMonths) {
      final paid = paidMap[m] ?? 0.0;
      final pending = (student.monthlyFees - paid) > 0 ? (student.monthlyFees - paid) : 0.0;
      pendingMap[m] = pending;
    }

    final overall = await DBHelper.instance.getStudentFeeSummary(student.id!);

    List<String> selected = [];
    if (initialSelectedMonth != null) {
      selected = [initialSelectedMonth];
      if (!candidateMonths.contains(initialSelectedMonth)) {
        candidateMonths.insert(0, initialSelectedMonth);
      }
    } else {
      final currentMonthStr = DateFormat('MMMM yyyy').format(now);
      final currentIdx = candidateMonths.indexOf(currentMonthStr);
      final pendingUpToNow = candidateMonths.where((m) {
        final idx = candidateMonths.indexOf(m);
        final isPastOrCurrent = currentIdx == -1 || idx <= currentIdx;
        return isPastOrCurrent && (pendingMap[m] ?? 0) > 0;
      }).toList();

      if (pendingUpToNow.isNotEmpty) {
        selected = pendingUpToNow;
      } else {
        selected = [currentMonthStr];
      }
    }

    double totalSelectedPending = 0.0;
    for (final m in selected) {
      totalSelectedPending += (pendingMap[m] ?? student.monthlyFees);
    }

    if (mounted) {
      setState(() {
        _selectedStudent = student;
        _candidateMonths = candidateMonths;
        _monthPaidMap = paidMap;
        _monthPendingMap = pendingMap;
        _selectedMonths = selected;
        _monthlyFee = student.monthlyFees;
        _overallDue = overall['balanceDue'] ?? 0.0;
        _overallTotalPaid = overall['totalPaid'] ?? 0.0;
        _isLoading = false;

        _amountController.text = totalSelectedPending > 0
            ? totalSelectedPending.toStringAsFixed(0)
            : student.monthlyFees.toStringAsFixed(0);
      });
    }
  }

  void _toggleMonthSelection(String month) {
    setState(() {
      if (_selectedMonths.contains(month)) {
        if (_selectedMonths.length > 1) {
          _selectedMonths.remove(month);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('At least one month must be selected for payment.'),
              duration: Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      } else {
        _selectedMonths.add(month);
        // Sort selected months according to candidateMonths chronological order
        _selectedMonths.sort((a, b) => _candidateMonths.indexOf(a).compareTo(_candidateMonths.indexOf(b)));
      }

      // Re-sum total pending for selected months
      double total = 0.0;
      for (final m in _selectedMonths) {
        total += (_monthPendingMap[m] ?? _monthlyFee);
      }
      _amountController.text = total > 0 ? total.toStringAsFixed(0) : _monthlyFee.toStringAsFixed(0);
    });
  }

  void _selectAllPending() {
    final now = DateTime.now();
    final currentMonthStr = DateFormat('MMMM yyyy').format(now);
    final currentIdx = _candidateMonths.indexOf(currentMonthStr);

    final pendingMonths = _candidateMonths.where((m) {
      final idx = _candidateMonths.indexOf(m);
      final isPastOrCurrent = currentIdx == -1 || idx <= currentIdx;
      return isPastOrCurrent && (_monthPendingMap[m] ?? 0) > 0;
    }).toList();

    if (pendingMonths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pending months found! All current dues are cleared.')),
      );
      return;
    }

    setState(() {
      _selectedMonths = pendingMonths;
      double total = 0.0;
      for (final m in _selectedMonths) {
        total += (_monthPendingMap[m] ?? _monthlyFee);
      }
      _amountController.text = total.toStringAsFixed(0);
    });
  }

  void _selectCurrentMonthOnly() {
    final now = DateTime.now();
    final currentMonthStr = DateFormat('MMMM yyyy').format(now);
    setState(() {
      _selectedMonths = [currentMonthStr];
      final pending = _monthPendingMap[currentMonthStr] ?? _monthlyFee;
      _amountController.text = pending > 0 ? pending.toStringAsFixed(0) : _monthlyFee.toStringAsFixed(0);
    });
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

  Future<void> _savePayment() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a student'), backgroundColor: AppColors.warning),
      );
      return;
    }

    if (_selectedMonths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one fee month'), backgroundColor: AppColors.warning),
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
      final receiptNo = _receiptNoController.text.trim();
      final nowStr = DateTime.now().toIso8601String();
      final notesText = _notesController.text.trim();
      final perMonthAmount = enteredAmount / _selectedMonths.length;

      // Insert an individual FeePayment record for each selected month atomically in DB batch
      final List<FeePayment> paymentsToInsert = [];
      for (int i = 0; i < _selectedMonths.length; i++) {
        final m = _selectedMonths[i];
        paymentsToInsert.add(
          FeePayment(
            studentId: _selectedStudent!.id!,
            receiptNo: receiptNo,
            amount: perMonthAmount,
            paymentDate: _paymentDateController.text.trim(),
            feeMonth: m,
            paymentMethod: _selectedMethod,
            notes: _selectedMonths.length > 1
                ? (notesText.isNotEmpty ? '$notesText [Month ${i + 1}/${_selectedMonths.length}]' : 'Multi-month payment [${i + 1}/${_selectedMonths.length}]')
                : (notesText.isNotEmpty ? notesText : null),
            createdAt: nowStr,
            studentName: _selectedStudent!.fullName,
            studentCode: _selectedStudent!.studentId,
            gradeClass: _selectedStudent!.gradeClass,
            studentMonthlyFee: _selectedStudent!.monthlyFees,
          ),
        );
      }

      await DBHelper.instance.insertMultipleFeePayments(paymentsToInsert);

      final combinedMonthString = _selectedMonths.length == 1
          ? _selectedMonths.first
          : '${_selectedMonths.first} - ${_selectedMonths.last} (${_selectedMonths.length} Months)';

      final combinedPaymentForReceipt = FeePayment(
        studentId: _selectedStudent!.id!,
        receiptNo: receiptNo,
        amount: enteredAmount,
        paymentDate: _paymentDateController.text.trim(),
        feeMonth: combinedMonthString,
        paymentMethod: _selectedMethod,
        notes: notesText.isNotEmpty ? notesText : null,
        createdAt: nowStr,
        studentName: _selectedStudent!.fullName,
        studentCode: _selectedStudent!.studentId,
        gradeClass: _selectedStudent!.gradeClass,
        studentMonthlyFee: _selectedStudent!.monthlyFees,
      );

      final remainingFeeSum = await DBHelper.instance.getStudentFeeSummary(_selectedStudent!.id!);
      final overallBalanceRemaining = remainingFeeSum['balanceDue'] ?? 0.0;

      if (mounted) {
        setState(() => _isSaving = false);

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
              'Fee payment of Rs. ${enteredAmount.toStringAsFixed(0)} for ${_selectedStudent!.fullName} for $combinedMonthString recorded successfully.\n\nRemaining pending dues: Rs. ${overallBalanceRemaining.toStringAsFixed(0)}.\n\nWould you like to view/share the official PDF bill receipt?',
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
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FeeReceiptScreen(
                        payment: combinedPaymentForReceipt,
                        student: _selectedStudent!,
                        balanceDue: overallBalanceRemaining,
                      ),
                    ),
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop(true);
                  }
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
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ');
    final enteredAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    double selectedPendingSum = 0.0;
    for (final m in _selectedMonths) {
      selectedPendingSum += (_monthPendingMap[m] ?? _monthlyFee);
    }

    int unpaidMonthsCount = 0;
    for (final m in _candidateMonths) {
      if ((_monthPendingMap[m] ?? 0) > 0) unpaidMonthsCount++;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Record Fee Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Receipt Number Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.lightBlue,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.tag_rounded, color: AppColors.primaryBlue, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Receipt: ${_receiptNoController.text}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryBlue),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('AUTO-GENERATED', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 1. SELECT STUDENT
                    const Text('Select Student *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                          hint: const Text('Choose Student'),
                          icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryBlue),
                          items: _allStudents.map((s) {
                            return DropdownMenuItem<int>(
                              value: s.id,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: AppColors.lightBlue,
                                    child: Text(
                                      s.fullName.isNotEmpty ? s.fullName[0].toUpperCase() : 'S',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${s.fullName} (${s.studentId}) • ${s.gradeClass}',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (id) {
                            if (id != null) {
                              final student = _allStudents.firstWhere((s) => s.id == id);
                              _calculateFeesForStudent(student);
                            }
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 2. MULTI-MONTH FEE SELECTOR
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('Fee Month(s) to Pay *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_selectedMonths.length} Selected',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        if (unpaidMonthsCount > 0)
                          InkWell(
                            onTap: _selectAllPending,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                              child: Text(
                                'Select All Due ($unpaidMonthsCount)',
                                style: const TextStyle(fontSize: 11.5, color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Quick Month Action Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.today_rounded, size: 14, color: AppColors.primaryBlue),
                            label: const Text('Current Month Only', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: AppColors.border),
                            onPressed: _selectCurrentMonthOnly,
                          ),
                          const SizedBox(width: 8),
                          if (unpaidMonthsCount > 1)
                            ActionChip(
                              avatar: const Icon(Icons.checklist_rounded, size: 14, color: Color(0xFFD97706)),
                              label: Text('All $unpaidMonthsCount Due Months', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFD97706))),
                              backgroundColor: const Color(0xFFFFFBEB),
                              side: const BorderSide(color: Color(0xFFFCD34D)),
                              onPressed: _selectAllPending,
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Month Chips List
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tap months to include in this fee bill:',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _candidateMonths.map((m) {
                              final isSelected = _selectedMonths.contains(m);
                              final pending = _monthPendingMap[m] ?? _monthlyFee;
                              final isPaid = pending <= 0;

                              return FilterChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(m, style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? Colors.white : (isPaid ? AppColors.textSecondary : AppColors.textPrimary),
                                    )),
                                    const SizedBox(width: 4),
                                    Text(
                                      isPaid ? '✓' : '(₹${pending.toStringAsFixed(0)})',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? AppColors.primaryYellow
                                            : (isPaid ? AppColors.success : const Color(0xFFD97706)),
                                      ),
                                    ),
                                  ],
                                ),
                                selected: isSelected,
                                selectedColor: AppColors.primaryBlue,
                                backgroundColor: isPaid ? Colors.grey.shade100 : const Color(0xFFFFFBEB),
                                showCheckmark: false,
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.primaryBlue
                                      : (isPaid ? Colors.grey.shade300 : const Color(0xFFFCD34D)),
                                  width: isSelected ? 1.5 : 1,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                onSelected: (_) => _toggleMonthSelection(m),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 3. FEE BREAKDOWN SUMMARY CARD
                    if (_selectedStudent != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
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
                                Expanded(
                                  child: Text(
                                    'Bill for: ${_selectedMonths.join(", ")}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.lightBlue,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${_selectedMonths.length} MO',
                                    style: const TextStyle(color: AppColors.primaryBlue, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _feeSummaryItem(
                                  'Rate / Month',
                                  currency.format(_monthlyFee),
                                  AppColors.textPrimary,
                                ),
                                _feeSummaryItem(
                                  'Selected Due',
                                  currency.format(selectedPendingSum),
                                  AppColors.primaryBlue,
                                ),
                                _feeSummaryItem(
                                  'Overall Due',
                                  currency.format(_overallDue),
                                  _overallDue > 0 ? AppColors.error : AppColors.success,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
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
                              labelText: 'Total Amount (Rs.) *',
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

                    if (enteredAmount > 0 && _selectedMonths.length > 1) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.success),
                            const SizedBox(width: 6),
                            Text(
                              'Rs. ${(enteredAmount / _selectedMonths.length).toStringAsFixed(0)} allocated per month across ${_selectedMonths.length} months.',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
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
                                _selectedMonths.length > 1
                                    ? 'Save Payment of ${currency.format(enteredAmount)} (${_selectedMonths.length} Months)'
                                    : 'Save Payment of ${currency.format(enteredAmount)}',
                                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.white),
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
