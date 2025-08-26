// lib/widgets/update_match_youtube_dialog.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../service/match_youtube_service.dart';
import '../theme/color.dart';

class UpdateMatchYoutubeDialog extends StatefulWidget {
  final int matchId;
  final String? initialUrl; // optional: prefill with existing link, if you have it

  const UpdateMatchYoutubeDialog({
    super.key,
    required this.matchId,
    this.initialUrl,
  });

  @override
  State<UpdateMatchYoutubeDialog> createState() => _UpdateMatchYoutubeDialogState();
}

class _UpdateMatchYoutubeDialogState extends State<UpdateMatchYoutubeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _urlCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _urlCtrl.text = widget.initialUrl ?? '';
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  String? _validateUrl(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Paste a YouTube URL';
    // Lightweight check (accepts youtu.be / youtube.com)
    final ok = s.contains('youtu.be') || s.contains('youtube.com');
    return ok ? null : 'Enter a valid YouTube link';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_logged_in_token') ?? '';
      if (token.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in again'), backgroundColor: Colors.red),
        );
        return;
      }

      final resp = await MatchYoutubeService.updateYoutube(
        apiToken: token,
        matchId: widget.matchId,
        youtubeUrl: _urlCtrl.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resp.message),
          backgroundColor: resp.ok ? Colors.green : Colors.red,
        ),
      );

      if (resp.ok) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update Match YouTube Link'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _urlCtrl,
          decoration: const InputDecoration(
            labelText: 'YouTube URL',
            hintText: 'https://youtu.be/… or https://www.youtube.com/watch?v=…',
          ),
          keyboardType: TextInputType.url,
          validator: _validateUrl,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: _saving
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
