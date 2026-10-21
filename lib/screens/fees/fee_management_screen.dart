import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/student.dart';
import '../../models/fee_payment.dart';
import '../../database/db_helper.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/confirm_dialog.dart';
import '../../services/pdf_service.dart';
import 'record_payment_screen.dart';
import 'fee_receipt_screen.dart';

class FeeManagementScreen extends StatefulWidget {
  const FeeManagementScreen({super.key});

  @override
  State<FeeManagementScreen> createState() => _FeeManagementScreenState();
}

class _FeeManagementScreenState extends State<FeeManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<FeePayment> _payments = [];
  List<Map<String, dynamic>> _pendingStudents = [];

  String _selectedMonth = 'All Months';
  double _totalCollected = 0.0;
  double _totalPending = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFeesData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFeesData() async {
    if (_payments.isEmpty && _pendingStudents.isEmpty) {
      setState(() => _isLoading = true);
    }

    // High-speed parallel query execution
    final results = await Future.wait([
      DBHelper.instance.getAllPayments(
        month: _selectedMonth,
        query: _searchController.text.trim(),
      ),
      DBHelper.instance.getPendingStudentsOverview(),
    ]);

    final paymentsList = results[0] as List<FeePayment>;
    final pendingList = List<Map<String, dynamic>>.from(results[1] as List);

    // Apply search filter to pending students if query is present
    final query = _searchController.text.trim().toLowerCase();
    List<Map<String, dynamic>> filteredPending = pendingList;
    if (query.isNotEmpty) {
      filteredPending = pendingList.where((p) {
        final name = (p['name'] as String? ?? '').toLowerCase();
        final code = (p['student_id'] as String? ?? '').toLowerCase();
        final mob = (p['mobile'] as String? ?? '').toLowerCase();
        return name.contains(query) || code.contains(query) || mob.contains(query);
      }).toList();
    }

    // Sort pending by highest dues first
    filteredPending.sort((a, b) => (b['balance'] as double).compareTo(a['balance'] as double));

    double totalDueAcrossAll = pendingList.fold(0.0, (sum, p) => sum + ((p['balance'] as num?)?.toDouble() ?? 0.0));
    double collectedSum = paymentsList.fold(0.0, (sum, p) => sum + p.amount);

    if (mounted) {
      setState(() {
        _payments = paymentsList;
        _pendingStudents = filteredPending;
        _totalCollected = collectedSum;
        _totalPending = totalDueAcrossAll;
        _isLoading = false;
      });
    }
  }

  Future<void> _exportFeesReport() async {
    final pdfBytes = await PdfService.generateFeesReport(
      paymentList: _payments,
      pendingStudentsList: _pendingStudents,
      month: _selectedMonth,
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'Fee_Report_${_selectedMonth.replaceAll(" ", "_")}.pdf',
    );
  }

  Future<void> _deletePayment(FeePayment p) async {
    final confirm = await ConfirmDialog.show(
      context: context,
      title: 'Delete Fee Receipt?',
      message: 'Are you sure you want to delete receipt ${p.receiptNo} of Rs. ${p.amount.toStringAsFixed(0)}?',
      confirmText: 'Delete',
      isDanger: true,
    );

    if (confirm) {
      await DBHelper.instance.deleteFeePayment(p.id!);
      _loadFeesData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment deleted'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _showEditPaymentModal(FeePayment p) async {
    final amountController = TextEditingController(text: p.amount.toStringAsFixed(0));
    final dateController = TextEditingController(text: p.paymentDate);
    final notesController = TextEditingController(text: p.notes ?? '');
    String selectedMonth = p.feeMonth;
    String selectedMethod = p.paymentMethod;

    final now = DateTime.now();
    final List<String> monthOptions = [];
    for (int i = -12; i <= 6; i++) {
      final d = DateTime(now.year, now.month + i, 1);
      final mStr = DateFormat('MMMM yyyy').format(d);
      if (!monthOptions.contains(mStr)) monthOptions.add(mStr);
    }
    if (!monthOptions.contains(selectedMonth)) {
      monthOptions.insert(0, selectedMonth);
    }

    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.lightBlue,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.edit_note_rounded, color: AppColors.primaryBlue, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Edit Fee Payment',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                                  ),
                                  Text(
                                    '${p.studentName ?? "Student"}  •  Receipt #${p.receiptNo}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        TextFormField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Amount Paid (Rs.) *',
                            prefixIcon: const Icon(Icons.currency_rupee_rounded, color: AppColors.primaryBlue),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: AppColors.background,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Enter amount';
                            if (double.tryParse(val) == null || double.parse(val) <= 0) return 'Enter valid amount';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: selectedMonth,
                          decoration: InputDecoration(
                            labelText: 'Fee Month *',
                            prefixIcon: const Icon(Icons.calendar_month_rounded, color: AppColors.primaryBlue),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: AppColors.background,
                          ),
                          items: monthOptions.map((m) {
                            return DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13)));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedMonth = val);
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: dateController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Payment Date *',
                            prefixIcon: const Icon(Icons.event_rounded, color: AppColors.primaryBlue),
                            suffixIcon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryBlue),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: AppColors.background,
                          ),
                          onTap: () async {
                            DateTime initial = DateTime.now();
                            try {
                              initial = DateTime.parse(dateController.text);
                            } catch (_) {}
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: initial,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 30)),
                            );
                            if (picked != null) {
                              setModalState(() {
                                dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: AppConstants.paymentMethods.contains(selectedMethod)
                              ? selectedMethod
                              : AppConstants.paymentMethods.first,
                          decoration: InputDecoration(
                            labelText: 'Payment Method *',
                            prefixIcon: const Icon(Icons.payment_rounded, color: AppColors.primaryBlue),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: AppColors.background,
                          ),
                          items: AppConstants.paymentMethods.map((m) {
                            return DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13)));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedMethod = val);
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: notesController,
                          decoration: InputDecoration(
                            labelText: 'Payment Remarks (Optional)',
                            hintText: 'e.g. UPI Ref / GPay Transaction ID',
                            prefixIcon: const Icon(Icons.notes_rounded, color: AppColors.primaryBlue),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: AppColors.background,
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;
                              final newAmount = double.parse(amountController.text.trim());
                              final updated = FeePayment(
                                id: p.id,
                                studentId: p.studentId,
                                receiptNo: p.receiptNo,
                                amount: newAmount,
                                paymentDate: dateController.text.trim(),
                                feeMonth: selectedMonth,
                                paymentMethod: selectedMethod,
                                notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                                createdAt: p.createdAt,
                                studentName: p.studentName,
                                studentIdCode: p.studentIdCode,
                                gradeClass: p.gradeClass,
                                monthlyFees: p.monthlyFees,
                              );

                              await DBHelper.instance.updateFeePayment(updated);
                              if (context.mounted) Navigator.pop(context);
                              _loadFeesData();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Payment #${p.receiptNo} updated successfully!'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                            label: const Text('Update Payment', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showShareBillOptions(FeePayment p) async {
    final student = await DBHelper.instance.getStudentById(p.studentId);
    if (student == null) return;
    final summary = await DBHelper.instance.getStudentFeeSummary(student.id!);
    final balanceDue = summary['balanceDue'] ?? 0.0;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Share Receipt #${p.receiptNo}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              Text(
                '${student.fullName} • ${p.feeMonth} • Rs. ${p.amount.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.lightYellow.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryYellow.withOpacity(0.5)),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryYellow.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.image_rounded, color: AppColors.darkYellow),
                  ),
                  title: const Row(
                    children: [
                      Text('Share as Image (PNG)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      SizedBox(width: 6),
                      Text(
                        '★ WhatsApp Friendly',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                      ),
                    ],
                  ),
                  subtitle: const Text('Direct image preview for WhatsApp sharing with parents', style: TextStyle(fontSize: 11)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final file = await PdfService.saveReceiptToFile(
                      payment: p,
                      student: student,
                      totalBalanceDue: balanceDue,
                      asImage: true,
                    );
                    await Share.shareXFiles(
                      [XFile(file.path)],
                      subject: 'Fee Receipt #${p.receiptNo} - ${student.fullName}',
                      text: 'Fee Receipt for ${student.fullName} (${p.feeMonth}) - Rs. ${p.amount.toStringAsFixed(0)}. Receipt #${p.receiptNo}.',
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.lightBlue.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primaryBlue),
                  ),
                  title: const Text('Share as PDF Document', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Official printable PDF bill', style: TextStyle(fontSize: 11)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final file = await PdfService.saveReceiptToFile(
                      payment: p,
                      student: student,
                      totalBalanceDue: balanceDue,
                      asImage: false,
                    );
                    await Share.shareXFiles(
                      [XFile(file.path)],
                      subject: 'Fee Receipt #${p.receiptNo} - ${student.fullName}',
                      text: 'Official Fee Receipt PDF for ${student.fullName} (${p.feeMonth}) - Rs. ${p.amount.toStringAsFixed(0)}.',
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Fees Management', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
            tooltip: 'Export Fee Report PDF',
            onPressed: _exportFeesReport,
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Summary Banner
          Container(
            color: AppColors.primaryBlue,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Collected', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(
                          currency.format(_totalCollected),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pending Dues', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(
                          currency.format(_totalPending),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.error),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primaryBlue,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primaryYellow,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: [
                Tab(text: 'Pending Dues (${_pendingStudents.length})'),
                Tab(text: 'Payment History (${_payments.length})'),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPendingDuesTab(currency),
                      _buildPaymentHistoryTab(currency),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final res = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RecordPaymentScreen()),
          );
          if (res == true) _loadFeesData();
        },
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add_card_rounded, color: Colors.white),
        label: const Text('Record Payment', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  // ==========================================
  // TAB 1: PENDING DUES
  // ==========================================
  Widget _buildPendingDuesTab(NumberFormat currency) {
    if (_pendingStudents.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.check_circle_outline_rounded,
        title: 'All Fees Cleared!',
        message: 'Great news! No student has pending tuition fee dues right now.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _pendingStudents.length,
      itemBuilder: (context, index) {
        final item = _pendingStudents[index];
        final Student student = item['student'] as Student;
        final balance = item['balance'] as double;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.errorLight,
                  child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.fullName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${student.studentId}  •  ${student.gradeClass}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      Text(
                        'Parent: ${student.parentName} (${student.mobile})',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currency.format(balance),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ElevatedButton(
                      onPressed: () async {
                        final res = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RecordPaymentScreen(
                              initialStudent: student,
                              initialMonth: _selectedMonth != 'All Months'
                                  ? _selectedMonth
                                  : DateFormat('MMMM yyyy').format(DateTime.now()),
                            ),
                          ),
                        );
                        if (res == true) _loadFeesData();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text('Collect', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // TAB 2: PAYMENT HISTORY
  // ==========================================
  Widget _buildPaymentHistoryTab(NumberFormat currency) {
    return Column(
      children: [
        // Search & Filter
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => _loadFeesData(),
            decoration: InputDecoration(
              hintText: 'Search by student name or receipt no...',
              hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.primaryBlue),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        _loadFeesData();
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ),

        Expanded(
          child: _payments.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.receipt_long_rounded,
                  title: 'No Payments Found',
                  message: 'No fee receipts match your search.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _payments.length,
                  itemBuilder: (context, index) {
                    final p = _payments[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: InkWell(
                        onTap: () async {
                          final student = await DBHelper.instance.getStudentById(p.studentId);
                          if (student != null && context.mounted) {
                            final sum = await DBHelper.instance.getStudentFeeSummary(student.id!);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FeeReceiptScreen(
                                  payment: p,
                                  student: student,
                                  balanceDue: sum['balanceDue'] ?? 0.0,
                                ),
                              ),
                            ).then((_) => _loadFeesData());
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.lightBlue,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.receipt_rounded, color: AppColors.primaryBlue, size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.studentName ?? 'Student',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${p.receiptNo}  •  ${p.feeMonth}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                        Text(
                                          '${p.paymentMethod}  •  ${p.paymentDate}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    currency.format(p.amount),
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // 1. Edit Payment Button
                                  TextButton.icon(
                                    onPressed: () => _showEditPaymentModal(p),
                                    icon: const Icon(Icons.edit_outlined, size: 15),
                                    label: const Text('Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.primaryBlue,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                    ),
                                  ),
                                  const SizedBox(width: 6),

                                  // 2. Share Bill Button
                                  TextButton.icon(
                                    onPressed: () => _showShareBillOptions(p),
                                    icon: const Icon(Icons.share_outlined, size: 15),
                                    label: const Text('Share', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.darkYellow,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                    ),
                                  ),
                                  const SizedBox(width: 6),

                                  // 3. Bill Preview Button
                                  TextButton.icon(
                                    onPressed: () async {
                                      final student = await DBHelper.instance.getStudentById(p.studentId);
                                      if (student != null && context.mounted) {
                                        final sum = await DBHelper.instance.getStudentFeeSummary(student.id!);
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => FeeReceiptScreen(
                                              payment: p,
                                              student: student,
                                              balanceDue: sum['balanceDue'] ?? 0.0,
                                            ),
                                          ),
                                        ).then((_) => _loadFeesData());
                                      }
                                    },
                                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 15),
                                    label: const Text('Bill', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.primaryBlue,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                    ),
                                  ),
                                  const SizedBox(width: 6),

                                  // 4. Delete Button
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Delete Receipt',
                                    onPressed: () => _deletePayment(p),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
