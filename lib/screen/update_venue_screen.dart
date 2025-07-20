import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/venue_model.dart';
import '../service/venue_service.dart';
import '../theme/color.dart';
import '../widget/cricjust_appbar.dart';
import 'login_screen.dart';

class UpdateVenueScreen extends StatefulWidget {
  final Venue venue;

  const UpdateVenueScreen({super.key, required this.venue});

  @override
  State<UpdateVenueScreen> createState() => _UpdateVenueScreenState();
}

class _UpdateVenueScreenState extends State<UpdateVenueScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _infoController;
  late TextEditingController _linkController;

  bool _isSubmitting = false;
  String? _apiToken;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.venue.name);
    _infoController = TextEditingController(text: widget.venue.info);
    _linkController = TextEditingController(text: widget.venue.link ?? '');
    _ensureLoggedIn();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _infoController.dispose();
    _linkController.dispose();
    super.dispose();
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

  Future<void> _submitUpdate() async {
    if (!_formKey.currentState!.validate() ||
        _isSubmitting ||
        _apiToken == null)
      return;
    setState(() => _isSubmitting = true);

    try {
      final updatedVenue = await VenueService.updateVenue(
        apiToken: _apiToken!,
        venueId: widget.venue.venueId,
        name: _nameController.text.trim(),
        info: _infoController.text.trim(),
        link: _linkController.text.trim().isEmpty
            ? null
            : _linkController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text('Venue updated successfully!'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 600));
        Navigator.pop(context, updatedVenue);
      }
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
        ).showSnackBar(SnackBar(content: Text('Error updating venue: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildStyledField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            borderRadius: BorderRadius.circular(18),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: buildCricjustAppBar("Update Venue"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildStyledField(
                controller: _nameController,
                label: 'Venue Name',
                icon: Icons.location_city,
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Please enter venue name'
                    : null,
              ),
              _buildStyledField(
                controller: _infoController,
                label: 'Venue Info',
                icon: Icons.info_outline,
                maxLines: 3,
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Please enter venue info'
                    : null,
              ),
              _buildStyledField(
                controller: _linkController,
                label: 'Google Maps Link (Optional)',
                icon: Icons.link,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isSubmitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.update),
                  label: Text(
                    _isSubmitting ? "Updating..." : "Update Venue",
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 3,
                  ),
                  onPressed: _submitUpdate,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
