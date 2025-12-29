import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../auth/auth_service.dart';
import 'assign_therapy_page.dart';
import '../../auth/login_page.dart';

class TherapistDashboard extends StatefulWidget {
  final AppUser user;
  const TherapistDashboard({super.key, required this.user});

  @override
  State<TherapistDashboard> createState() => _TherapistDashboardState();
}

class _TherapistDashboardState extends State<TherapistDashboard> {
  final UserService _userService = UserService();
  List<AppUser> _elders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadElders();
  }

  Future<void> _loadElders() async {
    try {
      final elders = await _userService.getUsersByRole(UserRole.elder);
      if (mounted) {
        setState(() {
          _elders = elders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
     await AuthService().signOut();
     if (mounted) {
       Navigator.of(context).pushAndRemoveUntil(
         MaterialPageRoute(builder: (_) => const LoginPage()), 
         (route) => false
       );
     }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Therapist Dashboard"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _signOut, icon: const Icon(Icons.logout))
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : _elders.isEmpty 
          ? const Center(child: Text("No elders found."))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _elders.length,
              itemBuilder: (context, index) {
                final elder = _elders[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal.shade100,
                      child: Text(elder.name?[0] ?? "E"),
                    ),
                    title: Text(elder.name ?? "Unknown"),
                    subtitle: Text(elder.email),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AssignTherapyPage(elderId: elder.uid, elderName: elder.name),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
