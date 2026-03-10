import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import 'risk_history_chart_screen.dart';
import 'personalized_plan_screen.dart';

class UpcomingSessionsScreen extends StatelessWidget {
  final AppUser therapist;

  const UpcomingSessionsScreen({super.key, required this.therapist});

  // Frontend demo sessions
  List<_TherapySession> get _demoSessions => const [
        _TherapySession(
          elderName: "Elder - Nimal",
          residentId: "resident_001",
          dateText: "15th January",
          timeText: "4:00 PM",
          mode: "Online",
        ),
        _TherapySession(
          elderName: "Elder - Kumari",
          residentId: "resident_002",
          dateText: "18th January",
          timeText: "11:30 AM",
          mode: "Clinic",
        ),
        _TherapySession(
          elderName: "Elder - Silva",
          residentId: "resident_003",
          dateText: "22nd January",
          timeText: "2:15 PM",
          mode: "Online",
        ),
      ];

  @override
  Widget build(BuildContext context) {
    const brownDark = Color(0xFF3E2723);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Upcoming Sessions"),
        backgroundColor: brownDark,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              "Hello ${therapist.name}, here are your next sessions:",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 12),

            ..._demoSessions.map((s) => _SessionCard(session: s)),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _TherapySession {
  final String elderName;
  final String residentId;
  final String dateText;
  final String timeText;
  final String mode;

  const _TherapySession({
    required this.elderName,
    required this.residentId,
    required this.dateText,
    required this.timeText,
    required this.mode,
  });
}

class _SessionCard extends StatelessWidget {
  final _TherapySession session;

  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),

      child: Padding(
        padding: const EdgeInsets.all(12),

        child: Column(
          children: [

            Row(
              children: [
                const CircleAvatar(
                  child: Icon(Icons.person_outline),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.elderName,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        "Resident: ${session.residentId}",
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.65),
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),

                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(999),
                  ),

                  child: Text(
                    session.mode,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                const Icon(Icons.event, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text("${session.dateText} • ${session.timeText}"),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,

              children: [

                OutlinedButton.icon(
                  onPressed: () {

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RiskHistoryChartScreen(
                          residentId: session.residentId,
                          days: 30,
                        ),
                      ),
                    );
                  },

                  icon: const Icon(Icons.show_chart, size: 18),
                  label: const Text("History"),
                ),

                OutlinedButton.icon(
                  onPressed: () {

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PersonalizedPlanScreen(
                          residentId: session.residentId,
                          elderEmail:
                              "${session.residentId}@gmail.com",
                          mode: PlanMode.viewOnly,
                        ),
                      ),
                    );
                  },

                  icon: const Icon(Icons.article_outlined, size: 18),
                  label: const Text("Plan"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}