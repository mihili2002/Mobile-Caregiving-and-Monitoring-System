import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:mobile_caregiving_and_monitoring_system/pages/therapist/risk_history_chart_screen.dart';

class RiskResultScreen extends StatelessWidget {
  final Map<String, dynamic> result;

  const RiskResultScreen({super.key, required this.result});

  static const String baseUrl = "http://127.0.0.1:8000";

  Future<void> approveRisk(BuildContext context) async {
    final riskId = result["risk_id"];

    if (riskId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Risk ID not found")),
      );
      return;
    }

    try {
      await http.post(
        Uri.parse("$baseUrl/risk/approve_risk_result"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "risk_id": riskId,
          "approved_by": "Mental Health Professional"
        }),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Risk assessment approved")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Approval failed: $e")),
      );
    }
  }

  Future<void> rejectRisk(BuildContext context) async {
    final riskId = result["risk_id"];

    if (riskId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Risk ID not found")),
      );
      return;
    }

    try {
      await http.post(
        Uri.parse("$baseUrl/risk/reject_risk_result"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "risk_id": riskId,
        }),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Risk assessment rejected")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Rejection failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final predictions = (result["predictions"] ?? {}) as Map<String, dynamic>;
    final residentId = (result["resident_id"] ?? "").toString();

    Widget tile(String title) {
      final data = (predictions[title] ?? {}) as Map<String, dynamic>;
      final prob = (data["probability"] ?? 0.0).toDouble();
      final level = (data["level"] ?? "Unknown").toString();

      Color levelColor = Colors.grey;

      if (level == "Low") levelColor = Colors.green;
      if (level == "Medium") levelColor = Colors.orange;
      if (level == "High") levelColor = Colors.red;

      return Card(
        child: ListTile(
          title: Text(title.replaceAll("_", " ")),
          subtitle: Text("Risk Level: $level"),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "${(prob * 100).toStringAsFixed(1)}%",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: levelColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Risk Prediction Result")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              "Resident ID: $residentId",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                "⚠ This AI prediction must be reviewed by a Mental Health Professional before informing the resident.",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),

            const SizedBox(height: 16),

            tile("Depression_Risk"),
            tile("Anxiety_Risk"),
            tile("Insomnia_Risk"),
            tile("Emotional_WellBeing_Risk"),

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle),
                    label: const Text("Approve"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    onPressed: () => approveRisk(context),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.cancel),
                    label: const Text("Reject"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () => rejectRisk(context),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              icon: const Icon(Icons.show_chart),
              label: const Text("View Risk Trend (30 days)"),
              onPressed: residentId.isEmpty
                  ? null
                  : () {
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
    );
  }
}