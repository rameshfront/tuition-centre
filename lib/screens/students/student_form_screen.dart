import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/student.dart';
import '../../database/db_helper.dart';

class StudentFormScreen extends StatefulWidget {
  final Student? studentToEdit;

  const StudentFormScreen({super.key, this.studentToEdit});

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _studentIdController;
  late TextEditingController _fullNameController;
  late TextEditingController _dobController;
  late TextEditingController _parentNameController;
  late TextEditingController _mobileController;
  late TextEditingController _addressController;
  late TextEditingController _schoolNameController;
  late TextEditingController _admissionDateController;
  late TextEditingController _monthlyFeesController;
  late TextEditingController _notesController;

  String _gender = 'Male';
  String _selectedClass = AppConstants.classesList.first;
  final List<String> _selectedSubjects = [];
  bool _isActive = true;
  bool _isLoading = false;

  bool get _isEditMode => widget.studentToEdit != null;

  @override
  void initState() {
    super.initState();
    final s = widget.studentToEdit;

    _studentIdController = TextEditingController(text: s?.studentId ?? '');
    _fullNameController = TextEditingController(text: s?.fullName ?? '');
    _dobController = TextEditingController(text: s?.dob ?? '');
    _parentNameController = TextEditingController(text: s?.parentName ?? '');
    _mobileController = TextEditingController(text: s?.mobile ?? '');
    _addressController = TextEditingController(text: s?.address ?? '');
    _schoolNameController = TextEditingController(text: s?.schoolName ?? '');
    _admissionDateController = TextEditingController(
      text: s?.admissionDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    _monthlyFeesController = TextEditingController(
      text: s != null ? s.monthlyFees.toStringAsFixed(0) : '',
    );
    _notesController = TextEditingController(text: s?.notes ?? '');

    if (s != null) {
      _gender = s.gender;
      _selectedClass = AppConstants.classesList.contains(s.gradeClass)
          ? s.gradeClass
          : AppConstants.classesList.first;
      _isActive = s.isActive;
      if (s.subjects.isNotEmpty) {
        _selectedSubjects.addAll(
          s.subjects.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty),
        );
      }
    } else {
      _loadAutoStudentId();
    }
  }

  Future<void> _loadAutoStudentId() async {
    final nextId = await DBHelper.instance.getNextStudentId();
    if (mounted && _studentIdController.text.isEmpty) {
      setState(() {
        _studentIdController.text = nextId;
      });
    }
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    _fullNameController.dispose();
    _dobController.dispose();
    _parentNameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _schoolNameController.dispose();
    _admissionDateController.dispose();
    _monthlyFeesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(TextEditingController controller) async {
    DateTime initial = DateTime.now();
    if (controller.text.isNotEmpty) {
      try {
        initial = DateTime.parse(controller.text);
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1990),
      lastDate: DateTime(2035),
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
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one subject.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final monthlyFee = double.tryParse(_monthlyFeesController.text.trim()) ?? 0.0;
      final student = Student(
        id: widget.studentToEdit?.id,
        studentId: _studentIdController.text.trim(),
        fullName: _fullNameController.text.trim(),
        photoPath: widget.studentToEdit?.photoPath,
        dob: _dobController.text.trim(),
        gender: _gender,
        parentName: _parentNameController.text.trim(),
        mobile: _mobileController.text.trim(),
        address: _addressController.text.trim(),
        gradeClass: _selectedClass,
        schoolName: _schoolNameController.text.trim(),
        subjects: _selectedSubjects.join(', '),
        admissionDate: _admissionDateController.text.trim(),
        monthlyFees: monthlyFee,
        notes: _notesController.text.trim(),
        isActive: _isActive,
        createdAt: widget.studentToEdit?.createdAt ?? DateTime.now().toIso8601String(),
      );

      if (_isEditMode) {
        await DBHelper.instance.updateStudent(student);
      } else {
        await DBHelper.instance.insertStudent(student);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? 'Student updated successfully!' : 'Student registered successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving student: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit Student' : 'New Admission',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
              // Registration Header Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.lightYellow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryYellow.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.school_rounded, color: AppColors.darkYellow, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditMode ? 'Updating Student Record' : 'Student Admission Form',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                          ),
                          const Text(
                            'Enter accurate details for record keeping and fee bills.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              _buildSectionHeader('Basic Information', Icons.person_rounded),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      controller: _studentIdController,
                      label: 'Student ID *',
                      icon: Icons.badge_outlined,
                      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: _buildTextField(
                      controller: _fullNameController,
                      label: 'Full Name *',
                      icon: Icons.person_outline,
                      validator: (val) => val == null || val.trim().isEmpty ? 'Enter full name' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Gender Selector
              const Text('Gender', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              Row(
                children: ['Male', 'Female', 'Other'].map((g) {
                  final isSelected = _gender == g;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ChoiceChip(
                      label: Text(g),
                      selected: isSelected,
                      selectedColor: AppColors.primaryBlue,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _gender = g);
                      },
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildDateField(
                      controller: _dobController,
                      label: 'Date of Birth (Optional)',
                      icon: Icons.cake_outlined,
                      isOptional: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDateField(
                      controller: _admissionDateController,
                      label: 'Admission Date *',
                      icon: Icons.calendar_today_outlined,
                      validator: (val) => val == null || val.trim().isEmpty ? 'Select date' : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              _buildSectionHeader('Parent & Contact Details', Icons.contact_phone_rounded),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _parentNameController,
                label: 'Parent / Guardian Name (Optional)',
                icon: Icons.family_restroom_rounded,
              ),
              const SizedBox(height: 14),

              _buildTextField(
                controller: _mobileController,
                label: 'Parent Mobile Number (Optional)',
                icon: Icons.phone_android_rounded,
                keyboardType: TextInputType.phone,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return null; // Optional
                  final clean = val.replaceAll(RegExp(r'\D'), '');
                  if (clean.length < 10) return 'Must be at least 10 digits';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              _buildTextField(
                controller: _addressController,
                label: 'Residential Address (Optional)',
                icon: Icons.home_outlined,
                maxLines: 2,
              ),

              const SizedBox(height: 24),
              _buildSectionHeader('Academic & Fee Details', Icons.menu_book_rounded),
              const SizedBox(height: 12),

              Row(
                children: [
                  // Class Dropdown
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedClass,
                      decoration: _inputDecoration('Class / Grade *', Icons.grade_rounded),
                      items: AppConstants.classesList.map((c) {
                        return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedClass = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _monthlyFeesController,
                      label: 'Monthly Fee (Rs.) *',
                      icon: Icons.currency_rupee_rounded,
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Enter monthly fee';
                        if (double.tryParse(val) == null) return 'Enter valid amount';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _buildTextField(
                controller: _schoolNameController,
                label: 'School Name (Optional)',
                icon: Icons.apartment_rounded,
              ),
              const SizedBox(height: 14),

              // Subjects Multi-Selection Chips
              const Text(
                'Enrolled Subjects *',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppConstants.subjectsList.map((subj) {
                  final isSelected = _selectedSubjects.contains(subj);
                  return FilterChip(
                    label: Text(subj),
                    selected: isSelected,
                    selectedColor: AppColors.primaryYellow.withOpacity(0.35),
                    checkmarkColor: AppColors.darkYellow,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: isSelected ? AppColors.darkYellow : AppColors.border,
                    ),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppColors.darkYellow : AppColors.textPrimary,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedSubjects.add(subj);
                        } else {
                          _selectedSubjects.remove(subj);
                        }
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 14),
              _buildTextField(
                controller: _notesController,
                label: 'Special Notes / Remarks (Optional)',
                icon: Icons.note_alt_outlined,
                maxLines: 2,
              ),

              if (_isEditMode) ...[
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Student Active Status', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(_isActive ? 'Active student' : 'Deactivated / Past student'),
                  value: _isActive,
                  activeColor: AppColors.success,
                  onChanged: (val) {
                    setState(() => _isActive = val);
                  },
                ),
              ],

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveStudent,
                  icon: _isLoading
                      ? const SizedBox.shrink()
                      : const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                  label: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isEditMode ? 'Update Student Details' : 'Register Student',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryBlue),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 13),
      decoration: _inputDecoration(label, icon),
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isOptional = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: () => _selectDate(controller),
      validator: validator,
      style: const TextStyle(fontSize: 13),
      decoration: _inputDecoration(label, icon).copyWith(
        suffixIcon: (isOptional && controller.text.isNotEmpty)
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                onPressed: () {
                  setState(() {
                    controller.clear();
                  });
                },
              )
            : const Icon(Icons.arrow_drop_down, color: AppColors.primaryBlue),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      prefixIcon: Icon(icon, size: 20, color: AppColors.primaryBlue),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.8),
      ),
    );
  }
}
