import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/centre_profile.dart';
import '../../database/db_helper.dart';

class CentreProfileScreen extends StatefulWidget {
  const CentreProfileScreen({super.key});

  @override
  State<CentreProfileScreen> createState() => _CentreProfileScreenState();
}

class _CentreProfileScreenState extends State<CentreProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _taglineController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _inchargeController;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _taglineController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _addressController = TextEditingController();
    _inchargeController = TextEditingController();

    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final profile = await DBHelper.instance.getCentreProfile();
    if (mounted) {
      setState(() {
        _nameController.text = profile.centreName;
        _taglineController.text = profile.tagline;
        _phoneController.text = profile.phone;
        _emailController.text = profile.email;
        _addressController.text = profile.address;
        _inchargeController.text = profile.inchargeName;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _inchargeController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final updated = CentreProfile(
      id: 1,
      centreName: _nameController.text.trim(),
      tagline: _taglineController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      address: _addressController.text.trim(),
      inchargeName: _inchargeController.text.trim(),
    );

    await DBHelper.instance.updateCentreProfile(updated);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tuition Centre profile updated successfully! All bills & reports will use these details.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tuition Centre Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              // Circular Logo & Info Card
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlue.withOpacity(0.15),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                        border: Border.all(color: AppColors.primaryYellow, width: 3),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.school_rounded,
                            size: 50,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _nameController.text.isNotEmpty ? _nameController.text : 'SS Tuition Centre',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.lightYellow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _taglineController.text.isNotEmpty ? _taglineController.text : 'Inspiring Minds, Shaping Futures',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.darkYellow),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Live Bill Header Preview
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.visibility_outlined, size: 16, color: AppColors.primaryBlue),
                        SizedBox(width: 6),
                        Text(
                          'Live Receipt & Bill Header Preview',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Text(
                      _nameController.text.toUpperCase(),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkBlue),
                    ),
                    Text(
                      _taglineController.text,
                      style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: AppColors.darkYellow),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_addressController.text} | Phone: ${_phoneController.text}',
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Form Section: Centre Information
              const Text('Centre Information', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 12),

              TextFormField(
                controller: _nameController,
                onChanged: (_) => setState(() {}),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter centre name' : null,
                decoration: InputDecoration(
                  labelText: 'Tuition Centre Name *',
                  prefixIcon: const Icon(Icons.school_rounded, color: AppColors.primaryBlue),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: _taglineController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Motto / Tagline',
                  prefixIcon: const Icon(Icons.lightbulb_outline_rounded, color: AppColors.primaryBlue),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Form Section: Contact & Billing Address
              const Text('Contact & Billing Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              const Text(
                'These details appear on printed PDF fee receipts and attendance reports.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _phoneController,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.phone,
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter phone number' : null,
                decoration: InputDecoration(
                  labelText: 'Primary Contact Phone *',
                  prefixIcon: const Icon(Icons.phone_rounded, color: AppColors.primaryBlue),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: _emailController,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primaryBlue),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: _addressController,
                onChanged: (_) => setState(() {}),
                maxLines: 2,
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter address' : null,
                decoration: InputDecoration(
                  labelText: 'Centre Address (Appears on Bills) *',
                  prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.primaryBlue),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: _inchargeController,
                decoration: InputDecoration(
                  labelText: 'Authorized Signatory / Tutor In-Charge',
                  prefixIcon: const Icon(Icons.verified_user_outlined, color: AppColors.primaryBlue),
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

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveProfile,
                  icon: _isSaving
                      ? const SizedBox.shrink()
                      : const Icon(Icons.save_rounded, color: Colors.white),
                  label: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Save & Update All Bills',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
}
