import 'package:flutter/material.dart';
import '../../../models/user_model.dart';

class ElderPlanViewPage extends StatelessWidget {
  final AppUser user;
  const ElderPlanViewPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final plan = _demoPlan();

    return Scaffold(
      appBar: AppBar(title: const Text("My Personalized Plan")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              "Hi ${user.name ?? 'there'} 👋",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              "",
              style: TextStyle(color: Colors.black.withOpacity(0.6)),
            ),
            const SizedBox(height: 16),

            _section("Depression Prevention", plan["depression"]!),
            _section("Anxiety Reduction", plan["anxiety"]!),
            _section("Insomnia Improvement", plan["insomnia"]!),
            _section("Emotional Wellbeing", plan["emotional"]!),

            const SizedBox(height: 18),
            Card(
              color: Colors.green.withOpacity(0.08),
              child: const ListTile(
                leading: Icon(Icons.verified, color: Colors.green),
                title: Text("Status: Active "),
                subtitle: Text("Therapist-approved plan will appear here later."),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<String> bullets) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...bullets.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("• "),
                      Expanded(child: Text(b)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Map<String, List<String>> _demoPlan() {
    return {
      "depression": [
        "Take a 15–20 minute walk in the morning (sunlight helps mood).",
        "Talk to a family member/friend once per day (call or message).",
        "Write 3 positive things each night (gratitude journal).",
        "Do one enjoyable activity daily (music, gardening, hobbies).",
      ],
      "anxiety": [
        "Practice 4-7-8 breathing for 2 minutes when feeling stressed.",
        "Limit news/social media to 15 minutes per day.",
        "Drink water and avoid too much caffeine after noon.",
        "Use a simple routine: same wake-up, meals, and bedtime.",
      ],
      "insomnia": [
        "Sleep at the same time daily (even weekends).",
        "No screens 60 minutes before bed (use book or calm music).",
        "Avoid heavy meals late night; warm milk/herbal tea is okay.",
        "Try a 5-minute body scan relaxation before sleeping.",
      ],
      "emotional": [
        "Spend 10 minutes doing mindfulness or prayer/meditation.",
        "Do one social interaction daily (even a short chat).",
        "Join a light physical activity: stretching or chair exercises.",
        "Write down worries → then write one small action you can do.",
      ],
    };
  }
}