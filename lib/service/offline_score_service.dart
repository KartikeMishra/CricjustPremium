import 'package:hive/hive.dart';
import '../model/offline_ball_event.dart';

class OfflineScoreService {
  static const String _boxName = 'offline_scores';

  static Box<OfflineBallEvent> get _box => Hive.box<OfflineBallEvent>(_boxName);

  /// Save an offline score entry
  static Future<void> save(OfflineBallEvent event) async {
    await _box.add(event);
  }

  /// Get all unsynced scores
  static List<OfflineBallEvent> getAll() {
    return _box.values.toList();
  }

  /// Remove a score after successful sync
  static Future<void> remove(OfflineBallEvent event) async {
    await event.delete();
  }

  /// Clear all offline data (optional for admin/debug)
  static Future<void> clearAll() async {
    await _box.clear();
  }

  /// Get total unsynced count (for badge/display)
  static int getCount() {
    return _box.length;
  }
}
