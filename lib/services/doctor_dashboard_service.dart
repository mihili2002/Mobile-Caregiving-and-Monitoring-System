import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/doctor_dashboard_item_model.dart';

class DoctorDashboardService {
  final String baseUrl = ApiConfig.baseUrl;

  Future<List<DoctorDashboardItem>> getDashboard() async {
    final token = await FirebaseAuth.instance.currentUser!.getIdToken();

    final res = await http.get(
      Uri.parse("$baseUrl/doctor/dashboard"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to load dashboard");
    }

    final json = jsonDecode(res.body);
    return (json["items"] as List)
        .map((e) => DoctorDashboardItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
