// lib/utils/score_log.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';

class ScoreLog {
  static bool network = false; // turn GET spam ON/OFF
  static bool submit  = true;  // keep ball-wise submit

  static void net(String msg)  { if (kDebugMode && network) debugPrint(msg); }
  static void ball(String msg) { if (kDebugMode && submit)  debugPrint(msg); }

  /// ✅ Proper function name: ballPayload
  /// Prints the exact submit payload (incl. batting orders) as one-line JSON.
  static void ballPayload(Map<String, String> fields) {
    final m = Map<String, String?>.from(fields);
    final payload = <String, String?>{
      'over'              : m['over_number'],
      'ball'              : m['ball_number'],
      'runs'              : m['runs'],
      'extra_type'        : m['extra_run_type'],
      'extra'             : m['extra_run'],
      'is_wicket'         : m['is_wicket'],
      'wicket_type'       : m['wicket_type'],
      'out_player'        : m['out_player'],
      'run_out_by'        : m['run_out_by'],
      'catch_by'          : m['catch_by'],
      'striker'           : m['on_strike_player_id'],
      'striker_order'     : m['on_strike_player_order'],
      'non_striker'       : m['non_strike_player_id'],
      'non_striker_order' : m['non_strike_player_order'],
      'bowler'            : m['bowler'],
      'shot'              : m['shot'],
    }..removeWhere((_, v) => v == null || v.isEmpty);

    if (kDebugMode && submit) {
      debugPrint('📤 SUBMIT ${m['over_number']}.${m['ball_number']} → ${jsonEncode(payload)}');
    }
  }
}
