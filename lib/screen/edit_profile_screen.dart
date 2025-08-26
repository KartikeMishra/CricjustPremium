// lib/screen/edit_profile_screen.dart
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/user_profile_model.dart';
import '../service/user_info_service.dart';
import '../service/user_image_service.dart';
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
  final _descCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();

  String _gender = 'male';
  String? _imageUrl;

  // NEW: user type (role)
  String? _userType; // 'cricket_player' | 'cricket_umpire' | 'cricket_scorer' | 'cricket_commentator'

  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl.text = widget.profile.firstName;
    _descCtrl.text      = widget.profile.description;
    _dobCtrl.text       = widget.profile.dob;
    _gender             = widget.profile.gender;
    _imageUrl = widget.profile.profileImage.isNotEmpty ? widget.profile.profileImage : null;
    _loadInitialUserType();
  }

  Future<void> _loadInitialUserType() async {
    // Prefer saved userType, else first role, else profile fallback, else null
    final prefs = await SharedPreferences.getInstance();
    final savedUserType = prefs.getString('userType');
    final roles = prefs.getStringList('roles') ?? [];
    final rolesCsv = prefs.getString('roles_csv');

    String? initial = savedUserType;
    if (initial == null || initial.isEmpty) {
      if (roles.isNotEmpty) {
        initial = roles.first;
      } else if ((rolesCsv ?? '').isNotEmpty) {
        initial = rolesCsv!.split(',').first.trim();
      }
    }
    // sanity check against allowed set
    const allowed = {
      'cricket_player',
      'cricket_umpire',
      'cricket_scorer',
      'cricket_commentator',
    };
    if (initial != null && !allowed.contains(initial)) {
      initial = null;
    }
    setState(() => _userType = initial);
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _descCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_logged_in_token') ?? '';
    if (token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login required')),
      );
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 70, maxWidth: 900);
    if (picked == null) return;

    final file = File(picked.path);
    final sizeMB = (await file.length()) / (1024 * 1024);
    if (sizeMB > 2) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image must be under 2 MB')),
      );
      return;
    }

    setState(() => _uploading = true);
    try {
      final url = await UserImageService.uploadAndGetUrl(
        token: token,
        file: file,
        postTimeout: const Duration(seconds: 30),
      );
      if (!mounted) return;
      setState(() => _imageUrl = url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo uploaded ✔️')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _selectDate() async {
    DateTime? initial;
    try {
      initial = DateFormat('yyyy-MM-dd').parse(_dobCtrl.text);
    } catch (_) {
      initial = DateTime(2000, 1, 1);
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _dobCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
      setState(() {});
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_logged_in_token') ?? '';
      if (token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login required'), backgroundColor: Colors.red),
        );
        return;
      }

      final updatedFields = <String, String>{
        'first_name':  _firstNameCtrl.text,
        'user_dob':    _dobCtrl.text,
        'user_gender': _gender,
        'description': _descCtrl.text,
      };

      // include profile image if changed
      if ((_imageUrl ?? '').isNotEmpty) {
        updatedFields['user_profile_image'] = _imageUrl!;
      }

      // NEW: include user_type if selected
      if ((_userType ?? '').isNotEmpty) {
        updatedFields['user_type'] = _userType!;
      }

      final result = await UserInfoService.updateUserInfo(
        apiToken: token,
        updatedFields: updatedFields,
      );

      final ok = result['ok'] == true;
      final msg = (result['message'] ?? (ok ? 'Updated successfully' : 'Update failed')).toString();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: ok ? Colors.green : Colors.red),
      );

      if (ok) {
        // Persist latest roles/user_type locally for the rest of the app
        final data = (result['data'] ?? {}) as Map<String, dynamic>;
        final extra = (result['extra_data'] ?? {}) as Map<String, dynamic>;

        // roles
        final rolesDyn = data['roles'];
        List<String> roles = [];
        if (rolesDyn is List) {
          roles = rolesDyn.map((e) => e.toString()).toList();
        } else if (rolesDyn is String) {
          roles = rolesDyn.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        }
        await prefs.setStringList('roles', roles);
        await prefs.setString('roles_csv', roles.join(','));
        final isAdmin = roles.map((r) => r.toLowerCase()).any((r) => r.contains('admin'));
        await prefs.setBool('is_admin', isAdmin);

        // user_type (from our selection or from extra_data)
        final newUserType = _userType ?? (extra['user_type']?.toString() ?? '');
        if (newUserType.isNotEmpty) {
          await prefs.setString('userType', newUserType);
          // legacy keys (if other screens read them)
          await prefs.setString('role', newUserType);
          await prefs.setString('user_role', newUserType);
        }

        Navigator.pop(context, true); // tell ProfileScreen to refresh
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Edit Profile',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.75)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ===== Header =====
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 190,
                      decoration: BoxDecoration(
                        gradient: isDark
                            ? const LinearGradient(
                          colors: [Color(0xFF1A1A1A), Color(0xFF111111)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                            : const LinearGradient(
                          colors: [Color(0xFFE3F2FD), Colors.white],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    Positioned(top: -18, left: -12, child: _bubble(86, Colors.white.withValues(alpha: 0.18))),
                    Positioned(bottom: -22, right: -16, child: _bubble(120, Colors.white.withValues(alpha: 0.14))),
                    BackdropFilter(filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6), child: Container(height: 190)),
                    Positioned.fill(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // avatar with edit overlay
                          Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primary.withValues(alpha: 0.7),
                                      AppColors.primary.withValues(alpha: 0.2),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 46,
                                  backgroundColor: Colors.white,
                                  backgroundImage: (_imageUrl != null && _imageUrl!.isNotEmpty)
                                      ? NetworkImage(_imageUrl!)
                                      : null,
                                  child: (_imageUrl == null || _imageUrl!.isEmpty)
                                      ? Icon(Icons.person, size: 46, color: AppColors.primary)
                                      : null,
                                ),
                              ),
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: InkWell(
                                  onTap: _uploading ? null : () => _pickAndUpload(ImageSource.gallery),
                                  child: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                      child: _uploading
                                          ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                          : const Icon(Icons.edit, size: 16, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.profile.displayName,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.profile.email,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ===== Form card =====
              Container(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF101010) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFEAEFF5)),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('First Name'),
                    _inputField(_firstNameCtrl, 'Enter first name'),

                    _label('Date of Birth'),
                    GestureDetector(
                      onTap: _selectDate,
                      child: AbsorbPointer(child: _inputField(_dobCtrl, 'YYYY-MM-DD')),
                    ),

                    _label('Gender'),
                    Row(
                      children: [
                        _genderChip('male', Icons.male),
                        const SizedBox(width: 8),
                        _genderChip('female', Icons.female),
                      ],
                    ),

                    // NEW: User Type
                    _label('User Type'),
                    DropdownButtonFormField<String>(
                      value: _userType,
                      decoration: _inputDecoration(hint: 'Select user type'),
                      items: const [
                        DropdownMenuItem(value: 'cricket_player', child: Text('Player')),
                        DropdownMenuItem(value: 'cricket_umpire', child: Text('Umpire')),
                        DropdownMenuItem(value: 'cricket_scorer', child: Text('Scorer')),
                        DropdownMenuItem(value: 'cricket_commentator', child: Text('Commentator')),
                      ],
                      onChanged: (v) => setState(() => _userType = v),
                    ),

                    _label('Description'),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 3,
                      decoration: _inputDecoration(hint: 'Tell something about yourself'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
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
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- UI helpers ----------
  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 6),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
  );

  Widget _inputField(TextEditingController controller, String hint) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
      decoration: _inputDecoration(hint: hint),
      validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE3EDF8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.7), width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true,
      fillColor: isDark ? const Color(0xFF161616) : const Color(0xFFF7FAFF),
    );
  }

  Widget _genderChip(String value, IconData icon) {
    final selected = _gender == value;
    final color = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChoiceChip(
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      avatar: Icon(icon, size: 16, color: selected ? Colors.white : color),
      label: Text(
        value[0].toUpperCase() + value.substring(1),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
        ),
      ),
      selected: selected,
      selectedColor: color,
      backgroundColor: isDark ? const Color(0xFF161616) : const Color(0xFFF7FAFF),
      shape: StadiumBorder(
        side: BorderSide(color: selected ? color : (isDark ? Colors.white10 : const Color(0xFFE3EDF8))),
      ),
      onSelected: (v) {
        if (v) setState(() => _gender = value);
      },
    );
  }

  Widget _bubble(double size, Color color) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}
