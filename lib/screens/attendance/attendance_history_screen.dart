import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/attendance.dart';
import '../../database/db_helper.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/confirm_dialog.dart';
import '../../services/pdf_service.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _selectedClass = 'All Classes';
  DateTime? _startDate;
  DateTime? _endDate;
  List<Attendance> _allRecords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final startStr = _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : null;
    final endStr = _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null;

    final list = await DBHelper.instance.getAttendanceForReport(
      gradeClass: _selectedClass,
      startDate: startStr,
      endDate: endStr,
    );

    if (mounted) {
      setState(() {
        _allRecords = list;
        _isLoading = false;
      });
    }
  }

  List<Attendance> get _filteredRecords {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _allRecords;

    return _allRecords.where((a) {
      final name = (a.studentName ?? '').toLowerCase();
      final code = (a.studentCode ?? '').toLowerCase();
      final grade = (a.gradeClass ?? '').toLowerCase();
      final date = a.date.toLowerCase();
      final status = a.status.toLowerCase();
      return name.contains(query) ||
          code.contains(query) ||
          grade.contains(query) ||
          date.contains(query) ||
          status.contains(query);
    }).toList();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
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
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadHistory();
    }
  }

  Future<void> _exportPdf() async {
    final recordsToExport = _filteredRecords;
    if (recordsToExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attendance records to export'), backgroundColor: AppColors.warning),
      );
      return;
    }

    final startStr = _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : null;
    final endStr = _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null;

    final pdfBytes = await PdfService.generateAttendanceReport(
      attendanceList: recordsToExport,
      gradeClass: _selectedClass,
      startDate: startStr,
      endDate: endStr,
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'Attendance_Report_${_selectedClass.replaceAll(" ", "_")}.pdf',
    );
  }

  Future<void> _sharePdf() async {
    final recordsToExport = _filteredRecords;
    if (recordsToExport.isEmpty) return;

    final startStr = _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : null;
    final endStr = _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null;

    final pdfBytes = await PdfService.generateAttendanceReport(
      attendanceList: recordsToExport,
      gradeClass: _selectedClass,
      startDate: startStr,
      endDate: endStr,
    );

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Attendance_Report_${_selectedClass.replaceAll(" ", "_")}.pdf',
    );
  }

  Future<void> _showEditAttendanceModal(Attendance att) async {
    String currentStatus = att.status;
    final notesController = TextEditingController(text: att.notes ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Color statusColor = AppColors.present;
            if (currentStatus == 'Absent') statusColor = AppColors.absent;
            if (currentStatus == 'Leave') statusColor = AppColors.leave;

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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag Handle
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

                    // Header Info
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.lightBlue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.edit_calendar_rounded, color: AppColors.primaryBlue, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                att.studentName ?? 'Student',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                              ),
                              Text(
                                '${att.gradeClass ?? ""}  •  Date: ${att.date}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: statusColor.withOpacity(0.5)),
                          ),
                          child: Text(
                            currentStatus,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: statusColor),
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 28),

                    // Status Selection
                    const Text(
                      'Update Attendance Status',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        // Present
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => currentStatus = 'Present'),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: currentStatus == 'Present' ? AppColors.present : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: currentStatus == 'Present' ? AppColors.present : AppColors.border,
                                  width: currentStatus == 'Present' ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 20,
                                    color: currentStatus == 'Present' ? Colors.white : AppColors.present,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Present',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: currentStatus == 'Present' ? Colors.white : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Absent
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => currentStatus = 'Absent'),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: currentStatus == 'Absent' ? AppColors.absent : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: currentStatus == 'Absent' ? AppColors.absent : AppColors.border,
                                  width: currentStatus == 'Absent' ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.cancel_rounded,
                                    size: 20,
                                    color: currentStatus == 'Absent' ? Colors.white : AppColors.absent,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Absent',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: currentStatus == 'Absent' ? Colors.white : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Leave
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => currentStatus = 'Leave'),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: currentStatus == 'Leave' ? AppColors.leave : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: currentStatus == 'Leave' ? AppColors.leave : AppColors.border,
                                  width: currentStatus == 'Leave' ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.access_time_filled_rounded,
                                    size: 20,
                                    color: currentStatus == 'Leave' ? Colors.white : AppColors.leave,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Leave',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: currentStatus == 'Leave' ? Colors.white : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Remarks / Notes Field
                    TextField(
                      controller: notesController,
                      decoration: InputDecoration(
                        labelText: 'Remarks / Reason (Optional)',
                        hintText: 'e.g. Informed parent, Sick leave, etc.',
                        prefixIcon: const Icon(Icons.note_alt_outlined, color: AppColors.primaryBlue),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: AppColors.background,
                      ),
                      maxLines: 2,
                    ),

                    const SizedBox(height: 20),

                    // Action Buttons
                    Row(
                      children: [
                        // Delete Button
                        OutlinedButton.icon(
                          onPressed: () async {
                            final confirm = await ConfirmDialog.show(
                              context: context,
                              title: 'Delete Attendance?',
                              message: 'Delete attendance record for ${att.studentName} on ${att.date}?',
                              confirmText: 'Delete',
                              isDanger: true,
                            );
                            if (confirm) {
                              await DBHelper.instance.deleteAttendanceSingleRecord(att.id!);
                              if (context.mounted) Navigator.pop(context);
                              _loadHistory();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Attendance record deleted'), backgroundColor: AppColors.error),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                          label: const Text('Delete', style: TextStyle(color: AppColors.error)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.errorLight),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Save Button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await DBHelper.instance.updateAttendanceRecord(
                                id: att.id!,
                                status: currentStatus,
                                notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                              );
                              if (context.mounted) Navigator.pop(context);
                              _loadHistory();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Attendance updated to "$currentStatus" for ${att.studentName}!'),
                                    backgroundColor: AppColors.success,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.check_rounded, color: Colors.white),
                            label: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _bulkDeleteAttendanceRecords() async {
    final filtered = _filteredRecords;
    final confirm = await ConfirmDialog.show(
      context: context,
      title: 'Bulk Delete Attendance',
      message: 'Are you sure you want to delete these ${filtered.length} filtered attendance records? This cannot be undone.',
      confirmText: 'Delete Records',
      isDanger: true,
    );

    if (confirm) {
      final ids = filtered.map((r) => r.id!).whereType<int>().toList();
      await DBHelper.instance.bulkDeleteAttendance(attendanceIds: ids);
      _loadHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ids.length} attendance records deleted'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = _filteredRecords;

    final presentCount = records.where((r) => r.status == 'Present').length;
    final absentCount = records.where((r) => r.status == 'Absent').length;
    final leaveCount = records.where((r) => r.status == 'Leave').length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Attendance Report & History', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            tooltip: 'Share PDF Report',
            onPressed: records.isNotEmpty ? _sharePdf : null,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
            tooltip: 'Export / Print PDF',
            onPressed: records.isNotEmpty ? _exportPdf : null,
          ),
          if (records.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.errorLight),
              tooltip: 'Bulk Delete Filtered Records',
              onPressed: _bulkDeleteAttendanceRecords,
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Controls Container
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Dropdowns Row
                Row(
                  children: [
                    // Class Dropdown
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedClass,
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryBlue),
                            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                            items: ['All Classes', ...AppConstants.classesList].map((c) {
                              return DropdownMenuItem(value: c, child: Text(c));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedClass = val);
                                _loadHistory();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Date Range Button
                    Expanded(
                      flex: 5,
                      child: OutlinedButton.icon(
                        onPressed: _pickDateRange,
                        icon: const Icon(Icons.date_range_rounded, size: 16, color: AppColors.primaryBlue),
                        label: Text(
                          _startDate == null ? 'All Dates' : '${DateFormat('dd/MM').format(_startDate!)} - ${DateFormat('dd/MM').format(_endDate!)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        ),
                      ),
                    ),

                    if (_startDate != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: AppColors.textMuted),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Clear Date Filter',
                        onPressed: () {
                          setState(() {
                            _startDate = null;
                            _endDate = null;
                          });
                          _loadHistory();
                        },
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 10),

                // Search Bar for Instant Student / Row Filtering
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search by student name, ID, or class...',
                    hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.primaryBlue),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16, color: AppColors.textMuted),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
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
              ],
            ),
          ),

          // Total Stats & Summary Pills Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.lightBlue.withOpacity(0.4),
              border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.6))),
            ),
            child: Row(
              children: [
                Text(
                  '${records.length} Found',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildSummaryPill('$presentCount Present', AppColors.present),
                        const SizedBox(width: 6),
                        _buildSummaryPill('$absentCount Absent', AppColors.absent),
                        const SizedBox(width: 6),
                        _buildSummaryPill('$leaveCount Leave', AppColors.leave),
                      ],
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: records.isNotEmpty ? _exportPdf : null,
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 14),
                  label: const Text('PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ),
          ),

          // Records List with Edit on each row
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
                : records.isEmpty
                    ? const EmptyStateWidget(
                        icon: Icons.event_busy_rounded,
                        title: 'No Attendance Records',
                        message: 'No records found matching your filters/search.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(10),
                        itemCount: records.length,
                        itemBuilder: (context, index) {
                          final att = records[index];
                          Color color = AppColors.present;
                          if (att.status == 'Absent') color = AppColors.absent;
                          if (att.status == 'Leave') color = AppColors.leave;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                onTap: () => _showEditAttendanceModal(att),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      // Status Vertical Indicator
                                      Container(
                                        width: 4,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: color,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Student details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    att.studentName ?? 'Student',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (att.studentCode != null && att.studentCode!.isNotEmpty)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.background,
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(color: AppColors.border),
                                                    ),
                                                    child: Text(
                                                      att.studentCode!,
                                                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              '${att.gradeClass ?? ""}  •  Date: ${att.date}',
                                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                            ),
                                            if (att.notes != null && att.notes!.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                'Note: ${att.notes}',
                                                style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: AppColors.textMuted),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),

                                      const SizedBox(width: 8),

                                      // Status Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: color.withOpacity(0.4)),
                                        ),
                                        child: Text(
                                          att.status,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            color: color,
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 4),

                                      // Edit Row Action Button
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.primaryBlue),
                                        tooltip: 'Edit Attendance',
                                        onPressed: () => _showEditAttendanceModal(att),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
