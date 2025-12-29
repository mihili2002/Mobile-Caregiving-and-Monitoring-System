import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart'; // Keep for UserRole if needed
import '../auth/auth_service.dart'; // Keep if needed
import '../auth/login_page.dart';
import 'role_based_wrapper.dart'; 

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  // Logic simplified: If Auth -> RoleBasedWrapper (Dashboard).
  // Onboarding is announced ONLY via SignupPage now.

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginPage();
        }

        // User is logged in. 
        // We TRUST that if they are here, they are either an old user 
        // or a new user who just finished signup (via manual nav).
        // If they "Auto Logged In", we SKIP onboarding checks as requested.
        return const RoleBasedWrapper();
      },
    );
  }
}
