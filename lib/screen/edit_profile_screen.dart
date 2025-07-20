import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/user_profile_model.dart';
import '../service/user_info_service.dart';
import '../theme/color.dart';

class EditProfileScreen extends StatefulWidget {
  final UserProfile profile;
  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  String _gender = 'male';

  @override
  void initState() {
    super.initState();
    _firstNameCtrl.text = widget.profile.firstName;
    _lastNameCtrl.text = widget.profile.lastName;
    _descCtrl.text = widget.profile.description;
    _dobCtrl.text = widget.profile.dob;
    _gender = widget.profile.gender;
  }

  Future<void> _selectDate() async {
    DateTime initialDate = DateTime.tryParse(_dobCtrl.text) ?? DateTime(2000);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _dobCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_logged_in_token') ?? '';

      final result = await UserInfoService.updateUserInfo(
        apiToken: token,
        updatedFields: {
          'first_name': _firstNameCtrl.text,
          'last_name': _lastNameCtrl.text,
          'user_dob': _dobCtrl.text,
          'user_gender': _gender,
          'description': _descCtrl.text,
        },
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Updated successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _label('First Name'),
              _inputField(_firstNameCtrl, 'Enter first name'),

              _label('Last Name'),
              _inputField(_lastNameCtrl, 'Enter last name'),

              _label('Date of Birth'),
              GestureDetector(
                onTap: _selectDate,
                child: AbsorbPointer(
                  child: _inputField(_dobCtrl, 'YYYY-MM-DD'),
                ),
              ),

              _label('Gender'),
              DropdownButtonFormField<String>(
                value: _gender,
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                ],
                onChanged: (val) => setState(() => _gender = val ?? 'male'),
                decoration: _inputDecoration(),
              ),

              _label('Description'),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: _inputDecoration(
                  hint: 'Tell something about yourself',
                ),
              ),

              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                ),
                icon: const Icon(Icons.save, color: Colors.white),
                label: const Text(
                  'Save Changes',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 6),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    ),
  );

  Widget _inputField(TextEditingController controller, String hint) {
    return TextFormField(
      controller: controller,
      decoration: _inputDecoration(hint: hint),
      validator: (val) => val!.isEmpty ? 'Required' : null,
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true,
      fillColor: Colors.white,
    );
  }
}
