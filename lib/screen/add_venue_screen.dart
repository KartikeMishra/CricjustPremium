// lib/screen/add_venue_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../service/venue_service.dart';
import '../theme/color.dart';
import 'login_screen.dart';

class AddVenueScreen extends StatefulWidget {
  const AddVenueScreen({super.key});

  @override
  State<AddVenueScreen> createState() => _AddVenueScreenState();
}

class _AddVenueScreenState extends State<AddVenueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _infoCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  bool _isSubmitting = false;
  String? _apiToken;

  @override
  void initState() {
    super.initState();
    _ensureLoggedIn();
  }

  Future<void> _ensureLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_logged_in_token');
    if (token == null || token.isEmpty) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } else {
      setState(() => _apiToken = token);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() ||
        _isSubmitting ||
        _apiToken == null) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final newVenue = await VenueService.addVenue(
        apiToken: _apiToken!,
        name: _nameCtrl.text.trim(),
        info: _infoCtrl.text.trim(),
        link: _linkCtrl.text.trim().isEmpty ? null : _linkCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Venue added successfully!'),
            ],
          ),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 500));
      Navigator.pop(context, newVenue);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Session expired')) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  InputDecoration _decor(String label, IconData icon, bool dark) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primary),
      filled: true,
      fillColor: dark ? Colors.grey[800] : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? Colors.black : Colors.grey[100],

      // ─── Gradient AppBar ────────────────────────────────
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'Add Venue',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: dark
                  ? null
                  : const LinearGradient(
                      colors: [AppColors.primary, Color(0xFF42A5F5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              color: dark ? const Color(0xFF1E1E1E) : null,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
      ),

      // ─── Body Card ───────────────────────────────────────
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          color: dark ? Colors.grey[850] : Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Venue Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Name
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: _decor('Venue Name', Icons.location_city, dark),
                    style: TextStyle(
                      color: dark ? Colors.white : Colors.black87,
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Enter venue name' : null,
                  ),
                  const SizedBox(height: 16),

                  // Info
                  TextFormField(
                    controller: _infoCtrl,
                    maxLines: 3,
                    decoration: _decor('Venue Info', Icons.info_outline, dark),
                    style: TextStyle(
                      color: dark ? Colors.white : Colors.black87,
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Enter venue info' : null,
                  ),
                  const SizedBox(height: 16),

                  // Link
                  TextFormField(
                    controller: _linkCtrl,
                    decoration: _decor(
                      'Google Maps Link (Optional)',
                      Icons.link,
                      dark,
                    ),
                    style: TextStyle(
                      color: dark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ─── Add Venue Button ───────────────────────────
                  Center(
                    child: dark
                        // glassy-⟶dark
                        ? GestureDetector(
                            onTap: _isSubmitting ? null : _submit,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.5),
                                        blurRadius: 8,
                                        offset: const Offset(4, 4),
                                      ),
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.6),
                                        blurRadius: 6,
                                        offset: const Offset(-4, -4),
                                      ),
                                    ],
                                  ),
                                  child: _isSubmitting
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Icon(
                                              Icons.add,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Add Venue',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          )
                        // solid primary-⟶light
                        : ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : _submit,
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.add, color: Colors.white),
                            label: Text(
                              _isSubmitting ? 'Saving…' : 'Add Venue',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              elevation: 6,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
