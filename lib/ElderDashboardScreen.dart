import 'package:flutter/material.dart';
import 'PatientHealthDetailsScreen.dart';
import 'features/voice_chatbot/screens/chat_screen.dart';
import 'pages/elder/daily_routine_page.dart';
import 'ElderProfilePage.dart';
import 'models/user_model.dart';
import 'pages/elder/widgets/quick_stats_widget.dart';


// ✅ ADD THIS IMPORT (make sure the path matches your project structure)
import 'TherapistRiskFormScreen.dart';

class ElderDashboard extends StatelessWidget {
  final AppUser user;
  const ElderDashboard({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // ✅ Match Login/Register design language (brown + soft gradients)
    const brown = Color(0xFF4E342E);
    const brownDark = Color(0xFF3E2723);
    const bgTop = Color(0xFFF7F3F0);
    const bgBottom = Color(0xFFF2EEF5);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
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
                // Top bar
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF6D4C41), Color(0xFF8D6E63)],
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
                        children: const [
                          Text(
                            'ElderCare',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: brownDark,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Elder Dashboard',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: brownDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ElderProfilePage()),
                        );
                      },
                      icon: Icon(Icons.settings, color: brownDark.withOpacity(0.85)),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Welcome header card
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
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: brown.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.waving_hand, color: brown, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome ${user.name ?? 'Back'} 👋',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: brownDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Choose a service to continue',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black.withOpacity(0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Grid
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
                        gradient: const [Color(0xFF3E2723), Color(0xFF6D4C41)],
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
                        gradient: const [Color(0xFF4E342E), Color(0xFF8D6E63)],
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
                      _FeatureCard(
                        title: 'Meal Planner',
                        subtitle: 'Healthy meals',
                        icon: Icons.restaurant_menu,
                        gradient: const [Color(0xFF5D4037), Color(0xFFA1887F)],
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PatientHealthDetailsScreen(),
                            ),
                          );
                        },
                      ),

                      // ✅ FIXED Therapist Card: now navigates to TherapistRiskFormScreen
                      _FeatureCard(
                        title: 'Therapist',
                        subtitle: 'Mental support',
                        icon: Icons.health_and_safety,
                        gradient: const [Color(0xFF3E2723), Color(0xFF8D6E63)],
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TherapistRiskFormScreen(),
                            ),
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
    const brownDark = Color(0xFF3E2723);

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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: brownDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black.withOpacity(0.55),
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
