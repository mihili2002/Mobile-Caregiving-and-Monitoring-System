import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'PatientHealthDetailsScreen.dart';
import 'auth/login_page.dart';

class ElderProfilePage extends StatelessWidget {
  const ElderProfilePage({super.key});

  // ✅ GREEN THEME COLORS
  static const Color green900 = Color(0xFF007A5E);
  static const Color green700 = Color(0xFF00A884);
  static const Color green500 = Color(0xFF12B981);
  static const Color bgTop = Color(0xFFF2FBF7);

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('User not logged in')),
      );
    }

    return Scaffold(
      backgroundColor: bgTop,
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: green900,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: green900),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: green900),
            onPressed: () => _signOut(context),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('elder_profiles')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data == null || !snapshot.data!.exists) {
            return _buildEmptyState(context);
          }

          final data = snapshot.data!.data() ?? {};
          return _buildElderProfilesUI(context, user, data);
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Profile Incomplete',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          const Text('Please complete your health profile to get better stats.'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PatientHealthDetailsScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: green700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('Complete Profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(User user) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: green500,
          child: Text(
            user.email != null && user.email!.isNotEmpty ? user.email![0].toUpperCase() : 'U',
            style: const TextStyle(
              fontSize: 40,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          user.email ?? 'User',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: green900,
          ),
        ),
        Text(
          'Elder Member',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildElderProfilesUI(BuildContext context, User user, Map<String, dynamic> data) {
    String score(dynamic v) => v == null ? "N/A" : "$v / 5";

    double? probabilityValue;
    final raw = data['prediction_probability'];
    if (raw != null) {
      probabilityValue = double.tryParse(raw.toString());
    }

    final probabilityText =
        probabilityValue == null ? "N/A" : "${(probabilityValue * 100).toStringAsFixed(1)}%";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildHeader(user),
          const SizedBox(height: 24),

          _SectionCard(
            title: "Basic Info",
            icon: Icons.person,
            children: [
              _InfoRow(label: "Age", value: "${data['age'] ?? 'N/A'}"),
              _InfoRow(label: "Long-term illness", value: "${data['long_term_illness'] ?? 'N/A'}"),
              _InfoRow(label: "Completed At", value: "${data['completed_at'] ?? data['created_at'] ?? 'N/A'}"),
            ],
          ),

          const SizedBox(height: 16),

          _SectionCard(
            title: "Sleep & Energy",
            icon: Icons.bedtime,
            children: [
              _InfoRow(label: "Sleep well", value: score(data['sleep_well_1to5'])),
              _InfoRow(label: "Tired during day", value: score(data['tired_day_1to5'])),
            ],
          ),

          const SizedBox(height: 16),

          _SectionCard(
            title: "Memory & Daily Tasks",
            icon: Icons.psychology,
            children: [
              _InfoRow(label: "Forget recent things", value: score(data['forget_recent_1to5'])),
              _InfoRow(label: "Difficulty remembering tasks", value: score(data['difficulty_remember_tasks_1to5'])),
              _InfoRow(label: "Forget taking meds", value: score(data['forget_take_meds_1to5'])),
              _InfoRow(label: "Tasks feel harder", value: score(data['tasks_harder_1to5'])),
            ],
          ),

          const SizedBox(height: 16),

          _SectionCard(
            title: "Mood & Social",
            icon: Icons.mood,
            children: [
              _InfoRow(label: "Loneliness", value: score(data['lonely_1to5'])),
              _InfoRow(label: "Sad / anxious", value: score(data['sad_anxious_1to5'])),
              _InfoRow(label: "Social talk", value: score(data['social_talk_1to5'])),
              _InfoRow(label: "Enjoy hobbies", value: score(data['enjoy_hobbies_1to5'])),
            ],
          ),

          const SizedBox(height: 16),

          _SectionCard(
            title: "App & Reminders",
            icon: Icons.notifications_active,
            children: [
              _InfoRow(label: "Comfort with app", value: score(data['comfortable_app_1to5'])),
              _InfoRow(label: "Reminders helpful", value: score(data['reminders_helpful_1to5'])),
              _InfoRow(label: "Right time", value: score(data['reminders_right_time_1to5'])),
              _InfoRow(label: "Reminder preference", value: "${data['reminders_preference'] ?? 'N/A'}"),
            ],
          ),

          const SizedBox(height: 16),

          _SectionCard(
            title: "Risk Prediction",
            icon: Icons.analytics,
            children: [
              _InfoRow(label: "Tier", value: "${data['prediction_tier'] ?? 'N/A'}"),
              _InfoRow(label: "Probability", value: probabilityText),
              _InfoRow(label: "Updated At", value: "${data['prediction_updated_at'] ?? 'N/A'}"),
            ],
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PatientHealthDetailsScreen()),
                );
              },
              icon: const Icon(Icons.edit),
              label: const Text('Edit Profile'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: green700),
                foregroundColor: green700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  // ✅ GREEN THEME COLORS
  static const Color green900 = Color(0xFF007A5E);
  static const Color green700 = Color(0xFF00A884);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: green700),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: green900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isWarning;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isWarning = false,
  });

  // ✅ GREEN THEME COLORS
  static const Color green900 = Color(0xFF007A5E);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 15),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isWarning ? Colors.red[700] : green900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
