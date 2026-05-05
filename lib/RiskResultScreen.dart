import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_caregiving_and_monitoring_system/pages/therapist/risk_history_chart_screen.dart';

class RiskResultScreen extends StatelessWidget {
  final Map<String, dynamic> result;

  const RiskResultScreen({super.key, required this.result});

  static const String baseUrl = "http://127.0.0.1:8000";

  // ================= SAFE MAP =================
  Map<String, dynamic> safeMap(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return {};
  }

  // ================= COLOR LOGIC =================
  Color getRiskColor(double value) {
    if (value >= 0.7) return Colors.red;       // High
    if (value >= 0.4) return Colors.orange;    // Medium
    return Colors.green;                       // Low
  }

  String getRiskLevel(double value) {
    if (value >= 0.7) return "High";
    if (value >= 0.4) return "Medium";
    return "Low";
  }

  // ================= APPROVE =================
  Future<bool> approveRisk(BuildContext context) async {
    final riskId = result["id"]; // 🔥 FIXED (was risk_id)

    if (riskId == null) return false;

    await http.post(
      Uri.parse("$baseUrl/api/risk/approve_risk_result"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "risk_id": riskId,
        "approved_by": "Therapist",
      }),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Approved")),
    );

    return true;
  }

  // ================= REJECT =================
  Future<void> rejectRisk(BuildContext context) async {
    final riskId = result["id"]; // 🔥 FIXED

    await http.post(
      Uri.parse("$baseUrl/api/risk/reject_risk_result"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"risk_id": riskId}),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Rejected")),
    );
  }

  // ================= TILE =================
  Widget buildRiskTile(String title, double value) {
    final color = getRiskColor(value);
    final level = getRiskLevel(value);

    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(
          "Level: $level",
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: Text(
          "${(value * 100).toStringAsFixed(1)}%",
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final residentId = (result["residentId"] ?? "").toString();

    // 🔥 USE PROBABILITIES DIRECTLY (NO DEPENDENCY ON predictions MAP)
    final dep = (result["depProb"] ?? 0.0).toDouble();
    final anx = (result["anxProb"] ?? 0.0).toDouble();
    final ins = (result["insProb"] ?? 0.0).toDouble();
    final emo = (result["emoProb"] ?? 0.0).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F3FF),
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF11BFA8),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: const Text(
                "Assessment Review",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ListView(
                  children: [
                    Text("Resident: $residentId",
                        style: const TextStyle(fontWeight: FontWeight.bold)),

                    const SizedBox(height: 20),

                    // ================= PREDICTIONS =================
                    const Text("AI Prediction",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),

                    const SizedBox(height: 10),

                    buildRiskTile("Depression Risk", dep),
                    buildRiskTile("Anxiety Risk", anx),
                    buildRiskTile("Insomnia Risk", ins),
                    buildRiskTile("Emotional Well-being Risk", emo),

                    const SizedBox(height: 20),

                    // ================= ACTIONS =================
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final ok = await approveRisk(context);
                              if (ok && context.mounted) {
                                Navigator.pop(context, 'approved');
                              }
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green),
                            child: const Text("Approve"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => rejectRisk(context),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red),
                            child: const Text("Reject"),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton(
                      child: const Text("View Trend Graph"),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RiskHistoryChartScreen(
                              residentId: residentId,
                              days: 30,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}