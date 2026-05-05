import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/risk_api.dart';
import '../../RiskResultScreen.dart';
import 'risk_history_chart_screen.dart';
import 'personalized_plan_screen.dart';

class TherapistElderProfilePage extends StatefulWidget {
  final AppUser elder;

  const TherapistElderProfilePage({super.key, required this.elder});

  @override
  State<TherapistElderProfilePage> createState() =>
      _TherapistElderProfilePageState();
}

class _TherapistElderProfilePageState
    extends State<TherapistElderProfilePage> {
  Map<String, dynamic>? latestRisk;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadRisk();
  }

  Future<void> _loadRisk() async {
    try {
      final data = await RiskApi.getRiskHistory(
        residentId: widget.elder.uid,
      );

      final history = data["items"] ?? [];

      if (history.isNotEmpty) {
        setState(() {
          latestRisk = Map<String, dynamic>.from(history.first); // latest
          loading = false;
        });
      } else {
        setState(() => loading = false);
      }
    } catch (e) {
      setState(() => loading = false);
    }
  }

  Widget buildPredictionCard(String title, double value) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text(
          "${(value * 100).toStringAsFixed(1)}%",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final elder = widget.elder;

    return Scaffold(
      appBar: AppBar(title: Text(elder.name ?? "Elder")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  // BASIC INFO
                  Card(
                    child: ListTile(
                      title: Text(elder.name ?? "No name"),
                      subtitle: Text(elder.email),
                    ),
                  ),

                  const SizedBox(height: 20),

                  if (latestRisk == null)
                    const Text("No assessment submitted yet"),

                  if (latestRisk != null) ...[
                    const Text(
                      "Prediction Results",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    buildPredictionCard(
                        "Depression Risk",
                        (latestRisk?["depProb"] ?? 0.0).toDouble()),

                    buildPredictionCard(
                        "Anxiety Risk",
                        (latestRisk?["anxProb"] ?? 0.0).toDouble()),

                    buildPredictionCard(
                        "Insomnia Risk",
                        (latestRisk?["insProb"] ?? 0.0).toDouble()),

                    buildPredictionCard(
                        "Emotional Well-being Risk",
                        (latestRisk?["emoProb"] ?? 0.0).toDouble()),

                    const SizedBox(height: 20),

                    ElevatedButton(
                      child: const Text("Open Full Review Screen"),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                RiskResultScreen(result: latestRisk!),
                          ),
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 20),

                  ElevatedButton(
                    child: const Text("View Trend Graph"),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RiskHistoryChartScreen(
                            residentId: elder.uid,
                            days: 30,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 10),

                  ElevatedButton(
                    child: const Text("Generate Personalized Plan"),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PersonalizedPlanScreen(
                            residentId: elder.uid,
                            elderEmail: elder.email,
                            mode: PlanMode.generateEditable,
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