import 'package:flutter/material.dart';
import '../model/toss_update_model.dart';
import '../service/toss_service.dart';
import '../theme/color.dart';

class TossDialog extends StatefulWidget {
  final int matchId;
  final int teamAId;
  final int teamBId;
  final String token;
  final String teamAName;
  final String teamBName;

  const TossDialog({
    super.key,
    required this.matchId,
    required this.teamAId,
    required this.teamBId,
    required this.token,
    required this.teamAName,
    required this.teamBName,
  });

  @override
  State<TossDialog> createState() => _TossDialogState();
}

class _TossDialogState extends State<TossDialog> {
  int? _selectedTossWinnerId;
  int? _selectedDecision; // 0 = Bat, 1 = Bowl
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadTossInfo();
  }

  Future<void> _loadTossInfo() async {
    try {
      final data = await TossService.fetchTossData(widget.matchId);
      setState(() {
        _selectedTossWinnerId = data['toss_win'];
        _selectedDecision = data['toss_win_chooses'];
      });
    } catch (e) {
      debugPrint('⚠️ No toss data found or error: $e');
    }
  }

  Future<void> _submitToss() async {
    if (_selectedTossWinnerId == null || _selectedDecision == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both team and decision')),
      );
      return;
    }

    setState(() => _loading = true);

    final request = TossUpdateRequest(
      tossWin: _selectedTossWinnerId!,
      tossWinChooses: _selectedDecision!,
    );

    final result = await TossService.updateToss(
      request: request,
      token: widget.token,
      matchId: widget.matchId,
    );

    setState(() => _loading = false);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result['message'] ?? 'No response')));

    if (result['success'] == true) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Theme.of(context).cardColor,
      title: const Text(
        'Toss Details',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: _loading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Who won the toss?'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ChoiceChip(
                        label: Text(
                          widget.teamAName,
                          overflow: TextOverflow.ellipsis,
                        ),
                        selected: _selectedTossWinnerId == widget.teamAId,
                        onSelected: (_) => setState(
                          () => _selectedTossWinnerId = widget.teamAId,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      ChoiceChip(
                        label: Text(
                          widget.teamBName,
                          overflow: TextOverflow.ellipsis,
                        ),
                        selected: _selectedTossWinnerId == widget.teamBId,
                        onSelected: (_) => setState(
                          () => _selectedTossWinnerId = widget.teamBId,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  const Text('Decision after winning toss'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ChoiceChip(
                        label: const Text('Bat First'),
                        selected: _selectedDecision == 0,
                        onSelected: (_) =>
                            setState(() => _selectedDecision = 0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      ChoiceChip(
                        label: const Text('Bowl First'),
                        selected: _selectedDecision == 1,
                        onSelected: (_) =>
                            setState(() => _selectedDecision = 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed:
              (_selectedTossWinnerId != null && _selectedDecision != null)
              ? _submitToss
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: Colors.grey.shade400,
            foregroundColor: Colors.white,
          ),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
