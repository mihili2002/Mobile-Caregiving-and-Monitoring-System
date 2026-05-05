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

  final Map<String, String> featureQuestions = {
    "Gender": "Gender",
    "Education_Level": "Education Level",
    "Medication_Use": "Medication Use",
    "Substance_Use": "Substance Use",
    "Age": "Age",
    "Sleep_Hours": "Sleep Hours",
    "Physical_Activity_Hrs": "Physical Activity (Hrs)",
    "Social_Support_Score": "Social Support Score",
    "Anxiety_Score": "Anxiety Score",
    "Depression_Score": "Depression Score",
    "Stress_Level": "Stress Level",
    "Family_History_Mental_Illness": "Family History of Mental Illness",
    "Chronic_Illnesses": "Chronic Illnesses",
    "Therapy": "Therapy",
    "Meditation": "Meditation",
    "Financial_Stress": "Financial Stress",
    "Work_Stress": "Work Stress",
    "Self_Esteem_Score": "Self Esteem Score",
    "Life_Satisfaction_Score": "Life Satisfaction Score",
    "Loneliness_Score": "Loneliness Score",
  };

  Widget buildPredictionCard(String title, String riskKey) {
    final pred = latestRisk?["predictions"]?[riskKey];
    final double prob = (pred?["probability"] ?? 0.0).toDouble();
    final String level = (pred?["level"] ?? "N/A").toString();

    Color levelColor = Colors.grey;
    if (level == "Low") {
      levelColor = Colors.green;
    } else if (level == "Medium") {
      levelColor = Colors.orange;
    } else if (level == "High") {
      levelColor = Colors.red;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: levelColor.withOpacity(0.2),
                  border: Border.all(color: levelColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  level,
                  style: TextStyle(
                    color: levelColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        trailing: Text(
          "${(prob * 100).toStringAsFixed(1)}%",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: levelColor,
          ),
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

                    buildPredictionCard("Depression Risk", "Depression_Risk"),
                    buildPredictionCard("Anxiety Risk", "Anxiety_Risk"),
                    buildPredictionCard("Insomnia Risk", "Insomnia_Risk"),
                    buildPredictionCard("Emotional Well-being Risk", "Emotional_WellBeing_Risk"),

                    const SizedBox(height: 30),

                    const Text(
                      "Submitted Questions & Answers",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            if (latestRisk?["features"] != null)
                              ...(latestRisk!["features"] as Map<String, dynamic>)
                                  .entries
                                  .map((entry) {
                                final label = featureQuestions[entry.key] ?? entry.key;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          label,
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        entry.value.toString(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton(
                      child: const Text("Open Full Review Screen"),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                RiskResultScreen(
                                    result: latestRisk!,
                                    elderEmail: elder.email),
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
                            elderEmail: elder.email,
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

                  const SizedBox(height: 10),

                  OutlinedButton(
                    child: const Text("View Current Personalized Plan"),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PersonalizedPlanScreen(
                            residentId: elder.uid,
                            elderEmail: elder.email,
                            mode: PlanMode.viewOnly,
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