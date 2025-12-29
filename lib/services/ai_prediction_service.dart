import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/routine_models.dart';
import '../config/api_config.dart';

class AiPredictionService {

  Future<RoutineAIInsights?> getTaskRiskPrediction({
    required Map<String, dynamic> userProfile,
    required String taskName,
    required String taskTime,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/predict_task_risk'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "profile": userProfile,
          "task": {
            "task_name": taskName,
            "time": taskTime
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return RoutineAIInsights.fromJson(data['predictions']);
        }
      }
      print("Backend returned error: ${response.body}");
      return null;
    } catch (e) {
      print("AI Connection Error: $e");
      return null;
    }
  }
}
