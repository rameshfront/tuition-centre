import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/student.dart';
import '../../models/attendance.dart';
import '../../database/db_helper.dart';
import '../../widgets/empty_state.dart';
import 'attendance_history_screen.dart';

class MarkAttendanceScreen extends StatefulWidget {
  const MarkAttendanceScreen({super.key});

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  String _selectedClass = AppConstants.classesList.first;
  List<Student> _students = [];
  Map<int, String> _attendanceMap = {}; // studentId -> 'Present'|'Absent'|'Leave'
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    // 1. Fetch active students in selected class
    final studentsList = await DBHelper.instance.getStudents(
      gradeClass: _selectedClass,
      onlyActive: true,
    );

    // 2. Fetch any already marked attendance for this date & class
    final existingAttendance = await DBHelper.instance.getAttendanceForDateAndClass(
      dateStr,
      _selectedClass,
    );

    final Map<int, String> statusMap = {};
    for (var att in existingAttendance) {
      statusMap[att.studentId] = att.status;
    }

    // Default unmarked students to 'Present'
    for (var s in studentsList) {
      if (!statusMap.containsKey(s.id)) {
        statusMap[s.id!] = 'Present';
      }
    }

    if (mounted) {
      setState(() {
        _students = studentsList;
        _attendanceMap = statusMap;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 7)),
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

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  void _markAll(String status) {
    setState(() {
      for (var s in _students) {
        if (s.id != null) {
          _attendanceMap[s.id!] = status;
        }
      }
    });
  }

  Future<void> _saveAttendance() async {
    if (_students.isEmpty) return;
    setState(() => _isSaving = true);

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final nowIso = DateTime.now().toIso8601String();

    final List<Attendance> records = [];
    for (var s in _students) {
      if (s.id != null) {
        final status = _attendanceMap[s.id!] ?? 'Present';
        records.add(
          Attendance(
            studentId: s.id!,
            date: dateStr,
            status: status,
            createdAt: nowIso,
          ),
        );
      }
    }

    await DBHelper.instance.batchSaveAttendance(records);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attendance saved successfully for ${records.length} students!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateDisplay = DateFormat('EEE, dd MMMM yyyy').format(_selectedDate);
    final isToday = DateFormat('yyyy-MM-dd').format(_selectedDate) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    int presentCount = _attendanceMap.values.where((v) => v == 'Present').length;
    int absentCount = _attendanceMap.values.where((v) => v == 'Absent').length;
    int leaveCount = _attendanceMap.values.where((v) => v == 'Leave').length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mark Attendance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.white),
            tooltip: 'Attendance History & Reports',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Date & Class Controls Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    // Date Selector Button
                    Expanded(
                      flex: 6,
                      child: InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.lightBlue,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, color: AppColors.primaryBlue, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isToday ? 'Today' : 'Selected Date',
                                      style: const TextStyle(fontSize: 10, color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      dateDisplay,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, color: AppColors.primaryBlue),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Class Dropdown
                    Expanded(
                      flex: 4,
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
                            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                            items: AppConstants.classesList.map((c) {
                              return DropdownMenuItem(value: c, child: Text(c));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedClass = val);
                                _loadData();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Batch Actions & Count Strip
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _markAll('Present'),
                          icon: const Icon(Icons.check_circle_outline, size: 14, color: AppColors.present),
                          label: const Text('All Present', style: TextStyle(fontSize: 11, color: AppColors.present, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.present),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton.icon(
                          onPressed: () => _markAll('Absent'),
                          icon: const Icon(Icons.cancel_outlined, size: 14, color: AppColors.absent),
                          label: const Text('All Absent', style: TextStyle(fontSize: 11, color: AppColors.absent, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.absent),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _statusBadge('P: $presentCount', AppColors.present),
                        const SizedBox(width: 4),
                        _statusBadge('A: $absentCount', AppColors.absent),
                        const SizedBox(width: 4),
                        _statusBadge('L: $leaveCount', AppColors.leave),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Students List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
                : _students.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.person_off_rounded,
                        title: 'No Active Students',
                        message: 'There are no active students enrolled in $_selectedClass.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _students.length,
                        itemBuilder: (context, index) {
                          final s = _students[index];
                          final currentStatus = _attendanceMap[s.id!] ?? 'Present';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: AppColors.border),
                            ),
                            elevation: 0.5,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: s.gender == 'Female'
                                        ? const Color(0xFFFCE7F3)
                                        : AppColors.lightBlue,
                                    child: Text(
                                      s.fullName.isNotEmpty ? s.fullName[0].toUpperCase() : 'S',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: s.gender == 'Female'
                                            ? const Color(0xFFDB2777)
                                            : AppColors.primaryBlue,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s.fullName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          s.studentId,
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // 3 Toggle Buttons: P, A, L
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildStatusButton(
                                        studentId: s.id!,
                                        label: 'P',
                                        fullStatus: 'Present',
                                        isSelected: currentStatus == 'Present',
                                        color: AppColors.present,
                                      ),
                                      const SizedBox(width: 6),
                                      _buildStatusButton(
                                        studentId: s.id!,
                                        label: 'A',
                                        fullStatus: 'Absent',
                                        isSelected: currentStatus == 'Absent',
                                        color: AppColors.absent,
                                      ),
                                      const SizedBox(width: 6),
                                      _buildStatusButton(
                                        studentId: s.id!,
                                        label: 'L',
                                        fullStatus: 'Leave',
                                        isSelected: currentStatus == 'Leave',
                                        color: AppColors.leave,
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
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2)),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: (_isSaving || _students.isEmpty) ? null : _saveAttendance,
            icon: _isSaving
                ? const SizedBox.shrink()
                : const Icon(Icons.save_rounded, color: Colors.white),
            label: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    'Save Attendance (${_students.length} Students)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusButton({
    required int studentId,
    required String label,
    required String fullStatus,
    required bool isSelected,
    required Color color,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _attendanceMap[studentId] = fullStatus;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
