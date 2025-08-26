import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../model/create_user_model.dart';
import '../service/create_service.dart';
import '../theme/color.dart';

class CreateUserScreen extends StatefulWidget {
  final String apiToken; // e.g., 3331741743926363
  const CreateUserScreen({super.key, required this.apiToken});

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _phoneCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // Use local supported types to avoid service coupling
  static const List<String> supportedUserTypes = <String>[
    'cricket_player',
    'cricket_umpire',
    'cricket_scorer',
    'cricket_commentator',
  ];

  String _userType = supportedUserTypes.first; // default
  String? _playerType; // for cricket_player only
  String? _batterType; // left/right
  String? _bowlerType; // pace/spin

  bool _submitting = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _firstNameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  bool get isPlayer => _userType == 'cricket_player';

  bool get needsBatterType {
    if (!isPlayer) return false;
    return _playerType == 'batter' ||
        _playerType == 'all-rounder' ||
        _playerType == 'wicket-keeper';
  }

  bool get needsBowlerType {
    if (!isPlayer) return false;
    return _playerType == 'bowler' || _playerType == 'all-rounder';
  }

  Future<void> _submit() async {
    if (_submitting) return;

    FocusScope.of(context).unfocus();

    // Local form validation
    final formOk = _formKey.currentState?.validate() ?? false;
    if (!formOk) return;

    final req = CreateUserRequest(
      userPhone: _phoneCtrl.text,
      firstName: _firstNameCtrl.text,
      userEmail: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      userType: _userType,
      playerType: isPlayer ? _playerType : null,
      batterType: isPlayer ? _batterType : null,
      bowlerType: isPlayer ? _bowlerType : null,
    );

    // Domain validation (combination rules)
    final moreErrors = req.validate();
    if (moreErrors.isNotEmpty) {
      _showSnack(moreErrors.values.first, Colors.red);
      return;
    }

    setState(() => _submitting = true);
    final resp =
    await CreateService.createUser(apiToken: widget.apiToken, request: req);
    if (!mounted) return;
    setState(() => _submitting = false);

    _showSnack(resp.message, resp.ok ? Colors.green : Colors.red);

    if (resp.ok) {
      _formKey.currentState?.reset();
      _phoneCtrl.clear();
      _firstNameCtrl.clear();
      _emailCtrl.clear();
      setState(() {
        _userType = supportedUserTypes.first;
        _playerType = null;
        _batterType = null;
        _bowlerType = null;
      });
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
  }

  String _pretty(String v) => v.replaceAll('_', ' ').replaceFirstMapped(
      RegExp(r'^\w'), (m) => m.group(0)!.toUpperCase());

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    IconData? icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF111214)
          : const Color(0xFFF6F7F9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: .2),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: .15),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppColors.primary.withValues(alpha: .9),
          width: 1.6,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0D0E) : const Color(0xFFF2F4F7),
      appBar: _fancyAppBar(isDark),
      body: SafeArea(
        child: Stack(
          children: [
            // subtle top gradient splash
            Positioned(
              left: -120,
              top: -120,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: .18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _heroCard(isDark),
                    const SizedBox(height: 16),

                    // Basics
                    _glassCard(
                      isDark: isDark,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _phoneCtrl,
                            decoration: _inputDecoration(
                              label: 'Phone Number',
                              hint: '10-digit number',
                              icon: Icons.phone_outlined,
                              suffix: const Icon(Icons.verified_user_outlined, size: 20),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            validator: (v) {
                              final s = (v ?? '').trim();
                              if (!RegExp(r'^\d{10}$').hasMatch(s)) {
                                return 'Enter a valid 10-digit phone number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _firstNameCtrl,
                            decoration: _inputDecoration(
                              label: 'First Name',
                              icon: Icons.person_outline,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'First name is required'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _emailCtrl,
                            decoration: _inputDecoration(
                              label: 'Email (optional)',
                              icon: Icons.alternate_email,
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              final s = (v ?? '').trim();
                              if (s.isEmpty) return null;
                              final ok = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s);
                              return ok ? null : 'Enter a valid email address';
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            decoration: _inputDecoration(
                              label: 'User Type',
                              icon: Icons.badge_outlined,
                            ),
                            value: _userType,
                            items: supportedUserTypes
                                .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(_pretty(t)),
                            ))
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _userType = v;
                                _playerType = null;
                                _batterType = null;
                                _bowlerType = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    // Player-specific
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: isPlayer
                          ? Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: _glassCard(
                          isDark: isDark,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _sectionHeader(
                                title: 'Player Details',
                                icon: Icons.sports_cricket_outlined,
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                decoration: _inputDecoration(
                                  label: 'Player Type',
                                  icon: Icons.category_outlined,
                                ),
                                value: _playerType,
                                items: const [
                                  DropdownMenuItem(
                                      value: 'all-rounder', child: Text('All-rounder')),
                                  DropdownMenuItem(
                                      value: 'batter', child: Text('Batter')),
                                  DropdownMenuItem(
                                      value: 'bowler', child: Text('Bowler')),
                                  DropdownMenuItem(
                                      value: 'wicket-keeper',
                                      child: Text('Wicket-keeper')),
                                ],
                                onChanged: (v) {
                                  setState(() {
                                    _playerType = v;
                                    _batterType = null;
                                    _bowlerType = null;
                                  });
                                },
                                validator: (v) =>
                                (v == null || v.isEmpty) ? 'Select player type' : null,
                              ),
                              const SizedBox(height: 12),

                              if (needsBatterType)
                                _chipGroup(
                                  label: 'Batter Type',
                                  hint: 'Choose left/right',
                                  options: const ['left', 'right'],
                                  value: _batterType,
                                  onChanged: (v) => setState(() => _batterType = v),
                                ),

                              if (needsBowlerType) ...[
                                const SizedBox(height: 12),
                                _chipGroup(
                                  label: 'Bowler Type',
                                  hint: 'Choose pace/spin',
                                  options: const ['pace', 'spin'],
                                  value: _bowlerType,
                                  onChanged: (v) => setState(() => _bowlerType = v),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                          : const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 24),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),

            // Sticky bottom action bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _bottomBar(),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _fancyAppBar(bool isDark) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? null
              : LinearGradient(
            colors: [AppColors.primary, const Color(0xFF42A5F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          color: isDark ? const Color(0xFF1C1D21) : null,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Add User',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _heroCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isDark
            ? LinearGradient(
          colors: [const Color(0xFF141518), const Color(0xFF0F1012)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: .12),
            const Color(0xFF42A5F5).withValues(alpha: .10)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (isDark ? Colors.white12 : Colors.black12),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white12 : AppColors.primary.withValues(alpha: .12)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.person_add_alt, size: 28),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Create a new user',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                SizedBox(height: 4),
                Text(
                  'Enter details. Player options will appear automatically.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassCard({required bool isDark, required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0x1AFFFFFF) : Colors.white.withValues(alpha: .82),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black12,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? .4 : .06),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _sectionHeader({required String title, required IconData icon}) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _chipGroup({
    required String label,
    required String hint,
    required List<String> options,
    required String? value,
    required ValueChanged<String> onChanged,
  }) {
    return FormField<String>(
      initialValue: value,
      validator: (v) {
        if (label.contains('Batter') &&
            (value == null || (value != 'left' && value != 'right'))) {
          return 'Select batter type (left/right)';
        }
        if (label.contains('Bowler') &&
            (value == null || (value != 'pace' && value != 'spin'))) {
          return 'Select bowler type (pace/spin)';
        }
        return null;
      },
      builder: (state) {
        final error = state.errorText;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: options.map((opt) {
                final selected = value == opt;
                return ChoiceChip(
                  label: Text(opt),
                  selected: selected,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : null,
                    fontWeight: FontWeight.w600,
                  ),
                  selectedColor: AppColors.primary,
                  onSelected: (_) {
                    onChanged(opt);
                    state.didChange(opt);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(hint, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  error,
                  style: TextStyle(color: Colors.red.shade600, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF0F1012).withValues(alpha: .96)
            : Colors.white.withValues(alpha: .96),
        border: Border(top: BorderSide(color: Colors.black12.withValues(alpha: .08))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Theme.of(context).dividerColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _submitting
                  ? null
                  : () {
                _formKey.currentState?.reset();
                _phoneCtrl.clear();
                _firstNameCtrl.clear();
                _emailCtrl.clear();
                setState(() {
                  _userType = supportedUserTypes.first;
                  _playerType = null;
                  _batterType = null;
                  _bowlerType = null;
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reset'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
                backgroundColor: AppColors.primary,
              ),
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Icon(Icons.check),
              label: Text(_submitting ? 'Creating...' : 'Create User',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
