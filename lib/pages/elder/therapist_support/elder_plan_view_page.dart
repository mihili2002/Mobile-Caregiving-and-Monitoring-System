import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../services/therapy_plan_service.dart';

class ElderPlanViewPage extends StatefulWidget {
  final AppUser user;

  const ElderPlanViewPage({super.key, required this.user});

  @override
  State<ElderPlanViewPage> createState() => _ElderPlanViewPageState();
}

class _ElderPlanViewPageState extends State<ElderPlanViewPage> {

  bool _loading = true;
  List<dynamic> _domains = [];
  String _status = "";

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    try {

      final result =
          await TherapyPlanService.getPlanByEmail(widget.user.email!);

      setState(() {
        _domains = result["domains"];
        _status = result["status"];
        _loading = false;
      });

    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Widget _section(Map domain) {

    final interventions = domain["interventions"] as List;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Text(
              domain["domain"]
                  .replaceAll("_Risk", "")
                  .replaceAll("_", " "),
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800),
            ),

            const SizedBox(height: 8),

            ...interventions.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("• "),
                    Expanded(
                        child: Text(item["activity"])),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text("My Personalized Plan")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [

                  Text(
                    "Hi ${widget.user.name ?? 'there'} 👋",
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    "Your therapist-approved support plan",
                    style: TextStyle(
                        color: Colors.black.withOpacity(0.6)),
                  ),

                  const SizedBox(height: 16),

                  if (_domains.isEmpty)
                    Card(
                      color: Colors.orange.withOpacity(0.08),
                      child: const ListTile(
                        leading: Icon(Icons.info_outline,
                            color: Colors.orange),
                        title: Text("No plan available yet"),
                        subtitle: Text(
                            "Your therapist has not approved a plan yet."),
                      ),
                    ),

                  ..._domains.map((d) => _section(d)).toList(),

                  const SizedBox(height: 18),

                  if (_status == "Active")
                    Card(
                      color: Colors.green.withOpacity(0.08),
                      child: const ListTile(
                        leading: Icon(Icons.verified,
                            color: Colors.green),
                        title: Text("Status: Active"),
                        subtitle: Text(
                            "This plan has been approved by your therapist."),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}