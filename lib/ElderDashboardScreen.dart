import 'package:flutter/material.dart';
import 'features/voice_chatbot/screens/chat_screen.dart';
import 'pages/elder/daily_routine_page.dart';
import 'ElderProfilePage.dart';
import 'models/user_model.dart';

// ✅ Your Meal Plan Dashboard
import 'pages/elder/meal_plans/elder_meal_plan_dashboard.dart';

import 'pages/elder/widgets/quick_stats_widget.dart'; // optional
import './RoutineHome.dart';

class ElderDashboard extends StatelessWidget {
  final AppUser user;
  const ElderDashboard({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // ✅ Use theme colors instead of hardcoded brown
    final scheme = Theme.of(context).colorScheme;

    final primary = scheme.primary; // main green
    final secondary = scheme.secondary; // green dark
    final bgTop = Theme.of(context).scaffoldBackgroundColor;
    final bgBottom = scheme.background;

    final titleColor = Colors.black.withOpacity(0.85);
    final subtitleColor = Colors.black.withOpacity(0.55);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgTop, bgBottom],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------------- Top Bar ----------------
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF11BFA8), Color(0xFF11BFA8)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.10),
                            blurRadius: 16,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.favorite, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ElderCare',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Elder Dashboard',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ElderProfilePage(),
                          ),
                        );
                      },
                      icon: Icon(Icons.settings, color: titleColor),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ---------------- Welcome Card ----------------
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.black.withOpacity(0.04),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.waving_hand, color: primary, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome ${user.name ?? 'Back'} 👋',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: titleColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Choose a service to continue',
                              style: TextStyle(
                                fontSize: 13,
                                color: subtitleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ---------------- Grid of Feature Cards ----------------
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.95,
                    children: [
                      _FeatureCard(
                        title: 'Voice Chatbot',
                        subtitle: 'Talk & ask for help',
                        icon: Icons.mic,
                        gradient: [primary, secondary],
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ChatScreen()),
                          );
                        },
                      ),

                      _FeatureCard(
                        title: 'Daily Routine',
                        subtitle: 'Reminders & habits',
                        icon: Icons.schedule,
                        gradient: [primary.withOpacity(0.95), secondary],
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DailyRoutinePage(
                                elderId: user.uid,
                                elderName: user.name,
                              ),
                            ),
                          );
                        },
                      ),

                      // ✅ Meal Planner (NOW opens Elder Meal Plan Dashboard)
                      _FeatureCard(
                        title: 'Meal Planner',
                        subtitle: 'Healthy meals',
                        icon: Icons.restaurant_menu,
                        gradient: [primary, secondary.withOpacity(0.95)],
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ElderMealPlanDashboard(),
                            ),
                          );
                        },
                      ),

                      _FeatureCard(
                        title: 'Therapist',
                        subtitle: 'Mental support',
                        icon: Icons.health_and_safety,
                        gradient: [primary.withOpacity(0.85), secondary],
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Therapist coming soon')),
                          );
                        },
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
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = Colors.black.withOpacity(0.85);
    final subtitleColor = Colors.black.withOpacity(0.55);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(color: Colors.black.withOpacity(0.04)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon badge
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradient,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 14,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),

                const SizedBox(height: 12),

                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: subtitleColor,
                    height: 1.25,
                  ),
                ),

                const Spacer(),

                Row(
                  children: [
                    Text(
                      'Open',
                      style: TextStyle(
                        color: gradient.first,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.arrow_forward, size: 18, color: gradient.first),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
