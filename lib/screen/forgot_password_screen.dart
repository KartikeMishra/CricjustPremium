// lib/screen/forgot_password_screen.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../service/auth_recovery_service.dart';
import '../theme/color.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

enum _Step { email, otp, reset }

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  final _formEmailKey = GlobalKey<FormState>();
  final _formOtpKey = GlobalKey<FormState>();
  final _formPassKey = GlobalKey<FormState>();

  _Step _step = _Step.email;
  bool _loading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;

  // resend cooldown
  int _cooldown = 0;
  Timer? _timer;

  // ---- server-side field errors ----
  String? _emailServerError;
  String? _otpServerError;

  @override
  void dispose() {
    _timer?.cancel();
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  Color get _primary => AppColors.primary; // fallback to your theme

  void _showMsg(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: error ? Colors.red : Colors.green,
        ),
      );
  }

  String? _validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Enter your email';
    final re = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!re.hasMatch(s)) return 'Enter a valid email';
    return null;
  }

  String? _validateOtp(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Enter OTP';
    if (s.length < 4) return 'OTP seems too short';
    return null;
  }

  String? _validatePass(String? v) {
    final s = (v ?? '').trim();
    if (s.length < 6) return 'Min 6 characters';
    return null;
  }

  void _startCooldown([int sec = 60]) {
    _timer?.cancel();
    setState(() => _cooldown = sec);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _cooldown -= 1;
        if (_cooldown <= 0) {
          t.cancel();
        }
      });
    });
  }

  Future<void> _onSendOtp() async {
    if (!_formEmailKey.currentState!.validate()) return;
    final email = _emailCtrl.text.trim();

    // clear previous server error
    setState(() => _emailServerError = null);

    setState(() => _loading = true);
    final resp = await AuthRecoveryService.sendOtp(email: email);
    setState(() => _loading = false);

    if (!resp.ok) {
      // try to bind to the specific field if server sent error.email
      final err = resp.data?['error'];
      if (err is Map && err['email'] != null) {
        setState(() => _emailServerError = err['email'].toString());
      }
      _showMsg(resp.message, error: true);
      return;
    }
    _showMsg(resp.message);
    _startCooldown(60);
    setState(() => _step = _Step.otp);
  }

  Future<void> _onVerifyOtp() async {
    if (!_formOtpKey.currentState!.validate()) return;
    final email = _emailCtrl.text.trim();
    final otp = _otpCtrl.text.trim();

    // clear previous server error
    setState(() => _otpServerError = null);

    setState(() => _loading = true);
    final resp = await AuthRecoveryService.verifyOtp(email: email, otp: otp);
    setState(() => _loading = false);

    if (!resp.ok) {
      final err = resp.data?['error'];
      if (err is Map && err['otp'] != null) {
        setState(() => _otpServerError = err['otp'].toString());
      }
      _showMsg(resp.message, error: true);
      return;
    }
    _showMsg('OTP verified ✔');
    setState(() => _step = _Step.reset);
  }

  Future<void> _onSetNewPassword() async {
    if (!_formPassKey.currentState!.validate()) return;
    if (_passCtrl.text.trim() != _pass2Ctrl.text.trim()) {
      _showMsg('Passwords do not match', error: true);
      return;
    }

    final email = _emailCtrl.text.trim();
    final otp = _otpCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    setState(() => _loading = true);

    final resp = await AuthRecoveryService.setNewPassword(
      email: email,
      otp: otp,
      newPassword: pass,
      confirmPassword: _pass2Ctrl.text.trim(), // ⬅️ pass confirm
    );


    setState(() => _loading = false);

    if (!resp.ok) {
      _showMsg(resp.message, error: true);
      return;
    }
    _showMsg('Password changed successfully');

    // Go to login
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  Future<void> _onResendOtp() async {
    if (_cooldown > 0) return;
    await _onSendOtp();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? Colors.black : Colors.grey[100],
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(108),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: dark ? 15 : 0, sigmaY: dark ? 15 : 0),
            child: Container(
              decoration: dark
                  ? BoxDecoration(color: Colors.white.withValues(alpha: 0.05))
                  : const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, Color(0xFF42A5F5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: kToolbarHeight,
                      child: Row(
                        children: const [
                          BackButton(color: Colors.white),
                          Expanded(
                            child: Center(
                              child: Text(
                                'Forgot Password',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: kToolbarHeight),
                        ],
                      ),
                    ),
                    // subtle step labels
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        children: [
                          _stepChip('Email', _step.index >= 0, dark),
                          _stepChip('OTP', _step.index >= 1, dark),
                          _stepChip('Reset', _step.index >= 2, dark),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Padding(
          key: ValueKey(_step),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: _buildStep(context, dark),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, bool dark) {
    switch (_step) {
      case _Step.email:
        return Form(
          key: _formEmailKey,
          child: _card(
            dark: dark,
            children: [
              const Text(
                'We’ll send a One-Time Password (OTP) to your email address.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ).copyWith(errorText: _emailServerError),
                validator: _validateEmail,
              ),
              const SizedBox(height: 18),
              _primaryBtn(
                text: _loading ? 'Sending...' : 'Send OTP',
                onTap: _loading ? null : _onSendOtp,
              ),
            ],
          ),
        );

      case _Step.otp:
        return Form(
          key: _formOtpKey,
          child: _card(
            dark: dark,
            children: [
              Text(
                'Enter the OTP sent to ${_emailCtrl.text.trim()}',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'OTP',
                  counterText: '',
                  prefixIcon: Icon(Icons.shield_outlined),
                ).copyWith(errorText: _otpServerError),
                validator: _validateOtp,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (_cooldown > 0)
                    Text(
                      'Resend available in $_cooldown s',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: (_cooldown > 0 || _loading) ? null : _onResendOtp,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Resend OTP'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _primaryBtn(
                text: _loading ? 'Verifying...' : 'Verify OTP',
                onTap: _loading ? null : _onVerifyOtp,
              ),
            ],
          ),
        );

      case _Step.reset:
        return Form(
          key: _formPassKey,
          child: _card(
            dark: dark,
            children: [
              const Text(
                'Create a new password for your account.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passCtrl,
                obscureText: _obscure1,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure1 ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure1 = !_obscure1),
                  ),
                ),
                validator: _validatePass,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pass2Ctrl,
                obscureText: _obscure2,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure2 ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure2 = !_obscure2),
                  ),
                ),
                validator: _validatePass,
              ),
              const SizedBox(height: 18),
              _primaryBtn(
                text: _loading ? 'Saving...' : 'Set New Password',
                onTap: _loading ? null : _onSetNewPassword,
              ),
            ],
          ),
        );
    }
  }

  Widget _card({required bool dark, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: dark ? Colors.black54 : Colors.grey.shade300,
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  Widget _primaryBtn({required String text, VoidCallback? onTap}) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
    );
  }

  Widget _stepChip(String label, bool active, bool dark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? (dark ? Colors.blueGrey[700] : Colors.white.withValues(alpha: 0.2))
            : (dark ? Colors.transparent : Colors.white.withValues(alpha: 0.15)),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}
