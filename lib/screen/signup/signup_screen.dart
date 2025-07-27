// Updated Flutter SignupScreen with dynamic player-type logic and numeric-only phone input

import 'package:cricjust_premium/screen/signup/signup_controller.dart';
import 'package:cricjust_premium/screen/signup/signup_enums.dart';
import 'package:cricjust_premium/screen/signup/signup_widget/signup_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/color.dart';
import '../../theme/text_styles.dart';
import '../home_screen/home_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Image.asset('lib/asset/images/cricjust_logo.png', height: 80),
              const SizedBox(height: 16),
              signUpTextFormField(
                controller: _nameCtrl,
                hintText: 'Full Name',
                validator: (v) => v!.trim().isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 12),
              signUpTextFormField(
                controller: _emailCtrl,
                hintText: 'Email',
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v == null ||
                        !RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w]{2,4}").hasMatch(v)
                    ? 'Enter valid email'
                    : null,
              ),
              const SizedBox(height: 12),
              signUpTextFormField(
                controller: _phoneCtrl,
                hintText: 'Phone Number',
                keyboardType: TextInputType.number,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) => v == null || v.length != 10
                    ? 'Enter 10 digit number'
                    : null,
              ),
              const SizedBox(height: 12),
              signUpTextFormField(
                hintText: 'Date of Birth',
                controller: _dobCtrl,
                readOnly: true,
                decoration: signUpDecoration('Date of Birth').copyWith(
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () =>
                        SignupController.pickDate(context).then((String value) {
                      _dobCtrl.text = value;
                    }),
                  ),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Select DOB' : null,
              ),
              const SizedBox(height: 12),
              _genderWidget(),
              const SizedBox(height: 12),
              _userTypeWidget(),
              if (_userType == 'cricket_player') ...[
                const SizedBox(height: 12),
                _playerTypeWidget(),
                if (_playerType == 'batter' || _playerType == 'all_rounder')
                  Column(
                    children: [
                      const SizedBox(height: 12),
                      _batterTypeWidget(),
                    ],
                  ),
                if (_playerType == 'bowler' || _playerType == 'all_rounder')
                  Column(
                    children: [
                      const SizedBox(height: 12),
                      _bowlerTypeWidget(),
                    ],
                  ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                decoration: signUpDecoration('Password').copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) =>
                    v == null || v.length < 6 ? 'Min 6 characters' : null,
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
                      borderRadius: BorderRadius.circular(8),
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
    );
  }

  Widget _genderWidget() {
    return DropdownButtonFormField<String>(
      decoration: signUpDecoration('Gender'),
      value: _gender,
      items: SignupGender.values
          .map(
            (g) => DropdownMenuItem(
              value: g.name,
              child: Text(g.value),
            ),
          )
          .toList(),
      onChanged: (val) => setState(() => _gender = val),
      validator: (v) => v == null ? 'Select gender' : null,
    );
  }

  Widget _userTypeWidget() {
    return DropdownButtonFormField<String>(
      decoration: signUpDecoration('User Type'),
      value: _userType,
      items: PlayerRole.values
          .map(
            (e) => DropdownMenuItem(
              value: e.value,
              child: Text(e.name),
            ),
          )
          .toList(),
      onChanged: (val) => setState(() {
        _userType = val;
        _playerType = _batterType = _bowlerType = null;
      }),
      validator: (v) => v == null ? 'Select user type' : null,
    );
  }

  Widget _playerTypeWidget() {
    return DropdownButtonFormField<String>(
      decoration: signUpDecoration('Player Type'),
      value: _playerType,
      items: ['All-Rounder', 'Batter', 'Bowler', 'Wicket-Keeper']
          .map(
            (e) => DropdownMenuItem(
              value: e.toLowerCase().replaceAll('-', '_'),
              child: Text(e),
            ),
          )
          .toList(),
      onChanged: (val) => setState(() => _playerType = val),
      validator: (v) => v == null ? 'Select player type' : null,
    );
  }

  Widget _batterTypeWidget() {
    return DropdownButtonFormField<String>(
      decoration: signUpDecoration('Batter Type'),
      value: _batterType,
      items: ['Left', 'Right']
          .map(
            (e) => DropdownMenuItem(value: e, child: Text(e)),
          )
          .toList(),
      onChanged: (val) => setState(() => _batterType = val),
      validator: (v) => v == null ? 'Select batter type' : null,
    );
  }

  Widget _bowlerTypeWidget() {
    return DropdownButtonFormField<String>(
      decoration: signUpDecoration('Bowler Type'),
      value: _bowlerType,
      items: ['Pace', 'Spin']
          .map(
            (e) => DropdownMenuItem(value: e, child: Text(e)),
          )
          .toList(),
      onChanged: (val) => setState(() => _bowlerType = val),
      validator: (v) => v == null ? 'Select bowler type' : null,
    );
  }

  void _signup() {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    SignupController.signup(
      firstName: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      password: _passwordCtrl.text,
      dob: _dobCtrl.text,
      gender: _gender ?? '',
      userType: _userType ?? '',
      playerType: _playerType ?? '',
      batterType: _batterType,
      bowlerType: _bowlerType,
      onSuccess: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      },
      onComplete: () => setState(() => _isLoading = false),
      onFailure: (message) => setState(() => _errorMessage = message),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }
}
