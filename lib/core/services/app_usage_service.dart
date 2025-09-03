import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:emb_mission/core/services/monitoring_service.dart';

class AppUsageService {
  static const String _key = 'app_usage_seconds';
  static DateTime? _sessionStart;
  static DateTime? get sessionStart => _sessionStart;

  // À appeler quand l'app démarre ou reprend
  static void startSession() {
    _sessionStart = DateTime.now();
    
    // ✅ NOUVEAU: Monitoring de session
    MonitoringService.logSessionStart();
  }

  // À appeler quand l'app se met en pause ou se ferme
  static Future<void> endSession() async {
    if (_sessionStart == null) return;
    
    final now = DateTime.now();
    final sessionSeconds = now.difference(_sessionStart!).inSeconds;
    
    // ✅ NOUVEAU: Monitoring de session
    await MonitoringService.logSessionEnd(sessionSeconds);
    
    final prefs = await SharedPreferences.getInstance();
    final total = prefs.getInt(_key) ?? 0;
    await prefs.setInt(_key, total + sessionSeconds);
    _sessionStart = null;
  }

  // Récupérer le temps total en heures (arrondi)
  static Future<int> getTotalHours() async {
    final prefs = await SharedPreferences.getInstance();
    final seconds = prefs.getInt(_key) ?? 0;
    return (seconds / 3600).floor();
  }

  // Récupère les stats de prières et témoignages via l'API
  static Future<Map<String, int>> fetchProfileStats(String userId) async {
    final url = Uri.parse('https://embmission.com/mobileappebm/api/statsprofil?user_id=$userId');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == 'true') {
        return {
          'prieres': data['prieres'] ?? 0,
          'temoignages': data['temoignages'] ?? 0,
        };
      }
    }
    return {'prieres': 0, 'temoignages': 0};
  }
} 