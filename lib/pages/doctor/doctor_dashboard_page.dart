import 'package:flutter/material.dart';
import '../../models/elder_health_profile_model.dart';
import '../../models/meal_plan_model.dart';
import '../../services/doctor_dashboard_service.dart';
import 'widgets/submission_card.dart';
import 'widgets/meal_plan_modal.dart';

class DoctorDashboardPage extends StatefulWidget {
  const DoctorDashboardPage({super.key});

  @override
  State<DoctorDashboardPage> createState() => _DoctorDashboardPageState();
}

class _DoctorDashboardPageState extends State<DoctorDashboardPage> {
  final DoctorDashboardService _service = DoctorDashboardService();

  // Cache latest plan per elder (so UI doesn’t keep re-querying)
  final Map<String, MealPlanModel?> _latestPlanCache = {};

  Future<MealPlanModel?> _getLatestPlan(String elderId) async {
    if (_latestPlanCache.containsKey(elderId)) return _latestPlanCache[elderId];

    final plan = await _service.getLatestMealPlanForElder(elderId);
    _latestPlanCache[elderId] = plan;
    return plan;
  }

  Future<void> _refreshCacheFor(String elderId) async {
    final plan = await _service.getLatestMealPlanForElder(elderId);
    setState(() => _latestPlanCache[elderId] = plan);
  }

  void _openMealPlanModal(MealPlanModel plan, String elderId) {
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
              await _service.updateMealPlanStatus(mealPlanDocId: plan.id, status: "Approved");
              if (mounted) Navigator.pop(context);
              await _refreshCacheFor(elderId);
            },
            onReject: () async {
              await _service.updateMealPlanStatus(mealPlanDocId: plan.id, status: "Rejected");
              if (mounted) Navigator.pop(context);
              await _refreshCacheFor(elderId);
            },
            onEdit: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Edit plan feature coming soon")),
              );
            },
          ),
        );
      },
    );
  }

  void _generateMealPlan(String elderId) {
    // TODO: Here you will navigate to your Meal Plan Generator page when you build it.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Generate Meal Plan for Elder: $elderId (Coming soon)")),
    );
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF9B4DFF);
    const bg = Color(0xFFF6F3FF);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header (matches screenshot)
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
                  Text("ElderCare", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                  SizedBox(height: 4),
                  Text("Doctor Dashboard", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ],
              ),
            ),

            Expanded(
              child: StreamBuilder<List<ElderHealthProfileModel>>(
                stream: _service.streamHealthSubmissions(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }

                  final submissions = snapshot.data ?? [];

                  if (submissions.isEmpty) {
                    return const Center(child: Text("No patient submissions yet."));
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      setState(() => _latestPlanCache.clear());
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                      children: [
                        const Text(
                          "Patient Submissions",
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                        ),
                        const SizedBox(height: 12),

                        ...submissions.map((profile) {
                          return FutureBuilder<MealPlanModel?>(
                            future: _getLatestPlan(profile.uid),
                            builder: (context, planSnap) {
                              final plan = planSnap.data;

                              final canApproveRejectEdit =
                                  plan != null && plan.status.toLowerCase() == "pending";

                              return SubmissionCard(
                                profile: profile,
                                latestMealPlan: plan,
                                canApproveRejectEdit: canApproveRejectEdit,

                                onShowMore: () {},

                                onViewMealPlan: () {
                                  if (plan == null) return;
                                  _openMealPlanModal(plan, profile.uid);
                                },

                                onGenerateMealPlan: () {
                                  _generateMealPlan(profile.uid);
                                },

                                onApprove: () async {
                                  if (plan == null) return;
                                  await _service.updateMealPlanStatus(mealPlanDocId: plan.id, status: "Approved");
                                  await _refreshCacheFor(profile.uid);
                                },

                                onReject: () async {
                                  if (plan == null) return;
                                  await _service.updateMealPlanStatus(mealPlanDocId: plan.id, status: "Rejected");
                                  await _refreshCacheFor(profile.uid);
                                },

                                onEdit: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Edit plan feature coming soon")),
                                  );
                                },
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
