import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../auth/auth_service.dart';
import '../auth/login_page.dart';

/// A widget that ensures only authorized users with the correct role can access content
class AuthorizedWrapper extends StatelessWidget {
  final Widget child;
  final List<UserRole> allowedRoles;
  final AppUser? user;

  const AuthorizedWrapper({
    super.key,
    required this.child,
    required this.allowedRoles,
    this.user,
  });

  @override
  Widget build(BuildContext context) {
    // If no user provided, try to get current user
    if (user == null) {
      return FutureBuilder<AppUser?>(
        future: AuthService().getCurrentAppUser(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final appUser = snapshot.data;
          if (appUser == null || !allowedRoles.contains(appUser.role)) {
            return const LoginPage();
          }

          return child;
        },
      );
    }

    // Check if user's role is in allowed roles
    if (!allowedRoles.contains(user!.role)) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock,
                size: 64,
                color: Colors.red,
              ),
              SizedBox(height: 16),
              Text(
                'You do not have permission to access this page.',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return child;
  }
}

