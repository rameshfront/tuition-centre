import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../database/db_helper.dart';
import '../../services/pdf_service.dart';
import '../../services/backup_service.dart';
import '../../widgets/confirm_dialog.dart';

class ReportsAndStorageScreen extends StatefulWidget {
  const ReportsAndStorageScreen({super.key});

  @override
  State<ReportsAndStorageScreen> createState() => _ReportsAndStorageScreenState();
}

class _ReportsAndStorageScreenState extends State<ReportsAndStorageScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Storage counters
  Map<String, int> _recordCounts = {'students': 0, 'attendance': 0, 'fees': 0};
  int _cacheSizeBytes = 0;
  bool _isLoading = true;

  // Report filters
  String _selectedReportClass = 'All Classes';
  String _selectedReportMonth = DateFormat('MMMM yyyy').format(DateTime.now());
  DateTime? _reportStartDate;
  DateTime? _reportEndDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStorageData();
  }

  Future<void> _loadStorageData() async {
    setState(() => _isLoading = true);
    final counts = await DBHelper.instance.getStorageRecordCounts();
    final cacheBytes = await StorageBackupService.getCacheSizeInBytes();

    if (mounted) {
      setState(() {
        _recordCounts = counts;
        _cacheSizeBytes = cacheBytes;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ==========================================
  // STORAGE & CLEANUP ACTIONS
  // ==========================================

  Future<void> _clearCache() async {
    final success = await StorageBackupService.clearAppCache();
    await _loadStorageData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Temporary app cache and generated PDFs cleared!' : 'Failed to clear cache'),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

  Future<void> _bulkDeleteInactiveStudents() async {
    final confirm = await ConfirmDialog.show(
      context: context,
      title: 'Bulk Delete Inactive Students',
      message: 'Are you sure you want to delete all deactivated students and their associated records?',
      confirmText: 'Delete Inactive',
      isDanger: true,
    );

    if (confirm) {
      final count = await DBHelper.instance.bulkDeleteInactiveStudents();
      await _loadStorageData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count inactive students deleted'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _bulkDeleteOldAttendance(int monthsOld) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: monthsOld * 30));
    final cutoffStr = DateFormat('yyyy-MM-dd').format(cutoffDate);

    final confirm = await ConfirmDialog.show(
      context: context,
      title: 'Bulk Delete Attendance',
      message: 'Delete all attendance records before $cutoffStr (older than $monthsOld month(s))?',
      confirmText: 'Delete Older Records',
      isDanger: true,
    );

    if (confirm) {
      final count = await DBHelper.instance.bulkDeleteAttendance(beforeDate: cutoffStr);
      await _loadStorageData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count old attendance records deleted'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _exportBackup() async {
    final path = await StorageBackupService.exportBackup();
    if (path != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Database backup exported! Check share options.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _restoreBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();

        final confirm = await ConfirmDialog.show(
          context: context,
          title: 'Restore Database Backup?',
          message: 'Warning: Restoring will overwrite existing local data with the backup file data. Do you wish to continue?',
          confirmText: 'Restore Now',
          isDanger: true,
        );

        if (confirm) {
          final ok = await StorageBackupService.restoreBackupFromFile(content);
          await _loadStorageData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(ok ? 'Database restored successfully!' : 'Failed to restore backup.'),
                backgroundColor: ok ? AppColors.success : AppColors.error,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _wipeAllData() async {
    final confirm = await ConfirmDialog.show(
      context: context,
      title: 'FACTORY RESET ALL DATA?',
      message: 'CRITICAL WARNING: This will permanently delete ALL students, ALL attendance, and ALL fee records stored locally on this phone. Ensure you have exported a backup first!',
      confirmText: 'DELETE EVERYTHING',
      isDanger: true,
    );

    if (confirm) {
      await DBHelper.instance.clearAllAppData();
      await StorageBackupService.clearAppCache();
      await _loadStorageData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All local app data cleared!'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ==========================================
  // PDF REPORT GENERATORS
  // ==========================================

  Future<void> _generateAttendanceReport() async {
    final startStr = _reportStartDate != null ? DateFormat('yyyy-MM-dd').format(_reportStartDate!) : null;
    final endStr = _reportEndDate != null ? DateFormat('yyyy-MM-dd').format(_reportEndDate!) : null;

    final records = await DBHelper.instance.getAttendanceForReport(
      gradeClass: _selectedReportClass,
      startDate: startStr,
      endDate: endStr,
    );

    if (records.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No attendance records found for criteria.'), backgroundColor: AppColors.warning),
        );
      }
      return;
    }

    final pdf = await PdfService.generateAttendanceReport(
      attendanceList: records,
      gradeClass: _selectedReportClass,
      startDate: startStr,
      endDate: endStr,
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf,
      name: 'Attendance_Report.pdf',
    );
  }

  Future<void> _generateFeeReport() async {
    final payments = await DBHelper.instance.getAllPayments(
      month: _selectedReportMonth == 'All Months' ? null : _selectedReportMonth,
    );

    final activeStudents = await DBHelper.instance.getStudents(onlyActive: true);
    final List<Map<String, dynamic>> pendingList = [];

    for (var s in activeStudents) {
      final summary = await DBHelper.instance.getStudentFeeSummary(s.id!);
      final balance = summary['balanceDue'] ?? 0.0;
      if (balance > 0) {
        pendingList.add({
          'student_id': s.studentId,
          'name': s.fullName,
          'class': s.gradeClass,
          'mobile': s.mobile,
          'balance': balance,
        });
      }
    }

    final pdf = await PdfService.generateFeesReport(
      paymentList: payments,
      pendingStudentsList: pendingList,
      month: _selectedReportMonth,
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf,
      name: 'Fees_Report_${_selectedReportMonth.replaceAll(" ", "_")}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reports & Storage', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppColors.primaryYellow,
          indicatorWeight: 3.5,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.picture_as_pdf_rounded, size: 20), text: 'PDF Reports'),
            Tab(icon: Icon(Icons.storage_rounded, size: 20), text: 'Data & Cache'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPdfReportsTab(),
                _buildStorageAndCleanupTab(),
              ],
            ),
    );
  }

  // ==========================================
  // TAB 1: PDF REPORTS
  // ==========================================
  Widget _buildPdfReportsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Attendance Report Card
        _buildReportSectionCard(
          title: 'Attendance Report (PDF)',
          icon: Icons.how_to_reg_rounded,
          color: AppColors.primaryBlue,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filter by Class', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedReportClass,
                    isExpanded: true,
                    items: ['All Classes', ...AppConstants.classesList].map((c) {
                      return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedReportClass = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _generateAttendanceReport,
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text('Generate Attendance PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Fees Report Card
        _buildReportSectionCard(
          title: 'Fee Collection & Dues Report (PDF)',
          icon: Icons.receipt_long_rounded,
          color: AppColors.darkYellow,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filter by Month', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedReportMonth,
                    isExpanded: true,
                    items: [
                      'All Months',
                      DateFormat('MMMM yyyy').format(DateTime.now()),
                      DateFormat('MMMM yyyy').format(DateTime.now().subtract(const Duration(days: 30))),
                      DateFormat('MMMM yyyy').format(DateTime.now().subtract(const Duration(days: 60))),
                    ].map((m) {
                      return DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13)));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedReportMonth = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _generateFeeReport,
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text('Generate Fee Report PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 2: STORAGE & BULK CLEANUP
  // ==========================================
  Widget _buildStorageAndCleanupTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Storage Status Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.storage_rounded, color: AppColors.primaryBlue, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Local Device Storage Overview',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _storageCountItem('Students', '${_recordCounts['students'] ?? 0}'),
                  _storageCountItem('Attendance', '${_recordCounts['attendance'] ?? 0}'),
                  _storageCountItem('Fee Bills', '${_recordCounts['fees'] ?? 0}'),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.cleaning_services_rounded, color: AppColors.primaryBlue, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'App Cache: ${StorageBackupService.formatBytes(_cacheSizeBytes)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: _clearCache,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Clear Cache', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Bulk Delete Operations Card
        _buildReportSectionCard(
          title: 'Bulk Delete Management',
          icon: Icons.delete_sweep_rounded,
          color: AppColors.error,
          content: Column(
            children: [
              _buildCleanupActionTile(
                title: 'Delete Inactive Students',
                subtitle: 'Remove students marked inactive and free space',
                icon: Icons.person_remove_rounded,
                onTap: _bulkDeleteInactiveStudents,
              ),
              const Divider(height: 1),
              _buildCleanupActionTile(
                title: 'Delete Attendance Older Than 3 Months',
                subtitle: 'Bulk purge attendance logs older than 90 days',
                icon: Icons.date_range_rounded,
                onTap: () => _bulkDeleteOldAttendance(3),
              ),
              const Divider(height: 1),
              _buildCleanupActionTile(
                title: 'Delete Attendance Older Than 6 Months',
                subtitle: 'Bulk purge attendance logs older than 180 days',
                icon: Icons.event_repeat_rounded,
                onTap: () => _bulkDeleteOldAttendance(6),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Database Backup & Restore Card
        _buildReportSectionCard(
          title: 'Database Backup & Restore',
          icon: Icons.cloud_sync_rounded,
          color: const Color(0xFF0D9488),
          content: Column(
            children: [
              _buildCleanupActionTile(
                title: 'Export Full Database Backup',
                subtitle: 'Save or share a JSON file of all local data',
                icon: Icons.file_download_rounded,
                onTap: _exportBackup,
              ),
              const Divider(height: 1),
              _buildCleanupActionTile(
                title: 'Restore Database from File',
                subtitle: 'Import a previously exported JSON backup',
                icon: Icons.file_upload_rounded,
                onTap: _restoreBackup,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Factory Reset Danger Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.errorLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.error.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Danger Zone - Reset All Data',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.error),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Wipes the entire local database clean. All students, attendance, and fee history will be permanently deleted.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _wipeAllData,
                  icon: const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 18),
                  label: const Text('Factory Reset App Data'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildReportSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget content,
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
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const Divider(height: 20),
          content,
        ],
      ),
    );
  }

  Widget _buildCleanupActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primaryBlue, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
      onTap: onTap,
    );
  }

  Widget _storageCountItem(String label, String count) {
    return Column(
      children: [
        Text(count, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}
