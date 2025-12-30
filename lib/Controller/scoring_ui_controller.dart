import 'package:flutter/foundation.dart';

class ScoringUIController {
  final ValueNotifier<int?> runs = ValueNotifier(null);
  final ValueNotifier<String?> extra = ValueNotifier(null);
  final ValueNotifier<bool> isSubmitting = ValueNotifier(false);

  void reset() {
    runs.value = null;
    extra.value = null;
  }

  void dispose() {
    runs.dispose();
    extra.dispose();
    isSubmitting.dispose();
  }
}
