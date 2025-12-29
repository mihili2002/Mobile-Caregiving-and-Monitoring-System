import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../auth/auth_service.dart';
import '../auth/login_page.dart';

class HomeDashboard extends StatelessWidget {
  final AppUser user;

  const HomeDashboard({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Dashboard'),
        actions: [
           IconButton(
             icon: const Icon(Icons.logout),
             onPressed: () async {
                await AuthService().signOut();
                if (context.mounted) {
                   Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginPage()), 
                      (route) => false
                   );
                }
             },
           )
        ],
      ),
      body: Center(
        child: Text('Welcome, ${user.name ?? user.email}!'),
      ),
    );
  }
}
