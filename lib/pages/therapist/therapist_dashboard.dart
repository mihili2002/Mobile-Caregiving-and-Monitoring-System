import 'package:flutter/material.dart';
import '../../auth/auth_service.dart';
import '../../auth/login_page.dart';
import '../../models/user_model.dart';
import 'therapist_elder_search_page.dart'; // ✅ NEW PAGE
import 'upcoming_sessions_screen.dart';

class TherapistDashboard extends StatelessWidget {
  final AppUser user;

  const TherapistDashboard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3FF),
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 12, 18),
              decoration: const BoxDecoration(
                color: Color(0xFF11BFA8),
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
                          "Therapist Dashboard",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      await AuthService().signOut();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                          (route) => false,
                        );
                      }
                    },
                    icon: const Icon(Icons.logout, color: Colors.white),
                  ),
                ],
              ),
            ),

            // BODY
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ListView(
                  children: [
                    Text(
                      "Welcome ${user.name}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 🔥 SEARCH ELDERS
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.search),
                        title: const Text("Search Elders"),
                        subtitle: const Text("Find elder by name"),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TherapistElderSearchPage(),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // UPCOMING SESSIONS
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.event_available),
                        title: const Text("Upcoming Sessions"),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UpcomingSessionsScreen(
                                therapist: user,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}