import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/therapy_plan_service.dart';


enum PlanMode {
  viewOnly,
  generateEditable,
}

class PersonalizedPlanScreen extends StatefulWidget {
  final String residentId;
  final PlanMode mode;

  const PersonalizedPlanScreen({
    super.key,
    required this.residentId,
    required this.mode,
  });

  @override
  State<PersonalizedPlanScreen> createState() =>
      _PersonalizedPlanScreenState();
}

class _PersonalizedPlanScreenState extends State<PersonalizedPlanScreen> {
  bool _loading = true;
  bool _editing = false;
  bool _isApproved = false;

  String? _currentPlanId;
  String _status = "";

  List<dynamic> _domains = [];
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    try {
      final result =
          await TherapyPlanService.generatePlan(widget.residentId);

      final plan = result["plan"];

      setState(() {
        _domains = plan["domains"];
        _currentPlanId = plan["id"];
        _status = plan["status"];
        _isApproved = _status == "Active";
        _editing =
            widget.mode == PlanMode.generateEditable && !_isApproved;
        _loading = false;
      });

      // Initialize controllers
      for (var domain in _domains) {
        final text = (domain["interventions"] as List)
            .map((e) =>
                "• ${e["activity"]} (${e["duration"] ?? ""})")
            .join("\n");

        _controllers[domain["domain"]] =
            TextEditingController(text: text);
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading plan: $e")),
      );
    }
  }

  Future<void> _approve() async {
    if (_currentPlanId == null) return;

    final updatedDomains = _domains.map((domain) {
      final controller = _controllers[domain["domain"]];
      final lines = controller!.text.split("\n");

      final interventions = lines
          .where((line) => line.trim().isNotEmpty)
          .map((line) => {
                "activity":
                    line.replaceAll("•", "").trim(),
                "duration": ""
              })
          .toList();

      return {
        "domain": domain["domain"],
        "severity": domain["severity"],
        "interventions": interventions,
      };
    }).toList();

    try {
      await TherapyPlanService.approvePlan(
        planId: _currentPlanId!,
        therapistName: "Dr. Silva",
        domains: updatedDomains,
      );

      setState(() {
        _editing = false;
        _isApproved = true;
        _status = "Active";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("✅ Plan approved and locked")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Approval failed: $e")),
      );
    }
  }

  Future<void> _downloadPdf() async {
    if (_currentPlanId == null) return;

    final url =
        TherapyPlanService.getPdfUrl(_currentPlanId!);

    await launchUrl(Uri.parse(url));
  }

  Widget _buildDomainCard(Map domain) {
    final controller = _controllers[domain["domain"]];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${domain["domain"].replaceAll("_Risk", "")} (${domain["severity"]})",
              style: const TextStyle(
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              enabled: _editing,
              maxLines: 6,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canEdit =
        widget.mode == PlanMode.generateEditable;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Personalized Plan"),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ListView(
                  children: [
                    Text(
                      "Resident: ${widget.residentId}",
                      style: const TextStyle(
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Status: $_status",
                      style: TextStyle(
                        color: _isApproved
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 16),

                    ..._domains
                        .map((d) => _buildDomainCard(d))
                        .toList(),

                    const SizedBox(height: 20),

                    if (canEdit)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isApproved
                                  ? null
                                  : () => setState(() =>
                                      _editing =
                                          !_editing),
                              icon: Icon(_editing
                                  ? Icons.lock
                                  : Icons.edit),
                              label: Text(_editing
                                  ? "Stop Editing"
                                  : "Edit"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  _isApproved ? null : _approve,
                              icon: const Icon(
                                  Icons.check_circle),
                              label:
                                  const Text("Approve"),
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 12),

                    if (_isApproved)
                      ElevatedButton.icon(
                        onPressed: _downloadPdf,
                        icon:
                            const Icon(Icons.picture_as_pdf),
                        label: const Text(
                            "Download Clinical Report"),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}