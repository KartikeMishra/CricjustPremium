import 'package:flutter/material.dart';

/// Parses a dynamic input into integer, returns 0 on failure.
int parseInt(dynamic input) {
  if (input == null) return 0;
  if (input is int) return input;
  if (input is String) return int.tryParse(input) ?? 0;
  return 0;
}

/// Shows a success message using SnackBar
void showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.green.shade600,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Shows an error message using SnackBar
void showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red.shade600,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Shows a confirmation dialog for ending the match or innings
Future<bool> showConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
}) async {
  return await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          child: const Text("Cancel"),
          onPressed: () => Navigator.pop(context, false),
        ),
        ElevatedButton(
          child: const Text("Confirm"),
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    ),
  ) ??
      false;
}

/// Resets scoring input selections
void resetScoringInputs({
  required ValueSetter<int?> setSelectedRuns,
  required ValueSetter<String?> setSelectedExtra,
  required ValueSetter<bool> setIsWicket,
}) {
  setSelectedRuns(null);
  setSelectedExtra(null);
  setIsWicket(false);
}
