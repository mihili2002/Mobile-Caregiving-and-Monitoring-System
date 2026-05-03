import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
 
import '../../../models/meal_plan_model.dart';
import '../../../services/meal_plan_service.dart';
import '../../../PatientHealthDetailsScreen.dart';
import 'meal_plan_detail_page.dart';
import 'all_submissions_screen.dart';
 
class ElderMealPlanDashboard extends StatefulWidget {
  const ElderMealPlanDashboard({super.key});
 
  @override
  State<ElderMealPlanDashboard> createState() => _ElderMealPlanDashboardState();
}
 
class _ElderMealPlanDashboardState extends State<ElderMealPlanDashboard> {
  final MealPlanService _mealPlanService = MealPlanService();
 
  MealPlanModel? _currentPlan;
  List<MealPlanModel> _completedPlans = [];
 
  bool _loading = true;
 
  @override
  void initState() {
    super.initState();
    _loadPlans();
  }
 
  Future<void> _loadPlans() async {
    setState(() => _loading = true);
 
    try {
      final current = await _mealPlanService.getCurrentMealPlan();
      final completed = await _mealPlanService.getCompletedMealPlans();
 
      if (!mounted) return;
      setState(() {
        _currentPlan = current;
        _completedPlans = completed;
      });
    } catch (e) {
      debugPrint("❌ Error loading plans: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading plans: $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
 
  String _formatDateRange(MealPlanModel plan) {
    final df = DateFormat("MMM d");
    return "${df.format(plan.startDate)} – ${df.format(plan.endDate)}";
  }
 
  @override
  Widget build(BuildContext context) {
    const brown = Color(0xFF11BFA8);
    const bgTop = Color(0xFFF8FBFF);
    const bgBottom = Color(0xFFF2F3FA);
 
    return Scaffold(
      appBar: AppBar(
  backgroundColor: brown,
        foregroundColor: Colors.white,
        title: const Text("Meal Plans"),
        centerTitle: true,
        elevation: 0,
  // ✅ back button
  leading: IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => Navigator.pop(context),
  ),
),

      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgTop, bgBottom],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadPlans,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              children: [
                _welcomeCard(),
 
                const SizedBox(height: 14),
 
                // ✅ FULL-WIDTH CARD 1 (Meal Plans)
                _actionCard(
                  icon: Icons.restaurant_menu,
                  iconBg: const Color(0xFFE6FBF7),
                  iconColor: const Color(0xFF11BFA8),
                  title: "Meal Plans",
                  subtitle: "View current & completed plans",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AllSubmissionsScreen(),
                      ),
                    );
                  },
                ),
 
                const SizedBox(height: 12),
 
                // ✅ FULL-WIDTH CARD 2 (Upload Health Details)
                _actionCard(
                  icon: Icons.description_outlined,
                  iconBg: const Color(0xFFF2E9FF),
                  iconColor: const Color(0xFF11BFA8),
                  title: "Upload Health Details",
                  subtitle: "Submit your latest health data",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PatientHealthDetailsScreen(),
                      ),
                    );
                  },
                ),
 
                const SizedBox(height: 18),
 
                _sectionTitle("Current Meal Plan"),
 
                const SizedBox(height: 10),
 
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_currentPlan == null)
                  _emptyCard("No current meal plan found.")
                else
                  _currentMealPlanCard(_currentPlan!),
 
                const SizedBox(height: 18),
 
                // _sectionTitle("Completed Meal Plans"),
                //
                // const SizedBox(height: 10),
                //
                // if (!_loading && _completedPlans.isEmpty)
                //   _emptyCard("No completed meal plans yet."),
                //
                // ..._completedPlans.map(_completedMealPlanCard),
              ],
            ),
          ),
        ),
      ),
    );
  }
 
  // ---------------- UI Components ----------------
 
  Widget _welcomeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Welcome!",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 4),
          Text("Your doctor-approved meal plans will appear here."),
        ],
      ),
    );
  }
 
  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
    );
  }
 
  /// ✅ This matches Photo 2: full width, no overflow, clean
  Widget _actionCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: iconBg,
                  child: Icon(icon, color: iconColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.55),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            "Open",
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: iconColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.arrow_forward, size: 18, color: iconColor),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
 
  Widget _emptyCard(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text),
    );
  }
 
  Widget _currentMealPlanCard(MealPlanModel plan) {
    const teal = Color(0xFF11BFA8);
 
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text(
          //   "Plan ID: ${plan.id}",
          //   style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          // ),
          // const SizedBox(height: 6),
          Text(
            "Status: ${plan.status}",
            style: TextStyle(color: Colors.black.withOpacity(0.70)),
          ),
          const SizedBox(height: 8),
          Text(
            _formatDateRange(plan),
            style: TextStyle(color: Colors.black.withOpacity(0.65)),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MealPlanDetailPage(planId: plan.id),
                  ),
                );
              },
              child: const Text(
                "View Plan",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          )
        ],
      ),
    );
  }
 
  Widget _completedMealPlanCard(MealPlanModel plan) {
    final completedDate = DateFormat("MMM d, yyyy").format(plan.endDate);
 
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                "Plan ID: ${plan.id}",
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                "Completed: $completedDate",
                style: TextStyle(color: Colors.black.withOpacity(0.60)),
              ),
            ]),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MealPlanDetailPage(planId: plan.id),
                ),
              );
            },
            child: const Text("View", style: TextStyle(fontWeight: FontWeight.w900)),
          )
        ],
      ),
    );
  }
}