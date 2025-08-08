import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../theme/color.dart';
import '../theme/text_styles.dart';
import 'home_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();

  String? _gender, _userType, _playerType, _batterType, _bowlerType;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  File? _profileImage;

  double _passwordStrength = 0;
  String _passwordStrengthLabel = '';
  Color _passwordStrengthColor = Colors.red;

  void _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      _dobCtrl.text = DateFormat('yyyy-MM-dd').format(date);
    }
  }



  void _checkPasswordStrength(String password) {
    double strength = 0;
    if (password.length >= 6) strength += 0.25;
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.25;
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.25;
    if (password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) strength += 0.25;

    String label;
    Color color;
    if (strength <= 0.25) {
      label = 'Weak';
      color = Colors.red;
    } else if (strength <= 0.5) {
      label = 'Fair';
      color = Colors.orange;
    } else if (strength <= 0.75) {
      label = 'Good';
      color = Colors.lightGreen;
    } else {
      label = 'Strong';
      color = Colors.green;
    }

    setState(() {
      _passwordStrength = strength;
      _passwordStrengthLabel = label;
      _passwordStrengthColor = color;
    });
  }
  Future<void> _pickAndCropImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose Image Source', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 80);

    if (pickedFile == null) return;

    // 🔍 Optional: Show preview before cropping
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Use this image?'),
        content: Image.file(File(pickedFile.path)),
        actions: [
          TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(context, false)),
          ElevatedButton(child: const Text('Continue'), onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );

    if (confirm != true) return;

    // ✂️ Crop
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 80,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: Colors.blue,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Crop Image'),
      ],
    );

    if (croppedFile != null) {
      setState(() {
        _profileImage = File(croppedFile.path);
      });
    }
  }


  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse('https://cricjust.in/wp-json/custom-api-for-cricket/register');
      final request = http.MultipartRequest('POST', uri);

      request.fields['first_name'] = _nameCtrl.text.trim();
      request.fields['user_email'] = _emailCtrl.text.trim();
      request.fields['user_phone'] = _phoneCtrl.text.trim();
      request.fields['user_password'] = _passwordCtrl.text;
      request.fields['user_dob'] = _dobCtrl.text;
      request.fields['user_gender'] = _gender ?? '';
      request.fields['user_type'] = _userType ?? '';

      if (_userType == 'cricket_player') {
        request.fields['player_type'] = _playerType ?? '';
        if (_playerType == 'batter' || _playerType == 'all_rounder') {
          request.fields['batter_type'] = _batterType?.toLowerCase() ?? '';
        }
        if (_playerType == 'bowler' || _playerType == 'all_rounder') {
          request.fields['bowler_type'] = _bowlerType?.toLowerCase() ?? '';
        }
      }

      final response = await request.send();
      final respStr = await response.stream.bytesToString();
      final data = json.decode(respStr) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['status'] == 1) {
        final token = data['api_logged_in_token'] as String?;
        final userData = data['data'] as Map<String, dynamic>;
        final extra = data['extra_data'] as Map<String, dynamic>? ?? {};
        final prefs = await SharedPreferences.getInstance();

        if (token != null) await prefs.setString('api_logged_in_token', token);
        await prefs.setString('userName', extra['first_name'] ?? userData['display_name'] ?? '');
        await prefs.setString('userEmail', userData['user_email'] ?? '');

        String? uploadedUrl;
        if (_profileImage != null) {
          final uploadUri = Uri.parse(
            'https://cricjust.in/wp-json/custom-api-for-cricket/upload-cricket-user-images?api_logged_in_token=$token',
          );

          final uploadRequest = http.MultipartRequest('POST', uploadUri)
            ..files.add(await http.MultipartFile.fromPath('user_profile_image', _profileImage!.path));

          final uploadResp = await uploadRequest.send();
          final uploadStr = await uploadResp.stream.bytesToString();
          final uploadData = json.decode(uploadStr);
          if (uploadResp.statusCode == 200 && uploadData['status'] == 1) {
            uploadedUrl = uploadData['url'];
            await prefs.setString('profilePic', uploadedUrl ?? '');
          }
        } else {
          await prefs.setString('profilePic', extra['user_profile_image'] ?? '');
        }


        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
        );
      } else {
        setState(() => _errorMessage = data['message'] ?? 'Signup failed');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Could not signup. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.grey[100],
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFE3F2FD),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: const Text(
              'Sign Up',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // 👇 Image Picker with cropping preview
                GestureDetector(
                  onTap: _pickAndCropImage,
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.grey[300],
                    backgroundImage:
                    _profileImage != null ? FileImage(_profileImage!) : null,
                    child: _profileImage == null
                        ? const Icon(Icons.camera_alt, color: Colors.white, size: 30)
                        : null,
                  ),
                ),

                const SizedBox(height: 16),

// 👇 App Logo
                Image.asset(
                  isDark ? 'lib/asset/images/Theme1.png' : 'lib/asset/images/cricjust_logo.png',
                  height: 80,
                ),
                const SizedBox(height: 20),

                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: _decoration('Full Name'),
                  validator: (v) => v!.trim().isEmpty ? 'Enter name' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: _decoration('Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v == null || !RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w]{2,4}").hasMatch(v)
                      ? 'Enter valid email'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: _decoration('Phone Number'),
                  keyboardType: TextInputType.number,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) => v == null || v.length != 10 ? 'Enter 10 digit number' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _dobCtrl,
                  readOnly: true,
                  decoration: _decoration('Date of Birth').copyWith(
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: _pickDate,
                    ),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Select DOB' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: _decoration('Gender'),
                  value: _gender,
                  items: ['Male', 'Female', 'Other']
                      .map((g) => DropdownMenuItem(value: g.toLowerCase(), child: Text(g)))
                      .toList(),
                  onChanged: (val) => setState(() => _gender = val),
                  validator: (v) => v == null ? 'Select gender' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: _decoration('User Type'),
                  value: _userType,
                  items: [
                    DropdownMenuItem(value: 'cricket_player', child: Text('Player')),
                    DropdownMenuItem(value: 'cricket_umpire', child: Text('Umpire')),
                    DropdownMenuItem(value: 'cricket_scorer', child: Text('Scorer')),
                    DropdownMenuItem(value: 'cricket_commentator', child: Text('Commentator')),
                  ],
                  onChanged: (val) => setState(() {
                    _userType = val;
                    _playerType = _batterType = _bowlerType = null;
                  }),
                  validator: (v) => v == null ? 'Select user type' : null,
                ),
                if (_userType == 'cricket_player') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: _decoration('Player Type'),
                    value: _playerType,
                    items: ['All-Rounder', 'Batter', 'Bowler', 'Wicket-Keeper']
                        .map((e) => DropdownMenuItem(
                        value: e.toLowerCase().replaceAll('-', '_'), child: Text(e)))
                        .toList(),
                    onChanged: (val) => setState(() => _playerType = val),
                    validator: (v) => v == null ? 'Select player type' : null,
                  ),
                  if (_playerType == 'batter' || _playerType == 'all_rounder') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: _decoration('Batter Type'),
                      value: _batterType,
                      items: ['Left', 'Right']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) => setState(() => _batterType = val),
                      validator: (v) => v == null ? 'Select batter type' : null,
                    ),
                  ],
                  if (_playerType == 'bowler' || _playerType == 'all_rounder') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: _decoration('Bowler Type'),
                      value: _bowlerType,
                      items: ['Pace', 'Spin']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) => setState(() => _bowlerType = val),
                      validator: (v) => v == null ? 'Select bowler type' : null,
                    ),
                  ],
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  onChanged: _checkPasswordStrength,
                  decoration: _decoration('Password').copyWith(
                    suffixIcon: IconButton(
                      icon:
                      Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) => v == null || v.length < 6 ? 'Min 6 characters' : null,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _passwordStrength,
                  minHeight: 6,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(_passwordStrengthColor),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _passwordStrengthLabel,
                    style: TextStyle(
                      color: _passwordStrengthColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_errorMessage != null)
                  Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isLoading ? null : _signup,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      'Sign Up',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already have an account? "),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        'Login',
                        style: AppTextStyles.heading.copyWith(
                          color: AppColors.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
