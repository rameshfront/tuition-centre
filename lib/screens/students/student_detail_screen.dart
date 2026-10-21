import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/student.dart';
import '../../models/attendance.dart';
import '../../models/fee_payment.dart';
import '../../database/db_helper.dart';
import '../../widgets/confirm_dialog.dart';
import '../../services/pdf_service.dart';
import 'student_form_screen.dart';
import '../fees/record_payment_screen.dart';
import '../fees/fee_receipt_screen.dart';

class StudentDetailScreen extends StatefulWidget {
  final int studentId;

  const StudentDetailScreen({super.key, required this.studentId});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Student? _student;
  List<Attendance> _attendanceList = [];
  List<FeePayment> _paymentList = [];
  Map<String, double> _feeSummary = {'totalPaid': 0.0, 'monthlyFee': 0.0, 'balanceDue': 0.0};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    final s = await DBHelper.instance.getStudentById(widget.studentId);
    if (s != null) {
      final att = await DBHelper.instance.getAttendanceForStudent(widget.studentId);
      final pays = await DBHelper.instance.getPaymentsForStudent(widget.studentId);
      final feeSum = await DBHelper.instance.getStudentFeeSummary(widget.studentId);

      if (mounted) {
        setState(() {
          _student = s;
          _attendanceList = att;
          _paymentList = pays;
          _feeSummary = feeSum;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _toggleActiveStatus() async {
    if (_student == null) return;
    final newStatus = !_student!.isActive;
    final confirm = await ConfirmDialog.show(
      context: context,
      title: newStatus ? 'Activate Student' : 'Deactivate Student',
      message: newStatus
          ? 'Are you sure you want to activate ${_student!.fullName}? They will appear in daily attendance.'
          : 'Deactivating will hide ${_student!.fullName} from regular attendance, but keeps all attendance & fee history safe.',
      confirmText: newStatus ? 'Activate' : 'Deactivate',
      isDanger: !newStatus,
    );

    if (confirm) {
      await DBHelper.instance.toggleStudentActiveStatus(_student!.id!, newStatus);
      _loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus ? 'Student activated' : 'Student deactivated'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _deleteStudent() async {
    if (_student == null) return;
    final confirm = await ConfirmDialog.show(
      context: context,
      title: 'Delete Student Record?',
      message: 'Warning: This will permanently delete ${_student!.fullName} and all their attendance and fee records. Alternatively, you can Deactivate the student to preserve records.',
      confirmText: 'Delete Permanently',
      isDanger: true,
    );

    if (confirm) {
      await DBHelper.instance.deleteStudent(_student!.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student deleted'), backgroundColor: AppColors.error),
        );
        Navigator.of(context).pop(true);
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

    if (_student == null) {
      return const Scaffold(
        body: Center(child: Text('Student not found')),
      );
    }

    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_student!.fullName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Student',
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => StudentFormScreen(studentToEdit: _student)),
              );
              if (result == true) _loadAllData();
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (val) {
              if (val == 'toggle_active') _toggleActiveStatus();
              if (val == 'delete') _deleteStudent();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle_active',
                child: Row(
                  children: [
                    Icon(
                      _student!.isActive ? Icons.person_off_outlined : Icons.person_add_alt_1_outlined,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(_student!.isActive ? 'Deactivate Student' : 'Activate Student'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                    SizedBox(width: 10),
                    Text('Delete Record', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Profile Card
          Container(
            color: AppColors.primaryBlue,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: _student!.gender == 'Female'
                        ? const Color(0xFFFCE7F3)
                        : AppColors.lightBlue,
                    child: Text(
                      _student!.fullName.isNotEmpty ? _student!.fullName[0].toUpperCase() : 'S',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: _student!.gender == 'Female' ? const Color(0xFFDB2777) : AppColors.primaryBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _student!.fullName,
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _student!.isActive ? AppColors.successLight : AppColors.errorLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _student!.isActive ? 'Active' : 'Inactive',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _student!.isActive ? AppColors.success : AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_student!.studentId}  •  ${_student!.gradeClass}',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                        ),
                        if (_student!.parentName.isNotEmpty || _student!.mobile.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            _student!.parentName.isNotEmpty && _student!.mobile.isNotEmpty
                                ? 'Parent: ${_student!.parentName} (${_student!.mobile})'
                                : (_student!.parentName.isNotEmpty ? 'Parent: ${_student!.parentName}' : 'Mobile: ${_student!.mobile}'),
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tab Bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primaryBlue,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primaryYellow,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(text: 'Profile Info'),
                Tab(text: 'Attendance'),
                Tab(text: 'Fees & Bills'),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProfileTab(currency),
                _buildAttendanceTab(),
                _buildFeesTab(currency),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RecordPaymentScreen(initialStudent: _student),
                    ),
                  );
                  _loadAllData();
                },
                icon: const Icon(Icons.currency_rupee_rounded, size: 18),
                label: const Text('Collect Fee'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: PROFILE INFO
  // ==========================================
  Widget _buildProfileTab(NumberFormat currency) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoCard(
          title: 'Student Details',
          icon: Icons.person_rounded,
          rows: [
            _detailRow('Date of Birth', _student!.dob.isNotEmpty ? _student!.dob : 'Not specified'),
            _detailRow('Gender', _student!.gender),
            _detailRow('Admission Date', _student!.admissionDate),
            _detailRow('Current School', (_student!.schoolName != null && _student!.schoolName!.isNotEmpty) ? _student!.schoolName! : 'Not specified'),
            _detailRow('Enrolled Subjects', _student!.subjects),
          ],
        ),
        const SizedBox(height: 14),
        _buildInfoCard(
          title: 'Parent & Contact',
          icon: Icons.family_restroom_rounded,
          rows: [
            _detailRow('Parent Name', _student!.parentName.isNotEmpty ? _student!.parentName : 'Not specified'),
            _detailRow('Contact Phone', _student!.mobile.isNotEmpty ? _student!.mobile : 'Not specified'),
            _detailRow('Residential Address', (_student!.address != null && _student!.address!.isNotEmpty) ? _student!.address! : 'Not specified'),
          ],
        ),
        const SizedBox(height: 14),
        _buildInfoCard(
          title: 'Fee Plan',
          icon: Icons.payments_rounded,
          rows: [
            _detailRow('Agreed Monthly Fee', currency.format(_student!.monthlyFees)),
            if (_student!.feeStartDate != null && _student!.feeStartDate!.isNotEmpty) ...[
              _detailRow(
                'Fee Billing Starts',
                DateFormat('MMMM yyyy').format(DateTime.parse(_student!.feeStartDate!)),
              ),
            ],
            _detailRow('Total Paid So Far', currency.format(_feeSummary['totalPaid'] ?? 0)),
            _detailRow(
              'Current Pending Dues',
              currency.format(_feeSummary['balanceDue'] ?? 0),
              isHighlight: (_feeSummary['balanceDue'] ?? 0) > 0,
            ),
          ],
        ),
        if (_student!.notes != null && _student!.notes!.isNotEmpty) ...[
          const SizedBox(height: 14),
          _buildInfoCard(
            title: 'Remarks / Notes',
            icon: Icons.note_rounded,
            rows: [
              _detailRow('Notes', _student!.notes!),
            ],
          ),
        ],
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> rows,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
              ),
            ],
          ),
          const Divider(height: 20),
          ...rows,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
                color: isHighlight ? AppColors.error : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: ATTENDANCE HISTORY
  // ==========================================
  Widget _buildAttendanceTab() {
    if (_attendanceList.isEmpty) {
      return const Center(
        child: Text('No attendance recorded yet for this student.', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    int present = _attendanceList.where((a) => a.status == 'Present').length;
    int absent = _attendanceList.where((a) => a.status == 'Absent').length;
    int leave = _attendanceList.where((a) => a.status == 'Leave').length;
    double percentage = (_attendanceList.isNotEmpty) ? ((present / _attendanceList.length) * 100) : 0;

    return Column(
      children: [
        // Summary Strip
        Container(
          padding: const EdgeInsets.all(14),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _attStatItem('Present', '$present', AppColors.present),
              _attStatItem('Absent', '$absent', AppColors.absent),
              _attStatItem('Leave', '$leave', AppColors.leave),
              _attStatItem('Rate', '${percentage.toStringAsFixed(0)}%', AppColors.primaryBlue),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: _attendanceList.length,
            itemBuilder: (context, index) {
              final att = _attendanceList[index];
              Color color = AppColors.present;
              if (att.status == 'Absent') color = AppColors.absent;
              if (att.status == 'Leave') color = AppColors.leave;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.textMuted),
                        const SizedBox(width: 10),
                        Text(
                          att.date,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        att.status,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _attStatItem(String label, String count, Color color) {
    return Column(
      children: [
        Text(count, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  // ==========================================
  // TAB 3: FEES HISTORY & RECEIPTS
  // ==========================================
  Widget _buildFeesTab(NumberFormat currency) {
    return Column(
      children: [
        // Summary Balance Banner
        Container(
          margin: const EdgeInsets.all(14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (_feeSummary['balanceDue'] ?? 0) > 0 ? AppColors.lightYellow : AppColors.successLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (_feeSummary['balanceDue'] ?? 0) > 0 ? AppColors.primaryYellow : AppColors.success,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pending Fees Balance', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    currency.format(_feeSummary['balanceDue'] ?? 0),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: (_feeSummary['balanceDue'] ?? 0) > 0 ? AppColors.darkYellow : AppColors.success,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Total Paid', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    currency.format(_feeSummary['totalPaid'] ?? 0),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                  ),
                ],
              ),
            ],
          ),
        ),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Payment History & Receipts',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
        ),

        Expanded(
          child: _paymentList.isEmpty
              ? const Center(
                  child: Text('No fee payments recorded yet.', style: TextStyle(color: AppColors.textSecondary)),
                )
              : ListView.builder(
                  itemCount: _paymentList.length,
                  itemBuilder: (context, index) {
                    final p = _paymentList[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.lightBlue,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.receipt_long_rounded, color: AppColors.primaryBlue, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.receiptNo,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'For ${p.feeMonth}  •  ${p.paymentMethod}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                Text(
                                  p.paymentDate,
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
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                              const SizedBox(height: 4),
                              IconButton(
                                icon: const Icon(Icons.download_rounded, color: AppColors.primaryBlue, size: 20),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                tooltip: 'View/Print Receipt PDF',
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => FeeReceiptScreen(
                                        payment: p,
                                        student: _student!,
                                        balanceDue: _feeSummary['balanceDue'] ?? 0.0,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
