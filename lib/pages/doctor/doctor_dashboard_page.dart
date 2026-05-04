import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/doctor_dashboard_item_model.dart';
import '../../models/meal_plan_model.dart';
import '../../services/doctor_dashboard_service.dart';
import '../../services/doctor_meal_plan_service.dart';
import 'widgets/submission_card.dart';
import 'widgets/meal_plan_modal.dart';

// go back to your app auth flow
import '../../widgets/session_wrapper.dart';
import '../../widgets/auth_wrapper.dart';
import '../../pages/shared/elders_selection_screen.dart';
import '../../models/user_model.dart';

class DoctorDashboardPage extends StatefulWidget {
  const DoctorDashboardPage({super.key});

  @override
  State<DoctorDashboardPage> createState() => _DoctorDashboardPageState();
}

/* ======================= RISK BADGES SUPPORT ======================= */
enum _RiskLevel { high, medium, stable }

class _RiskTag {
  final String label;
  final _RiskLevel level;
  const _RiskTag(this.label, this.level);
}
/* =================================================================== */

class _DoctorDashboardPageState extends State<DoctorDashboardPage> {
  final DoctorDashboardService _dashboardService = DoctorDashboardService();
  final DoctorMealPlanService _mealPlanService = DoctorMealPlanService();

  bool _generatingPlan = false;
  late Future<List<DoctorDashboardItem>> _dashboardFuture;

  /* ======================= SEARCH + FILTER (NEW) ======================= */
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedFilter = "All";

  final List<String> _filters = const [
    "All",
    "Pending",
    "High Risk",
    "Diabetes",
    "Hypertension",
    "Heart",
  ];
  /* ==================================================================== */

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _loadDashboard() {
    _dashboardFuture = _dashboardService.getDashboard();

    _dashboardFuture.then((data) {
      print(data);
    }).catchError((e) {
      print("Error: $e");
    });
  }

  Future<void> _refresh() async {
    setState(() => _loadDashboard());
    await _dashboardFuture;
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }

  // SIGN OUT
  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const SessionWrapper(child: AuthWrapper()),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Sign out failed: $e")),
      );
    }
  }

  // ---------------- MEAL PLAN MODAL ----------------
  void _openMealPlanModal(
    MealPlanModel plan,
    String elderId,
    String submissionId, {
    Map<String, dynamic> latestSubmission = const {},
  }) {
    final chronicConditions =
        List<String>.from(latestSubmission['chronic_conditions'] ?? []);

    int? age = latestSubmission['age'];

    double? height = (latestSubmission['height_cm'] is num)
        ? (latestSubmission['height_cm'] as num).toDouble()
        : (latestSubmission['height'] is num)
            ? (latestSubmission['height'] as num).toDouble()
            : null;

    double? weight = (latestSubmission['weight_kg'] is num)
        ? (latestSubmission['weight_kg'] as num).toDouble()
        : (latestSubmission['weight'] is num)
            ? (latestSubmission['weight'] as num).toDouble()
            : null;

    double? bmi;
    if (height != null && weight != null && height > 0) {
      final hMeters = height / 100;
      bmi = weight / (hMeters * hMeters);
    }

    final bp = latestSubmission['blood_pressure'] is Map
        ? Map<String, dynamic>.from(latestSubmission['blood_pressure'])
        : null;

    final bloodSugar = (latestSubmission['blood_sugar_mg_dl'] is num)
        ? (latestSubmission['blood_sugar_mg_dl'] as num).toDouble()
        : null;

    final dietaryHabit = latestSubmission['dietary_habit']?.toString();
    final foodAllergies = latestSubmission['food_allergies']?.toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.92,
          child: MealPlanModal(
            plan: plan,
            chronicConditions: chronicConditions,
            age: age,
            bmi: bmi,
            bloodPressure: bp,
            bloodSugar: bloodSugar,
            dietaryHabit: dietaryHabit,
            foodAllergies: foodAllergies,
            onApprove: () async {
              await _mealPlanService.approve(plan.id);
              if (mounted) Navigator.pop(context);
              await _refresh();
            },
            onReject: () async {
              await _mealPlanService.reject(plan.id);
              if (mounted) Navigator.pop(context);
              await _refresh();
            },
            onEdit: (updated) async {
              if (mounted) Navigator.pop(context);
              await _refresh();
            },
          ),
        );
      },
    );
  }

  // ---------------- GENERATE MEAL PLAN ----------------
  Future<void> _generateMealPlan(String elderId, String healthSubmissionId) async {
    if (_generatingPlan) return;

    setState(() => _generatingPlan = true);
    _showLoadingDialog();

    try {
      await _mealPlanService.generateMealPlan(
        elderId: elderId,
        healthSubmissionId: healthSubmissionId,
      );

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Meal plan generated successfully")),
      );

      await _refresh();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to generate meal plan: $e")),
      );
    } finally {
      if (mounted) setState(() => _generatingPlan = false);
    }
  }

  /* ======================= RISK CALCULATOR ======================= */

  List<_RiskTag> _buildRiskTags(Map<String, dynamic> latestSubmission) {
    final conditions =
        List<String>.from(latestSubmission['chronic_conditions'] ?? []);
    final condLower = conditions.map((e) => e.toLowerCase().trim()).toList();
    final diseaseCount =
        condLower.where((c) => c.isNotEmpty && c != "none").length;

    int? systolic;
    int? diastolic;
    final bp = latestSubmission['blood_pressure'];
    if (bp is Map) {
      final s = bp['systolic'];
      final d = bp['diastolic'];
      if (s is num) systolic = s.toInt();
      if (d is num) diastolic = d.toInt();
    }

    double? sugar;
    final sugarVal = latestSubmission['blood_sugar_mg_dl'];
    if (sugarVal is num) sugar = sugarVal.toDouble();

    final tags = <_RiskTag>[];

    // rules (tweak as you like)
    if (systolic != null && systolic >= 160) {
      tags.add(const _RiskTag("High BP", _RiskLevel.high));
    } else if (systolic != null && systolic >= 140) {
      tags.add(const _RiskTag("BP Elevated", _RiskLevel.medium));
    }

    if (sugar != null && sugar >= 180) {
      tags.add(const _RiskTag("High Sugar", _RiskLevel.high));
    } else if (sugar != null && sugar >= 140) {
      tags.add(const _RiskTag("Sugar Elevated", _RiskLevel.medium));
    }

    if (diseaseCount >= 2) {
      tags.add(const _RiskTag("Complex Case", _RiskLevel.medium));
    }

    if (tags.isEmpty) {
      tags.add(const _RiskTag("Stable", _RiskLevel.stable));
    }

    return tags;
  }

  bool _isHighRisk(Map<String, dynamic> latestSubmission) {
    final tags = _buildRiskTags(latestSubmission);
    return tags.any((t) => t.level == _RiskLevel.high);
  }

  Color _chipBg(_RiskLevel level) {
    switch (level) {
      case _RiskLevel.high:
        return Colors.red.shade100;
      case _RiskLevel.medium:
        return Colors.orange.shade100;
      case _RiskLevel.stable:
        return Colors.green.shade100;
    }
  }

  Color _chipFg(_RiskLevel level) {
    switch (level) {
      case _RiskLevel.high:
        return Colors.red.shade900;
      case _RiskLevel.medium:
        return Colors.orange.shade900;
      case _RiskLevel.stable:
        return Colors.green.shade900;
    }
  }

  Widget _riskChips(List<_RiskTag> tags) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags
          .map(
            (t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _chipBg(t.level),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _chipFg(t.level).withOpacity(0.18)),
              ),
              child: Text(
                t.label,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: _chipFg(t.level),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  /* ======================= FILTERING LOGIC ======================= */

  bool _matchesDisease(Map<String, dynamic> submission, String key) {
    final conditions = List<String>.from(submission['chronic_conditions'] ?? []);
    final lower = conditions.map((e) => e.toLowerCase());
    return lower.any((c) => c.contains(key));
  }

  bool _matchesSearch(DoctorDashboardItem item, String query) {
    if (query.isEmpty) return true;

    final elderId = item.elderId.toLowerCase();
    final submissionId = item.latestSubmissionId.toLowerCase();

    // optional (safe)
    final name = item.latestSubmission['name']?.toString().toLowerCase() ?? "";
    final phone =
        item.latestSubmission['phone']?.toString().toLowerCase() ?? "";

    return elderId.contains(query) ||
        submissionId.contains(query) ||
        name.contains(query) ||
        phone.contains(query);
  }

  bool _matchesFilter(DoctorDashboardItem item) {
    if (_selectedFilter == "All") return true;

    final plan = item.latestMealPlan;
    final sub = item.latestSubmission;

    if (_selectedFilter == "Pending") {
      return plan != null && plan.status.toLowerCase() == "pending";
    }
    if (_selectedFilter == "High Risk") {
      return _isHighRisk(sub);
    }
    if (_selectedFilter == "Diabetes") {
      return _matchesDisease(sub, "diab");
    }
    if (_selectedFilter == "Hypertension") {
      return _matchesDisease(sub, "hyper");
    }
    if (_selectedFilter == "Heart") {
      return _matchesDisease(sub, "heart");
    }
    return true;
  }

  int _riskSortScore(DoctorDashboardItem item) {
    final tags = _buildRiskTags(item.latestSubmission);
    if (tags.any((t) => t.level == _RiskLevel.high)) return 0;
    if (tags.any((t) => t.level == _RiskLevel.medium)) return 1;
    return 2;
  }

  /* =============================================================== */

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF11BFA8);
    const bg = Color(0xFFF6F3FF);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ---------------- HEADER ----------------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 12, 18),
              decoration: const BoxDecoration(
                color: purple,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(22),
                  bottomRight: Radius.circular(22),
                ),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "ElderCare",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Doctor Dashboard",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: "Sign out",
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout, color: Colors.white),
                  ),
                ],
              ),
            ),

            // ---------------- BODY ----------------
            Expanded(
              child: FutureBuilder<List<DoctorDashboardItem>>(
                future: _dashboardFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        "Error loading dashboard\n${snapshot.error}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  final items = snapshot.data ?? [];
                  if (items.isEmpty) {
                    return const Center(child: Text("No patient submissions yet."));
                  }

                  final query = _searchCtrl.text.toLowerCase().trim();

                  // ✅ apply search + filter
                  final filtered = items
                      .where((item) => _matchesSearch(item, query))
                      .where((item) => _matchesFilter(item))
                      .toList();

                  // ✅ auto-sort: high risk first
                  filtered.sort((a, b) {
                    // 1️⃣ First sort by risk (optional)
                    final riskCompare =
                    _riskSortScore(a).compareTo(_riskSortScore(b));

                    if (riskCompare != 0) return riskCompare;

                    // 2️⃣ Then sort by submittedAt (latest first)
                    final aDate = a.submittedAt ?? DateTime(1970);
                    final bDate = b.submittedAt ?? DateTime(1970);

                    return bDate.compareTo(aDate); // DESCENDING
                  });

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                      children: [
                        const Text(
                          "Patient Submissions",
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                        ),
                        const SizedBox(height: 12),

                        // ✅ Health Details Card for Doctor
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.medical_information_outlined,
                                color: Colors.blue.shade700,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Record Medical Details",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Add medical data for an elder",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade700,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EldersSelectionScreen(
                                        title: "Select Elder - Medical Details",
                                        description:
                                            "Record medical conditions and vitals for the selected elder.",
                                        userRole: UserRole.doctor,
                                      ),
                                    ),
                                  );
                                },
                                child: const Text("Select"),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                decoration: InputDecoration(
                                  hintText: "Search patient / ID",
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.black.withOpacity(0.08)),
                              ),
                              child: DropdownButton<String>(
                                value: _selectedFilter,
                                underline: const SizedBox.shrink(),
                                items: _filters
                                    .map((f) =>
                                        DropdownMenuItem(value: f, child: Text(f)))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _selectedFilter = v ?? "All"),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        if (filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 30),
                            child: Center(
                              child: Text(
                                "No results found.",
                                style: TextStyle(color: Colors.black.withOpacity(0.65)),
                              ),
                            ),
                          ),

                        ...filtered.map((item) {
                          final MealPlanModel? plan = item.latestMealPlan;

                          final canApproveRejectEdit =
                              plan != null && plan.status.toLowerCase() == "pending";

                          final tags = _buildRiskTags(item.latestSubmission);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _riskChips(tags),
                                const SizedBox(height: 10),

                                SubmissionCard(
                                  elderId: item.elderId,
                                  elderName: item.elderName,
                                  latestSubmission: item.latestSubmission,
                                  latestMealPlan: plan,
                                  canApproveRejectEdit: canApproveRejectEdit,
                                  onShowMore: () {},
                                  onViewMealPlan: () {
                                    if (plan == null) return;
                                    _openMealPlanModal(
                                      plan,
                                      item.elderId,
                                      item.latestSubmissionId,
                                      latestSubmission: item.latestSubmission,
                                    );
                                  },
                                  onGenerateMealPlan: () {
                                    _generateMealPlan(item.elderId, item.latestSubmissionId);
                                  },
                                  onApprove: () async {
                                    if (plan == null) return;
                                    await _mealPlanService.approve(plan.id);
                                    await _refresh();
                                  },
                                  onReject: () async {
                                    if (plan == null) return;
                                    await _mealPlanService.reject(plan.id);
                                    await _refresh();
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
