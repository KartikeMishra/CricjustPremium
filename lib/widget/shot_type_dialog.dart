import 'package:flutter/material.dart';

Future<Map<String, String>?> showShotTypeDialog(
    BuildContext context,
    String batterName,
    int run,
    ) {
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ShotTypePickerUI(batterName: batterName, run: run),
  );
}

class ShotTypePickerUI extends StatefulWidget {
  final String batterName;
  final int run;

  const ShotTypePickerUI({super.key, required this.batterName, required this.run});

  @override
  State<ShotTypePickerUI> createState() => _ShotTypePickerUIState();
}

class _ShotTypePickerUIState extends State<ShotTypePickerUI> {
  String? _selectedShot;
  String? _selectedZone;
  final _scrollController = ScrollController();

  void _submit() {
    Navigator.pop(context, {
      'shot': _selectedShot ?? '',
      'shot_area': _selectedZone ?? '',
    });
  }

  void _selectShot(String shot) {
    setState(() => _selectedShot = shot);
    _scrollToBottom();
  }

  void _selectZone(String zone) {
    setState(() => _selectedZone = zone);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  static const List<_Shot> straightShots = [
    _Shot('Straight Drive', Icons.trending_flat),
    _Shot('On Drive', Icons.arrow_downward),
    _Shot('Off Drive', Icons.arrow_upward),
    _Shot('Lofted Drive', Icons.flight),
  ];

  static const List<_Shot> frontFootShots = [
    _Shot('Cover Drive', Icons.alt_route),
    _Shot('Extra Cover Drive', Icons.call_split),
    _Shot('Inside Out', Icons.double_arrow),
    _Shot('Defensive Block', Icons.shield),
  ];

  static const List<_Shot> backFootShots = [
    _Shot('Backfoot Punch', Icons.back_hand),
    _Shot('Cut', Icons.cut),
    _Shot('Late Cut', Icons.timelapse),
    _Shot('Square Drive', Icons.crop_square),
    _Shot('Upper Cut', Icons.arrow_upward),
  ];

  static const List<_Shot> legSideShots = [
    _Shot('Pull', Icons.swipe),
    _Shot('Hook', Icons.rotate_left),
    _Shot('Sweep', Icons.swipe_right),
    _Shot('Reverse Sweep', Icons.undo),
    _Shot('Slog Sweep', Icons.bolt),
    _Shot('Helicopter Shot', Icons.loop),
    _Shot('Flick', Icons.flip),
    _Shot('Leg Glance', Icons.format_align_left),
  ];

  static const List<_Shot> unorthodoxShots = [
    _Shot('Ramp Shot', Icons.directions),
    _Shot('Paddle Sweep', Icons.pan_tool),
    _Shot('Switch Hit', Icons.switch_left),
    _Shot('Dilscoop', Icons.vertical_align_top),
    _Shot('Reverse Flick', Icons.swap_horiz),
  ];

  static const List<_Shot> miscShots = [
    _Shot('Edge', Icons.horizontal_rule),
    _Shot('Deflection', Icons.keyboard_return),
    _Shot('Dead Bat', Icons.block),
    _Shot('No Shot', Icons.not_interested),
  ];

  static const _zones = <_Zone>[
    _Zone('Lng On', Alignment.topLeft, Icons.north_west),
    _Zone('Lng Off', Alignment.topCenter, Icons.north),
    _Zone('Cvr', Alignment.topRight, Icons.north_east),
    _Zone('Mid Wkt', Alignment.centerLeft, Icons.west),
    _Zone('Pnt', Alignment.centerRight, Icons.east),
    _Zone('Sqre Leg', Alignment.bottomLeft, Icons.south_west),
    _Zone('Fn Leg', Alignment.bottomCenter, Icons.south),
    _Zone('3rd Man', Alignment.bottomRight, Icons.south_east),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ready = _selectedShot != null && _selectedZone != null;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.only(top: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: const [BoxShadow(blurRadius: 16, color: Colors.black26)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(isDark),
            Flexible(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _buildGround(isDark),
                    const SizedBox(height: 18),
                    _buildGroupedRow("Straight Shots", straightShots, isDark),
                    _buildGroupedRow("Front Foot Shots", frontFootShots, isDark),
                    _buildGroupedRow("Back Foot Shots", backFootShots, isDark),
                    _buildGroupedRow("Leg Side Shots", legSideShots, isDark),
                    _buildGroupedRow("Modern / Unorthodox Shots", unorthodoxShots, isDark),
                    _buildGroupedRow("Miscellaneous", miscShots, isDark),

                    if (ready) _buildPreviewBadge(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            _buildBottomButtons(ready),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              children: [
                Text(widget.batterName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black,
                    )),
                Text("${widget.run} Run${widget.run == 1 ? '' : 's'}",
                    style: const TextStyle(color: Colors.teal)),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildGround(bool isDark) {
    return SizedBox(
      height: 260,
      width: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: isDark
                    ? [Colors.green.shade900, Colors.green.shade800]
                    : [Colors.green.shade400, Colors.green.shade700],
              ),
            ),
          ),
          Container(
            width: 12,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.yellow.shade700,
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
            ),
          ),
          ..._zones.map((z) => Align(
            alignment: z.alignment,
            child: GestureDetector(
              onTap: () => _selectZone(z.label),
              child: Container(
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: _selectedZone == z.label
                      ? Colors.blueAccent
                      : (isDark ? Colors.grey[800] : Colors.white),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedZone == z.label ? Colors.white : Colors.transparent,
                    width: 1.5,
                  ),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(z.icon, size: 14, color: isDark ? Colors.white70 : Colors.black87),
                    const SizedBox(width: 4),
                    Text(z.label,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87)),
                  ],
                ),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildGroupedRow(String title, List<_Shot> shots, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isDark ? Colors.grey[300] : Colors.black87)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: shots.map((s) {
            final selected = _selectedShot == s.label;
            return _shotChip(s.label, s.icon, selected, isDark);
          }).toList(),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _shotChip(String label, IconData icon, bool selected, bool isDark) {
    return GestureDetector(
      onTap: () => _selectShot(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? Colors.blueAccent.withValues(alpha: 0.1)
              : (isDark ? Colors.grey[850] : Colors.grey[100]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.blueAccent : Colors.transparent,
            width: 2,
          ),
          boxShadow: selected
              ? [BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.2), blurRadius: 6)]
              : [const BoxShadow(color: Colors.black12, blurRadius: 2)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.blueAccent : Colors.grey),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: selected ? Colors.blueAccent : (isDark ? Colors.white : Colors.black))),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewBadge() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blueAccent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sports_cricket, size: 18, color: Colors.blue),
            const SizedBox(width: 6),
            Text('$_selectedShot • $_selectedZone',
                style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.blueAccent)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButtons(bool ready) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 52),
      child: Column(
        children: [
          if (ready)
            ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              label: const Text("Submit Shot & Area"),
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            )
          else
            const Text("Select a shot and a zone to continue", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.skip_next, size: 16),
            label: const Text("Skip"),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              textStyle: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _Zone {
  final String label;
  final Alignment alignment;
  final IconData icon;
  const _Zone(this.label, this.alignment, this.icon);
}

class _Shot {
  final String label;
  final IconData icon;
  const _Shot(this.label, this.icon);
}
