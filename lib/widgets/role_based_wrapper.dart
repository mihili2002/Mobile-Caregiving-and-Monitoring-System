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

//IMPORTANT: Import Doctor Dashboard
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
    if (user != null) {
      _userFuture = _loadUserWithRetries(user.uid);
    } else {
      _userFuture = Future.value(null);
    }
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

        final appUser = userSnapshot.data;

        if (appUser == null) {
          return SetupRequiredPage(
            title: 'User Profile Not Found',
            message:
                'Your Firebase Auth account exists, but no profile document was found in the "users" collection for this user.\n\n'
                'Please log out and sign in again. If the problem persists, contact support.',
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

        //Role routing
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

          //FIXED ROUTE: Doctor now goes to DoctorDashboardPage
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
