import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../../auth/auth_service.dart';
import '../services/user_service.dart';
import '../../auth/login_page.dart';

class ProfilePage extends StatefulWidget {
  final AppUser user;

  const ProfilePage({super.key, required this.user});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();
  
  // This future will hold our extra profile data
  late Future<Map<String, dynamic>?> _profileDataFuture;

  @override
  void initState() {
    super.initState();
    // Start fetching data as soon as the page loads
    _profileDataFuture = _userService.getElderProfile(widget.user.uid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 1. Basic User Info Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.green,
                      child: Icon(Icons.person, size: 40, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.user.name ?? "Elder",
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      widget.user.email,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Text(
                        widget.user.role.toString().split('.').last.toUpperCase(),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 2. Detailed Health Profile (Fetched from Firestore)
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
                child: Text(
                  "Health Profile",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
            ),
            
            FutureBuilder<Map<String, dynamic>?>(
              future: _profileDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                }

                if (snapshot.hasError) {
                  return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text("Error loading profile data")));
                }

                final data = snapshot.data;

                if (data == null) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text("No health profile found. Please complete onboarding."),
                    ),
                  );
                }

                // If data exists, show it nicely
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildProfileRow(Icons.cake, "Age", "${data['age']} Years"),
                        const Divider(),
                        _buildProfileRow(Icons.healing, "Long-term Condition", "${data['long_term_illness']}"),
                        const Divider(),
                        // Highlighted Risk Tier
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _getTierColor(data['prediction_tier']).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _getTierColor(data['prediction_tier'])),
                          ),
                          child: Row(
                             children: [
                               Icon(Icons.shield, color: _getTierColor(data['prediction_tier'])),
                               const SizedBox(width: 12),
                               Expanded(
                                 child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     const Text("Support Level", style: TextStyle(fontSize: 12, color: Colors.grey)),
                                     Text(
                                       _friendlyTier(data['prediction_tier']), 
                                       style: TextStyle(
                                         fontSize: 18, 
                                         fontWeight: FontWeight.bold,
                                         color: _getTierColor(data['prediction_tier'])
                                       )
                                     ),
                                   ],
                                 ),
                               )
                             ],
                          ),
                        ),
                        const Divider(),
                        _buildProfileRow(Icons.bed, "Sleep Quality", _textForSleep(data['sleep_well_1to5'])),
                        const Divider(),
                        _buildProfileRow(Icons.psychology, "Memory Status", _textForMemory(data['forget_recent_1to5'])),
                        const Divider(),
                        _buildProfileRow(Icons.bolt, "Energy Level", _textForEnergy(data['tired_day_1to5'])),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getTierColor(String? tier) {
    if (tier == null) return Colors.grey;
    if (tier.contains("Tier 1")) return Colors.green;
    if (tier.contains("Tier 2")) return Colors.orange;
    return Colors.red;
  }

  String _friendlyTier(String? tier) {
     if (tier == null) return "Unknown";
     if (tier.contains("Tier 1")) return "Low Support";
     if (tier.contains("Tier 2")) return "Medium Support";
     if (tier.contains("Tier 3")) return "High Support";
     return tier;
  }

  String _textForSleep(dynamic score) {
    int s = _toInt(score);
    if (s >= 4) return "Restful";
    if (s == 3) return "Moderate";
    return "Needs Improvement";
  }

  String _textForMemory(dynamic score) {
    // Score is "Often forgets": 1(Disagree/Good) to 5(Agree/Bad)
    int s = _toInt(score);
    if (s <= 2) return "Sharp";
    if (s == 3) return "Average";
    return "Forgetful";
  }

  String _textForEnergy(dynamic score) {
    // Score is "Often tired": 1(Disagree/Good) to 5(Agree/Bad)
    int s = _toInt(score);
    if (s <= 2) return "High Energy";
    if (s == 3) return "Moderate";
    return "Low Energy";
  }

  int _toInt(dynamic val) {
    if (val is int) return val;
    if (val is double) return val.toInt();
    if (val is String) return int.tryParse(val) ?? 3;
    return 3;
  }

  Widget _buildProfileRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.green, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Logout", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }
}

