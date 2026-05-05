import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import 'elder_plan_view_page.dart';
import 'elder_risk_form_screen.dart';

class ElderTherapistSupportPage extends StatelessWidget {
  final AppUser user;

  const ElderTherapistSupportPage({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Dashboard"),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ✅ USER INFO CARD
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: primary,
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name ?? "Elder Name",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.email ?? "email@example.com",
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 🔥 RISK PREDICTION FORM BUTTON
              Card(
                elevation: 2,
                child: ListTile(
                  leading: Icon(Icons.analytics, color: primary),
                  title: const Text("Mental Health Assessment"),
                  subtitle: const Text("Fill your risk prediction form"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ElderRiskFormScreen(
                          currentUser: user, // ✅ CORRECT
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // 🔥 VIEW PERSONALIZED PLAN
              Card(
                elevation: 2,
                child: ListTile(
                  leading: Icon(Icons.assignment, color: primary),
                  title: const Text("View My Personalized Plan"),
                  subtitle: const Text("See your approved care plan"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ElderPlanViewPage(user: user),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Optional helper text
              Text(
                "Complete your self-assessment and track your mental health progress.",
                style: TextStyle(
                  color: Colors.black.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}