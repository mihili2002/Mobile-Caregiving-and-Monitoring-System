import 'package:flutter/material.dart';
import '../../auth/auth_service.dart';
import '../../auth/login_page.dart';
import '../../models/user_model.dart';
import 'therapist_elder_search_page.dart';
import 'upcoming_sessions_screen.dart';

class TherapistDashboard extends StatelessWidget {
  final AppUser user;

  const TherapistDashboard({super.key, required this.user});

  // Healthcare Theme Colors
  static const Color primaryColor = Color(0xFF11BFA8);
  static const Color accentColor = Color(0xFF6C63FF);
  static const Color backgroundColor = Color(0xFFF6F3FF);
  static const Color cardShadow = Color(0x12000000);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildWelcomeText(),
                  const SizedBox(height: 24),
                  
                  _buildSearchBar(context),
                  const SizedBox(height: 30),

                  // _buildSectionHeader("Patient Directory", "View All"),
                  // const SizedBox(height: 12),
                  // _buildMyPatientsScroll(),
                  // const SizedBox(height: 30),

                  _buildSectionHeader("Therapist Hub", null),
                  const SizedBox(height: 16),
                  _buildQuickActionsGrid(context),
                  const SizedBox(height: 30),

                  _buildSectionHeader("Recent Clinical Updates", null),
                  const SizedBox(height: 12),
                  _buildActivityList(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HEADER ---
  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
      decoration: const BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(color: Color(0x33000000), blurRadius: 15, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "ElderCare",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                "Professional Clinical Portal",
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
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
            icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }

  // --- WELCOME ---
  Widget _buildWelcomeText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Clinical Overview",
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Dr. ${user.name}",
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  // --- SEARCH ---
  Widget _buildSearchBar(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TherapistElderSearchPage()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: cardShadow, blurRadius: 10, offset: Offset(0, 2))],
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: primaryColor),
            const SizedBox(width: 12),
            Text(
              "Search patient health records...",
              style: TextStyle(color: Colors.grey[400], fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  // --- SECTION HEADER ---
  Widget _buildSectionHeader(String title, String? action) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF2D3142)),
        ),
        if (action != null)
          Text(
            action,
            style: const TextStyle(color: primaryColor, fontWeight: FontWeight.w700, fontSize: 13),
          ),
      ],
    );
  }

  // --- PATIENTS SCROLL ---
  Widget _buildMyPatientsScroll() {
    final patients = [
      {"name": "Nimal", "img": "https://i.pravatar.cc/150?u=n"},
      {"name": "Kumari", "img": "https://i.pravatar.cc/150?u=k"},
      {"name": "Silva", "img": "https://i.pravatar.cc/150?u=s"},
      {"name": "Perera", "img": "https://i.pravatar.cc/150?u=p"},
      {"name": "Jay", "img": "https://i.pravatar.cc/150?u=j"},
    ];

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: patients.length,
        clipBehavior: Clip.none,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryColor.withOpacity(0.4), width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: NetworkImage(patients[index]['img']!),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  patients[index]['name']!,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- QUICK ACTIONS ---
  Widget _buildQuickActionsGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildActionCard(Icons.analytics_outlined, "Health Insights", Colors.orange),
        _buildActionCard(Icons.description_outlined, "Medical Reports", Colors.blue),
        _buildActionCard(Icons.forum_outlined, "Consultations", Colors.purple),
        _buildActionCard(Icons.settings_suggest_outlined, "Plan Settings", Colors.teal),
      ],
    );
  }

  Widget _buildActionCard(IconData icon, String label, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: cardShadow, blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF4F5E7B)),
          ),
        ],
      ),
    );
  }

  // --- ACTIVITY LIST ---
  Widget _buildActivityList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: cardShadow, blurRadius: 15, offset: Offset(0, 5))],
      ),
      child: Column(
        children: [
          _buildActivityItem(
            Icons.notification_important_rounded,
            "Critical Update",
            "Nimal's anxiety levels rose today.",
            Colors.red,
          ),
          const Divider(height: 1, indent: 60),
          _buildActivityItem(
            Icons.task_alt_rounded,
            "Plan Approved",
            "Support plan for Kumari is now active.",
            Colors.green,
          ),
          const Divider(height: 1, indent: 60),
          _buildActivityItem(
            Icons.pending_actions_rounded,
            "Review Required",
            "Silva submitted a new health self-assessment.",
            Colors.amber,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(IconData icon, String title, String msg, Color color) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
      ),
      subtitle: Text(
        msg,
        style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
    );
  }
}