import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/auth_service.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import '../auth/login_page.dart';

import '../pages/admin/admin_dashboard.dart';
import '../ElderDashboardScreen.dart';
import '../pages/caregiver/caregiver_dashboard.dart';
import '../pages/therapist/therapist_dashboard.dart';
import '../pages/home_dashboard.dart';

import '../services/elder_profile_service.dart';
import '../pages/elder/onboarding_flow.dart';
import '../pages/setup_required_page.dart';

// ✅ Doctor dashboard
import '../pages/doctor/doctor_dashboard_page.dart';

class RoleBasedWrapper extends StatefulWidget {
  const RoleBasedWrapper({super.key});

  @override
  State<RoleBasedWrapper> createState() => _RoleBasedWrapperState();
}

class _RoleBasedWrapperState extends State<RoleBasedWrapper> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  late Future<AppUser?> _userFuture;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _userFuture =
        (user != null) ? _loadUserWithRetries(user.uid) : Future.value(null);
  }

  Future<void> _reload() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _userFuture = _loadUserWithRetries(user.uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      return const LoginPage();
    }

    return FutureBuilder<AppUser?>(
      future: _userFuture,
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // ✅ Handle Future error (rare but useful)
        if (userSnapshot.hasError) {
          return SetupRequiredPage(
            title: "Something went wrong",
            message:
                "We couldn't load your user profile.\n\n"
                "Error: ${userSnapshot.error}\n\n"
                "Try reloading or logging out.",
            onSetupPressed: () async {
              await _authService.signOut();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
          );
        }

        final appUser = userSnapshot.data;

        // ✅ If profile doc missing: try reload once, then sign out if still missing
        if (appUser == null) {
          return SetupRequiredPage(
            title: 'User Profile Not Found',
            message:
                'Your Firebase Auth account exists, but no profile document was found in the "users" collection.\n\n'
                'If you just registered, wait a second and try again.\n\n'
                'Otherwise, log out and sign in again. If the problem persists, contact support.',
            onSetupPressed: () async {
              // Try one reload first (helps with race conditions right after register)
              await _reload();

              final refreshed = await _userFuture;
              if (refreshed != null) return;

              await _authService.signOut();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
          );
        }

        // ✅ Role routing (therapist/doctor included)
        switch (appUser.role) {
          case UserRole.admin:
            return AdminDashboard(user: appUser);

          case UserRole.elder:
            return FutureBuilder<bool>(
              future: ElderProfileService().isOnboardingComplete(appUser.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                final isComplete = snapshot.data ?? false;
                return isComplete
                    ? ElderDashboard(user: appUser)
                    : ElderOnboardingFlow(user: appUser);
              },
            );

          case UserRole.caregiver:
            return CaregiverDashboard(user: appUser);

          case UserRole.doctor:
            return const DoctorDashboardPage();

          case UserRole.therapist:
            return TherapistDashboard(user: appUser);

          case UserRole.familyMember:
            return HomeDashboard(user: appUser);
        }
      },
    );
  }

  Future<AppUser?> _loadUserWithRetries(String uid) async {
    AppUser? appUser;
    int attempts = 0;

    while (appUser == null && attempts < 10) {
      try {
        appUser = await _userService.getUser(uid);
        if (appUser != null) return appUser;
      } catch (_) {}

      if (attempts < 9) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      attempts++;
    }

    return appUser;
  }
}
