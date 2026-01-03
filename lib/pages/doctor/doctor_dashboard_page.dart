import 'package:flutter/material.dart';

import '../../models/doctor_dashboard_item_model.dart';
import '../../models/meal_plan_model.dart';
import '../../services/doctor_dashboard_service.dart';
import '../../services/doctor_meal_plan_service.dart';
import 'widgets/submission_card.dart';
import 'widgets/meal_plan_modal.dart';

class DoctorDashboardPage extends StatefulWidget {
  const DoctorDashboardPage({super.key});

  @override
  State<DoctorDashboardPage> createState() => _DoctorDashboardPageState();
}

class _DoctorDashboardPageState extends State<DoctorDashboardPage> {
  final DoctorDashboardService _dashboardService = DoctorDashboardService();
  final DoctorMealPlanService _mealPlanService = DoctorMealPlanService();

  late Future<List<DoctorDashboardItem>> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  void _loadDashboard() {
    _dashboardFuture = _dashboardService.getDashboard();
  }

  Future<void> _refresh() async {
    setState(() => _loadDashboard());
    await _dashboardFuture;
  }

  // ---------------- MEAL PLAN MODAL ----------------
  void _openMealPlanModal(
      MealPlanModel plan,
      String elderId,
      String submissionId,
      ) {
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
            onEdit: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Edit plan feature coming soon"),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ---------------- GENERATE MEAL PLAN ----------------
  Future<void> _generateMealPlan(
      String elderId,
      String healthSubmissionId,
      ) async {
    try {
      await _mealPlanService.generateMealPlan(
        elderId: elderId,
        healthSubmissionId: healthSubmissionId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Meal plan generated successfully")),
      );

      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to generate meal plan: $e")),
      );
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF9B4DFF);
    const bg = Color(0xFFF6F3FF);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ---------------- HEADER ----------------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              decoration: const BoxDecoration(
                color: purple,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(22),
                  bottomRight: Radius.circular(22),
                ),
              ),
              child: const Column(
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
                    return const Center(
                      child: Text("No patient submissions yet."),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                      children: [
                        const Text(
                          "Patient Submissions",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 12),

                        ...items.map((item) {
                          final MealPlanModel? plan = item.latestMealPlan;

                          final canApproveRejectEdit =
                              plan != null &&
                                  plan.status.toLowerCase() == "pending";

                          return SubmissionCard(
                            // NOTE: SubmissionCard must now accept these fields
                            elderId: item.elderId,
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
                              );
                            },

                            onGenerateMealPlan: () {
                              _generateMealPlan(
                                item.elderId,
                                item.latestSubmissionId,
                              );
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

                            onEdit: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Edit plan feature coming soon",
                                  ),
                                ),
                              );
                            },
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
