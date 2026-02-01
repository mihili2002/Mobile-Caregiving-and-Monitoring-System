import 'package:flutter/material.dart';
import 'package:mobile_caregiving_and_monitoring_system/pages/therapist/risk_history_chart_screen.dart';

class RiskResultScreen extends StatelessWidget {
  final Map<String, dynamic> result;

  const RiskResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final predictions = (result["predictions"] ?? {}) as Map<String, dynamic>;
    final residentId = (result["resident_id"] ?? "").toString();

    Widget tile(String title) {
      final data = (predictions[title] ?? {}) as Map<String, dynamic>;
      final prob = (data["probability"] ?? 0.0).toDouble();
      final level = (data["level"] ?? "Unknown").toString();

      return Card(
        child: ListTile(
          title: Text(title),
          subtitle: Text("Level: $level"),
          trailing: Text("${(prob * 100).toStringAsFixed(1)}%"),
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
            const SizedBox(height: 12),

            tile("Depression_Risk"),
            tile("Anxiety_Risk"),
            tile("Insomnia_Risk"),
            tile("Emotional_WellBeing_Risk"),

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