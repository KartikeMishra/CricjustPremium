import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/user_profile_model.dart';
import '../service/user_info_service.dart';
import '../theme/color.dart';

// ... same imports as before ...
import 'dart:io';

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

  File? _profileImageFile;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl.text = widget.profile.firstName;
    _lastNameCtrl.text = widget.profile.lastName;
    _descCtrl.text = widget.profile.description;
    _dobCtrl.text = widget.profile.dob;
    _gender = widget.profile.gender;
  }
/*
  Future<void> _pickAndCropImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatioPresets: [CropAspectRatioPreset.square],
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(toolbarTitle: 'Crop Image'),
        IOSUiSettings(title: 'Crop Image'),
      ],
    );

    if (cropped != null) {
      setState(() {
        _profileImageFile = File(cropped.path);
      });

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_logged_in_token') ?? '';
      await UserInfoService.uploadProfileImage(token, _profileImageFile!);
    }
  }*/

  Future<void> _selectDate() async {
    final initialDate = DateTime.tryParse(_dobCtrl.text) ?? DateTime(2000);
    final picked = await showDatePicker(
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
    appBar: AppBar(
      backgroundColor: isDark ? Colors.black : AppColors.primary,
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
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 55,
                      backgroundColor: Colors.grey,
                      backgroundImage: _profileImageFile != null
                          ? FileImage(_profileImageFile!)
                          : (widget.profile.profileImage.isNotEmpty
                          ? NetworkImage(widget.profile.profileImage)
                          : null) as ImageProvider?,
                      child: widget.profile.profileImage.isEmpty &&
                          _profileImageFile == null
                          ? Icon(Icons.person, size: 50, color: AppColors.primary)
                          : null,
                    ),
                    /*Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _pickAndCropImage,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit, size: 18, color: Colors.white),
                        ),
                      ),
                    ),*/
                  ],
                ),
              ),
              const SizedBox(height: 30),

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
                decoration: _inputDecoration(hint: 'Tell something about yourself'),
              ),

              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _inputField(TextEditingController controller, String hint) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
      decoration: _inputDecoration(hint: hint),
      validator: (val) => val!.isEmpty ? 'Required' : null,
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true,
      fillColor: isDark ? Colors.grey[850] : Colors.white,
    );
  }
}
