import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../TherapistRiskFormScreen.dart';

// ✅ Chart screen
import 'risk_history_chart_screen.dart';

// ✅ Plan screen
import 'personalized_plan_screen.dart';

// ✅ NEW: Upcoming sessions page
import 'upcoming_sessions_screen.dart';

class TherapistDashboard extends StatefulWidget {
  final AppUser user;

  const TherapistDashboard({super.key, required this.user});

  @override
  State<TherapistDashboard> createState() => _TherapistDashboardState();
}

class _TherapistDashboardState extends State<TherapistDashboard> {
  final _residentIdController = TextEditingController();
  String? _selectedResidentId;

  @override
  void dispose() {
    _residentIdController.dispose();
    super.dispose();
  }

  void _selectResident() {
    final id = _residentIdController.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter Resident ID")),
      );
      return;
    }
    setState(() => _selectedResidentId = id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Loaded resident: $id")),
    );
  }

  @override
  Widget build(BuildContext context) {
    const brownDark = Color(0xFF3E2723);
    final residentId = _selectedResidentId;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Therapist Dashboard"),
        backgroundColor: brownDark,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Text(
                "Welcome ${widget.user.name}",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),

              // ✅ Resident ID entry box
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Resident Lookup",
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _residentIdController,
                        decoration: const InputDecoration(
                          labelText: "Enter Resident ID (e.g., resident_001)",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 46,
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _selectResident,
                          icon: const Icon(Icons.search),
                          label: const Text("Load Resident"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ✅ Show selected resident info
              if (residentId != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified, color: Colors.green),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Selected Resident: $residentId",
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _selectedResidentId = null),
                        child: const Text("Clear"),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              // ✅ Open risk form
              Card(
                child: ListTile(
                  leading: const Icon(Icons.assignment),
                  title: const Text("Open Therapist Risk Form"),
                  subtitle: const Text("Fill the assessment and predict risk"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TherapistRiskFormScreen()),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // ✅ View prediction graph (requires residentId)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.show_chart),
                  title: const Text("View Prediction History (Graph)"),
                  subtitle: const Text("See 30-day risk trends"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    if (residentId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Load a Resident ID first")),
                      );
                      return;
                    }
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
              ),

              const SizedBox(height: 12),

              // ✅ View current plan (requires residentId)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: const Text("View Current Personalized Plan"),
                  subtitle: const Text(""),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    if (residentId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Load a Resident ID first")),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PersonalizedPlanScreen(
                          residentId: residentId,
                          mode: PlanMode.viewOnly,
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // ✅ NEW: View upcoming sessions (no resident required)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.event_available),
                  title: const Text("View Upcoming Sessions"),
                  subtitle: const Text("See your upcoming meetings with elders "),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UpcomingSessionsScreen(therapist: widget.user),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
