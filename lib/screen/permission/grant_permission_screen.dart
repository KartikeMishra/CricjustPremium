// lib/screen/permission/grant_permission_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../service/permission_service.dart';
import '../../utils/qr_payload.dart';
import '../../theme/color.dart'; // ← for AppColors like other screens

class GrantPermissionScreen extends StatefulWidget {
  /// Sender's API token
  final String apiToken;

  /// When provided, screen enters "pinned" mode (no list/toggle),
  /// locked to this type/id. Allowed values: 'matches' or 'teams'.
  final String? initialType;
  final int? initialTypeId;

  /// Optional pretty title to show in the pinned card header
  final String? initialTitle;

  const GrantPermissionScreen({
    super.key,
    required this.apiToken,
    this.initialType,
    this.initialTypeId,
    this.initialTitle,
  });

  @override
  State<GrantPermissionScreen> createState() => _GrantPermissionScreenState();
}

class _GrantPermissionScreenState extends State<GrantPermissionScreen> {
  late String _type; // 'matches' | 'teams'
  int? _selectedId;

  final List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  bool _granting = false;
  String? _scannedPhone;

  bool get _pinned =>
      widget.initialType != null && widget.initialTypeId != null;

  @override
  void initState() {
    super.initState();
    _type = (widget.initialType == 'teams') ? 'teams' : 'matches';
    _selectedId = widget.initialTypeId;

    if (!_pinned) {
      _loadItems();
    }
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);
    try {
      final list = await PermissionService.getTypeList(
        token: widget.apiToken,
        type: _type,
      );
      setState(() {
        _items
          ..clear()
          ..addAll(list);
        // ensure selected id still exists if previously chosen
        final exists = _items.any((it) {
          final id = (_type == 'matches') ? it['match_id'] : it['team_id'];
          return id == _selectedId;
        });
        if (!exists) _selectedId = null;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scanReceiver() async {
    final phone = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _ScanPage()),
    );
    if (phone != null && phone.isNotEmpty) {
      setState(() => _scannedPhone = phone);
      _toast('Receiver: $phone');
    }
  }

  Future<void> _grant() async {
    if (_selectedId == null) {
      _toast('Select a ${_type == 'matches' ? 'match' : 'team'}');
      return;
    }
    if (_scannedPhone == null || _scannedPhone!.isEmpty) {
      _toast('Scan receiver QR first');
      return;
    }
    if (_granting) return;

    setState(() => _granting = true);
    try {
      final ok = await PermissionService.addPermission(
        token: widget.apiToken,
        type: _type,
        typeId: _selectedId!,
        assignUserPhone: _normalizePhone(_scannedPhone!),
      );

      if (!mounted) return;
      if (ok) {
        _toast('Permission granted ✔');
        if (_pinned) {
          Navigator.pop(context, true);
        } else {
          setState(() {
            _scannedPhone = null; // keep selection for quick multi-grant
          });
        }
      } else {
        _toast('Failed to grant permission');
      }
    } finally {
      if (mounted) setState(() => _granting = false);
    }
  }

  String _normalizePhone(String p) =>
      p.replaceAll(RegExp(r'[^0-9+]'), '');

  void _toast(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  // ---------- UI bits ----------

  PreferredSizeWidget _buildPrettyHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.canPop(context);

    final isMatch = _type == 'matches';

    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: Container(
        decoration: isDark
            ? const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        )
            : const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, Color(0xFF42A5F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: canPop
              ? IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.maybePop(context),
            tooltip: 'Back',
          )
              : null,
          title: Text(
            _pinned
                ? 'Grant ${isMatch ? "Match" : "Team"} Access'
                : 'Grant Permission',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          actions: [
            if (!_pinned)
              TextButton.icon(
                onPressed: () {
                  setState(() => _type = isMatch ? 'teams' : 'matches');
                  _loadItems();
                },
                icon: const Icon(Icons.swap_horiz, color: Colors.white),
                label: Text(
                  isMatch ? 'Teams' : 'Matches',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pinnedSelectionCard({required String title, required String subtitle}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(12),
            child: const Icon(Icons.verified_user, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiverCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasPhone = _scannedPhone != null && _scannedPhone!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: (hasPhone ? Colors.green : Colors.orange).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(12),
            child: Icon(
              hasPhone ? Icons.check_circle : Icons.qr_code_scanner,
              color: hasPhone ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Receiver', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  hasPhone ? _scannedPhone! : '— not scanned —',
                  style: TextStyle(
                    color: hasPhone
                        ? (isDark ? Colors.greenAccent : Colors.green)
                        : (isDark ? Colors.white60 : Colors.black54),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _scanReceiver,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.qr_code_2),
            label: const Text('Scan'),
          ),
        ],
      ),
    );
  }

  Widget _listItemCard({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? (isDark ? Colors.lightBlueAccent : AppColors.primary)
              : (isDark ? Colors.white12 : Colors.black12),
          width: selected ? 1.4 : 1,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Row(
          children: [
            Icon(
              Icons.sports_cricket, // works for both; keeps it fun
              color: selected
                  ? (isDark ? Colors.lightBlueAccent : AppColors.primary)
                  : (isDark ? Colors.white70 : Colors.black45),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected
                  ? (isDark ? Colors.lightBlueAccent : AppColors.primary)
                  : (isDark ? Colors.white54 : Colors.black38),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grantButton() {
    final isMatch = _type == 'matches';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _granting ? null : _grant,
          icon: _granting
              ? const SizedBox(
              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send),
          label: Text(
            _granting
                ? 'Granting...'
                : 'Grant ${isMatch ? "Match" : "Team"} Permission',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 3,
          ),
        ),
      ),
    );
  }

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    final isMatch = _type == 'matches';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111111) : const Color(0xFFF5F7FA),
      appBar: _buildPrettyHeader(),

      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),

          // Pinned header when launched from a specific card
          if (_pinned)
            _pinnedSelectionCard(
              title: widget.initialTitle ??
                  '${isMatch ? "Match" : "Team"} ID: ${widget.initialTypeId}',
              subtitle: isMatch ? 'Matches' : 'Teams',
            ),

          // Free-pick list when not pinned
          if (!_pinned)
            Expanded(
              child: _items.isEmpty
                  ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 160),
                  Icon(Icons.qr_code_2,
                      size: 64, color: isDark ? Colors.white24 : Colors.black26),
                  const SizedBox(height: 12),
                  Text(
                    _loading ? 'Loading...' : 'No ${isMatch ? 'matches' : 'teams'} found',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16, color: isDark ? Colors.white70 : Colors.black54),
                  ),
                  const SizedBox(height: 80),
                ],
              )
                  : ListView.builder(
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: _items.length,
                itemBuilder: (_, i) {
                  final it = _items[i];
                  final id = (isMatch ? it['match_id'] : it['team_id']) as int?;
                  final title = (isMatch ? it['match_name'] : it['team_name']).toString();
                  final subtitle = isMatch ? 'Match' : 'Team';
                  final selected = id != null && id == _selectedId;

                  return _listItemCard(
                    title: title,
                    subtitle: subtitle,
                    selected: selected,
                    onTap: () => setState(() => _selectedId = id),
                  );
                },
              ),
            ),

          // Receiver row (card)
          _receiverCard(),

          // Tip text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Ask the receiver to open their “Receive QR” and scan it here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ),

          // Grant button fixed at bottom
          _grantButton(),
        ],
      ),
    );
  }
}

class _ScanPage extends StatefulWidget {
  const _ScanPage();

  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final codes = capture.barcodes;
    final code = codes.isNotEmpty ? (codes.first.rawValue ?? '') : '';
    if (code.isEmpty) return;

    final parsed = ReceiverQrPayload.tryParse(code);
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid QR')),
      );
      return;
    }
    _handled = true;
    Navigator.of(context).pop(parsed.phone);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Receiver QR'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Column(
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Point the camera at the receiver’s QR code.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
