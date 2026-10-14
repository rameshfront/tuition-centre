import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/student.dart';
import '../../database/db_helper.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/confirm_dialog.dart';
import 'student_form_screen.dart';
import 'student_detail_screen.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Student> _students = [];
  bool _isLoading = true;

  String _selectedClass = 'All Classes';
  int _activeFilterIndex = 0; // 0 = All, 1 = Active, 2 = Inactive

  // Multi-Select Mode for Bulk Delete / Operations
  bool _isSelectionMode = false;
  final Set<int> _selectedStudentIds = {};

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    bool? onlyActive;
    if (_activeFilterIndex == 1) onlyActive = true;
    if (_activeFilterIndex == 2) onlyActive = false;

    final list = await DBHelper.instance.getStudents(
      query: _searchController.text.trim(),
      gradeClass: _selectedClass,
      onlyActive: onlyActive,
    );

    if (mounted) {
      setState(() {
        _students = list;
        _isLoading = false;
        // Clean up selection set of removed students
        _selectedStudentIds.removeWhere((id) => !_students.any((s) => s.id == id));
      });
    }
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedStudentIds.contains(id)) {
        _selectedStudentIds.remove(id);
        if (_selectedStudentIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedStudentIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedStudentIds.length == _students.length) {
        _selectedStudentIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedStudentIds.addAll(_students.map((s) => s.id!).whereType<int>());
      }
    });
  }

  Future<void> _bulkDeleteSelected() async {
    if (_selectedStudentIds.isEmpty) return;

    final confirm = await ConfirmDialog.show(
      context: context,
      title: 'Bulk Delete Students',
      message: 'Are you sure you want to permanently delete ${_selectedStudentIds.length} selected students and their records?',
      confirmText: 'Delete All (${_selectedStudentIds.length})',
      isDanger: true,
    );

    if (confirm) {
      await DBHelper.instance.bulkDeleteStudents(_selectedStudentIds.toList());
      setState(() {
        _selectedStudentIds.clear();
        _isSelectionMode = false;
      });
      _loadStudents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected students deleted'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deleteSingleStudent(Student s) async {
    final confirm = await ConfirmDialog.show(
      context: context,
      title: 'Delete Student',
      message: 'Are you sure you want to delete ${s.fullName}? All attendance and payment history will be permanently deleted.',
      confirmText: 'Delete',
      isDanger: true,
    );

    if (confirm) {
      await DBHelper.instance.deleteStudent(s.id!);
      _loadStudents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student deleted'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _toggleSingleStatus(Student s) async {
    await DBHelper.instance.toggleStudentActiveStatus(s.id!, !s.isActive);
    _loadStudents();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.isActive ? '${s.fullName} deactivated' : '${s.fullName} activated'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_selectedStudentIds.length} Selected', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
            : const Text('Students Directory', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _isSelectionMode ? AppColors.darkBlue : AppColors.primaryBlue,
        elevation: 0,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: Icon(
                _selectedStudentIds.length == _students.length ? Icons.deselect_rounded : Icons.select_all_rounded,
                color: Colors.white,
              ),
              tooltip: 'Select All',
              onPressed: _selectAll,
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.errorLight),
              tooltip: 'Bulk Delete',
              onPressed: _bulkDeleteSelected,
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () {
                setState(() {
                  _isSelectionMode = false;
                  _selectedStudentIds.clear();
                });
              },
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.checklist_rounded, color: Colors.white),
              tooltip: 'Multi-select Mode',
              onPressed: () {
                setState(() => _isSelectionMode = true);
              },
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Filter & Search Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Search Field
                TextField(
                  controller: _searchController,
                  onChanged: (val) => _loadStudents(),
                  decoration: InputDecoration(
                    hintText: 'Search by name, ID or mobile...',
                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search, color: AppColors.primaryBlue, size: 22),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _loadStudents();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryBlue),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Class Dropdown & Status Chips
                Row(
                  children: [
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
                            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                            items: ['All Classes', ...AppConstants.classesList].map((c) {
                              return DropdownMenuItem(value: c, child: Text(c));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedClass = val);
                                _loadStudents();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Active / Inactive / All segmented toggle
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            _buildFilterSegment('All', 0),
                            _buildFilterSegment('Active', 1),
                            _buildFilterSegment('Inactive', 2),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Total Count Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.lightBlue.withOpacity(0.4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${_students.length} students',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryBlue),
                ),
                if (_isSelectionMode)
                  const Text(
                    'Tap cards to select for bulk delete',
                    style: TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),

          // Student List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
                : _students.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.people_outline_rounded,
                        title: 'No Students Found',
                        message: 'No student matches your current filter or search criteria.',
                        buttonText: 'Add New Student',
                        onButtonPressed: () async {
                          final res = await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const StudentFormScreen()),
                          );
                          if (res == true) _loadStudents();
                        },
                      )
                    : RefreshIndicator(
                        onRefresh: _loadStudents,
                        color: AppColors.primaryBlue,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _students.length,
                          itemBuilder: (context, index) {
                            final s = _students[index];
                            final isSelected = _selectedStudentIds.contains(s.id);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.primaryBlue
                                      : (s.isActive ? AppColors.border : AppColors.border.withOpacity(0.5)),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              elevation: isSelected ? 3 : 1,
                              color: isSelected ? AppColors.lightBlue.withOpacity(0.3) : Colors.white,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onLongPress: () {
                                  if (!_isSelectionMode) {
                                    setState(() {
                                      _isSelectionMode = true;
                                      _selectedStudentIds.add(s.id!);
                                    });
                                  }
                                },
                                onTap: () {
                                  if (_isSelectionMode) {
                                    _toggleSelection(s.id!);
                                  } else {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => StudentDetailScreen(studentId: s.id!),
                                      ),
                                    ).then((_) => _loadStudents());
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      if (_isSelectionMode)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 10),
                                          child: Checkbox(
                                            value: isSelected,
                                            activeColor: AppColors.primaryBlue,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                            onChanged: (val) => _toggleSelection(s.id!),
                                          ),
                                        ),

                                      // Avatar
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor: s.gender == 'Female'
                                            ? const Color(0xFFFCE7F3)
                                            : AppColors.lightBlue,
                                        child: Text(
                                          s.fullName.isNotEmpty ? s.fullName[0].toUpperCase() : 'S',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: s.gender == 'Female'
                                                ? const Color(0xFFDB2777)
                                                : AppColors.primaryBlue,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    s.fullName,
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.bold,
                                                      color: s.isActive ? AppColors.textPrimary : AppColors.textMuted,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                if (!s.isActive)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.errorLight,
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: const Text(
                                                      'Inactive',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        color: AppColors.error,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              '${s.studentId}  •  ${s.gradeClass}',
                                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Parent: ${s.parentName} (${s.mobile})',
                                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Right action popup
                                      if (!_isSelectionMode)
                                        PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
                                          onSelected: (val) {
                                            if (val == 'view') {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) => StudentDetailScreen(studentId: s.id!),
                                                ),
                                              ).then((_) => _loadStudents());
                                            }
                                            if (val == 'edit') {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) => StudentFormScreen(studentToEdit: s),
                                                ),
                                              ).then((_) => _loadStudents());
                                            }
                                            if (val == 'status') _toggleSingleStatus(s);
                                            if (val == 'delete') _deleteSingleStudent(s);
                                          },
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(
                                              value: 'view',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.visibility_outlined, size: 18),
                                                  SizedBox(width: 8),
                                                  Text('View Profile'),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'edit',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.edit_outlined, size: 18),
                                                  SizedBox(width: 8),
                                                  Text('Edit Student'),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'status',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    s.isActive ? Icons.person_off_outlined : Icons.person_add_alt_1_outlined,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(s.isActive ? 'Deactivate' : 'Activate'),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                                  SizedBox(width: 8),
                                                  Text('Delete', style: TextStyle(color: AppColors.error)),
                                                ],
                                              ),
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
          ),
        ],
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                final res = await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StudentFormScreen()),
                );
                if (res == true) _loadStudents();
              },
              backgroundColor: AppColors.primaryBlue,
              icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
              label: const Text(
                'New Student',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
    );
  }

  Widget _buildFilterSegment(String label, int index) {
    final isSelected = _activeFilterIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _activeFilterIndex = index);
          _loadStudents();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
