import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'PatientHealthDetailsScreen.dart';
import 'auth/login_page.dart';

class ElderProfilePage extends StatelessWidget {
  const ElderProfilePage({Key? key}) : super(key: key);

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
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('elder_health_profiles')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildEmptyState(context);
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildHeader(user),
                const SizedBox(height: 24),
                _buildHealthCard(data),
                const SizedBox(height: 16),
                _buildLifestyleCard(data),
                const SizedBox(height: 16),
                _buildDietCard(data),
                const SizedBox(height: 24),
                // Edit Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PatientHealthDetailsScreen(),
                        ),
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
                MaterialPageRoute(builder: (_) => const PatientHealthDetailsScreen()),
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
            user.email != null && user.email!.isNotEmpty
                ? user.email![0].toUpperCase()
                : 'U',
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

  Widget _buildHealthCard(Map<String, dynamic> data) {
    return _SectionCard(
      title: 'Health Overview',
      icon: Icons.health_and_safety,
      children: [
        _InfoRow(label: 'Age', value: '${data['age'] ?? 'N/A'} years'),
        _InfoRow(label: 'Gender', value: '${data['gender'] ?? 'N/A'}'),
        _InfoRow(label: 'Height', value: '${data['height'] ?? 'N/A'} cm'),
        _InfoRow(label: 'Weight', value: '${data['weight'] ?? 'N/A'} kg'),
        const Divider(),
        _InfoRow(
          label: 'Conditions',
          value: (data['chronicConditions'] as List<dynamic>?)?.join(', ') ?? 'None',
        ),
        _InfoRow(label: 'Blood Type', value: 'Not set'),
      ],
    );
  }

  Widget _buildLifestyleCard(Map<String, dynamic> data) {
    return _SectionCard(
      title: 'Lifestyle',
      icon: Icons.directions_walk,
      children: [
        _InfoRow(label: 'Daily Steps', value: '${data['dailySteps'] ?? 'N/A'}'),
        _InfoRow(label: 'Exercise', value: '${data['exerciseFrequency'] ?? 'N/A'}'),
        _InfoRow(label: 'Sleep', value: '${data['sleepHours'] ?? 'N/A'} hrs/night'),
        _InfoRow(
            label: 'Habits',
            value: [
              if (data['smoking'] == true) 'Smoking',
              if (data['alcohol'] == true) 'Alcohol',
              if (data['smoking'] != true && data['alcohol'] != true) 'None'
            ].join(', ')),
      ],
    );
  }

  Widget _buildDietCard(Map<String, dynamic> data) {
    return _SectionCard(
      title: 'Diet & Nutrition',
      icon: Icons.restaurant,
      children: [
        _InfoRow(label: 'Diet', value: '${data['dietaryHabit'] ?? 'N/A'}'),
        _InfoRow(label: 'Cuisine', value: '${data['preferredCuisine'] ?? 'N/A'}'),
        if (data['foodAllergies'] != null)
          _InfoRow(
            label: 'Allergies',
            value: '${data['foodAllergies']}',
            isWarning: true,
          ),
      ],
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
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 15)),
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
