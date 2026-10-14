import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../constants/app_colors.dart';
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
    setState(() => _isLoading = true);

    // 1. Fetch payments with search/filter
    final paymentsList = await DBHelper.instance.getAllPayments(
      month: _selectedMonth,
      query: _searchController.text.trim(),
    );

    // 2. Fetch all active students and calculate dues
    final activeStudents = await DBHelper.instance.getStudents(onlyActive: true);
    final List<Map<String, dynamic>> pendingList = [];
    double totalDueAcrossAll = 0.0;

    for (var s in activeStudents) {
      final summary = await DBHelper.instance.getStudentFeeSummary(s.id!);
      final balance = summary['balanceDue'] ?? 0.0;
      if (balance > 0) {
        totalDueAcrossAll += balance;
        pendingList.add({
          'student': s,
          'student_id': s.studentId,
          'name': s.fullName,
          'class': s.gradeClass,
          'mobile': s.mobile,
          'balance': balance,
          'monthlyFee': s.monthlyFees,
          'totalPaid': summary['totalPaid'] ?? 0.0,
        });
      }
    }

    // Sort pending by highest dues first
    pendingList.sort((a, b) => (b['balance'] as double).compareTo(a['balance'] as double));

    double collectedSum = paymentsList.fold(0.0, (sum, p) => sum + p.amount);

    if (mounted) {
      setState(() {
        _payments = paymentsList;
        _pendingStudents = pendingList;
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
                            builder: (_) => RecordPaymentScreen(initialStudent: student),
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
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
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
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  currency.format(p.amount),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.print_rounded, size: 18, color: AppColors.primaryBlue),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Print / Share Receipt',
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
                                          );
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 10),
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
                          ],
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
