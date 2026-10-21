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
  String? _feeStartDate;

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
    _feeStartDate = s?.feeStartDate ?? s?.admissionDate;
    if (_feeStartDate == null) {
      _feeStartDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    }

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

      if (controller == _admissionDateController) {
        final now = DateTime.now();
        final isPastMonth = picked.year < now.year || (picked.year == now.year && picked.month < now.month);
        if (isPastMonth) {
          _showPastAdmissionFeeDialog(picked);
        } else {
          setState(() {
            _feeStartDate = DateFormat('yyyy-MM-dd').format(picked);
          });
        }
      }
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
        feeStartDate: _feeStartDate ?? _admissionDateController.text.trim(),
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

              if (_isPastAdmissionDate) ...[
                const SizedBox(height: 10),
                _buildFeeBillingInfoCard(),
              ],

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

  bool get _isPastAdmissionDate {
    if (_admissionDateController.text.trim().isEmpty) return false;
    try {
      final adm = DateTime.parse(_admissionDateController.text.trim());
      final now = DateTime.now();
      return adm.year < now.year || (adm.year == now.year && adm.month < now.month);
    } catch (_) {
      return false;
    }
  }

  Widget _buildFeeBillingInfoCard() {
    final now = DateTime.now();
    DateTime feeStart = now;
    if (_feeStartDate != null && _feeStartDate!.isNotEmpty) {
      try {
        feeStart = DateTime.parse(_feeStartDate!);
      } catch (_) {}
    }

    final isCurrentMonth = feeStart.year == now.year && feeStart.month == now.month;
    final startMonthName = DateFormat('MMMM yyyy').format(feeStart);
    final monthlyFee = double.tryParse(_monthlyFeesController.text.trim()) ?? 0.0;

    int pendingMonths = 1;
    if (!isCurrentMonth) {
      pendingMonths = ((now.year - feeStart.year) * 12) + (now.month - feeStart.month) + 1;
      if (pendingMonths < 1) pendingMonths = 1;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentMonth ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentMonth ? const Color(0xFF86EFAC) : const Color(0xFFFCD34D),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCurrentMonth ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            color: isCurrentMonth ? AppColors.success : const Color(0xFFD97706),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrentMonth
                      ? 'Fees Start: Current Month ($startMonthName)'
                      : 'Fees Pending From: $startMonthName ($pendingMonths Months)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: isCurrentMonth ? const Color(0xFF166534) : const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isCurrentMonth
                      ? 'Past months before $startMonthName are cleared (No past dues).'
                      : 'Pending amount: Rs. ${(pendingMonths * monthlyFee).toStringAsFixed(0)} ($pendingMonths months due).',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isCurrentMonth ? const Color(0xFF15803D) : const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              try {
                final adm = DateTime.parse(_admissionDateController.text.trim());
                _showPastAdmissionFeeDialog(adm);
              } catch (_) {}
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Change',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isCurrentMonth ? AppColors.success : const Color(0xFFD97706),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPastAdmissionFeeDialog(DateTime admissionDate) {
    final now = DateTime.now();
    final admMonthStr = DateFormat('MMMM yyyy').format(admissionDate);
    final curMonthStr = DateFormat('MMMM yyyy').format(now);
    final monthlyFee = double.tryParse(_monthlyFeesController.text.trim()) ?? 0.0;

    // Build list of months between admissionDate and now (max 24)
    final List<DateTime> availableMonths = [];
    DateTime pointer = DateTime(now.year, now.month, 1);
    final admMonthStart = DateTime(admissionDate.year, admissionDate.month, 1);
    while (pointer.isAfter(admMonthStart) || pointer.isAtSameMomentAs(admMonthStart)) {
      availableMonths.add(pointer);
      pointer = DateTime(pointer.year, pointer.month - 1, 1);
      if (availableMonths.length >= 24) break;
    }

    DateTime selectedStart = DateTime(now.year, now.month, 1);
    if (_feeStartDate != null && _feeStartDate!.isNotEmpty) {
      try {
        final parsed = DateTime.parse(_feeStartDate!);
        selectedStart = DateTime(parsed.year, parsed.month, 1);
      } catch (_) {}
    }

    bool hasPendingDues = !(selectedStart.year == now.year && selectedStart.month == now.month);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final monthsCount = hasPendingDues
                ? (((now.year - selectedStart.year) * 12) + (now.month - selectedStart.month) + 1)
                : 1;
            final estimatedPending = (monthsCount * monthlyFee).toStringAsFixed(0);

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
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
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.history_edu_rounded, color: AppColors.primaryBlue, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Past Admission Fee Setup',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textPrimary),
                            ),
                            Text(
                              'Joined in $admMonthStr',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Does this student have unpaid fees from past months?',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),

                  // Option 1: No pending fees (All paid)
                  InkWell(
                    onTap: () {
                      setModalState(() {
                        hasPendingDues = false;
                        selectedStart = DateTime(now.year, now.month, 1);
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: !hasPendingDues ? const Color(0xFFF0FDF4) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: !hasPendingDues ? AppColors.success : AppColors.border,
                          width: !hasPendingDues ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            !hasPendingDues ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                            color: !hasPendingDues ? AppColors.success : AppColors.textMuted,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'No, All Past Fees Paid (Cleared)',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Billing starts from current month ($curMonthStr). Zero past dues.',
                                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Option 2: Yes, has pending fees
                  InkWell(
                    onTap: () {
                      setModalState(() {
                        hasPendingDues = true;
                        if (availableMonths.length > 1 && selectedStart.year == now.year && selectedStart.month == now.month) {
                          selectedStart = availableMonths[1]; // default to last month
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: hasPendingDues ? const Color(0xFFFFFBEB) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: hasPendingDues ? const Color(0xFFD97706) : AppColors.border,
                          width: hasPendingDues ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            hasPendingDues ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                            color: hasPendingDues ? const Color(0xFFD97706) : AppColors.textMuted,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Yes, Has Unpaid Dues from Past',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Choose from which month fees are unpaid.',
                                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (hasPendingDues) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Select Fee Pending Starting Month:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<DateTime>(
                          value: availableMonths.firstWhere(
                            (m) => m.year == selectedStart.year && m.month == selectedStart.month,
                            orElse: () => availableMonths.first,
                          ),
                          isExpanded: true,
                          items: availableMonths.map((m) {
                            final mStr = DateFormat('MMMM yyyy').format(m);
                            final count = (((now.year - m.year) * 12) + (now.month - m.month) + 1);
                            final isCur = m.year == now.year && m.month == now.month;
                            final isAdm = m.year == admissionDate.year && m.month == admissionDate.month;
                            String tag = '';
                            if (isCur) tag = ' (Current Month)';
                            else if (isAdm) tag = ' (Joined Month)';
                            else tag = ' ($count months total)';
                            return DropdownMenuItem<DateTime>(
                              value: m,
                              child: Text('$mStr$tag', style: const TextStyle(fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                selectedStart = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.lightBlue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calculate_rounded, color: AppColors.primaryBlue, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Pending: $monthsCount month(s) × Rs. ${monthlyFee.toStringAsFixed(0)} = Rs. $estimatedPending',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _feeStartDate = DateFormat('yyyy-MM-01').format(selectedStart);
                        });
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save Billing Setting', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
