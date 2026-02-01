import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import 'schedule_therapist_meeting_page.dart';
import 'elder_plan_view_page.dart';

class ElderTherapistSupportPage extends StatelessWidget {
  final AppUser user;
  const ElderTherapistSupportPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    const title = "Therapist Support";

    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
    final onPrimary = scheme.onPrimary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(title),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ✅ NEW: Upcoming session nice card
            _UpcomingSessionCard(
              primary: primary,
              onPrimary: onPrimary,
              onReschedule: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ScheduleTherapistMeetingPage(user: user),
                  ),
                );
              },
              onViewDetails: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(" session details page coming soon"),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Schedule meeting
            Card(
              elevation: 2,
              child: ListTile(
                leading: Icon(Icons.video_call, color: primary),
                title: const Text("Schedule a Meeting"),
                subtitle: const Text("Book an appointment with a therapist "),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ScheduleTherapistMeetingPage(user: user),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // View plan
            Card(
              elevation: 2,
              child: ListTile(
                leading: Icon(Icons.assignment_turned_in, color: primary),
                title: const Text("View My Personalized Plan"),
                subtitle: const Text("Read your current plan "),
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

            const SizedBox(height: 18),

            // Text(
            //   "Tip: This is frontend-only for the supervisor demo.\nLater you can connect it to backend plan generation + scheduling.",
            //   style: TextStyle(color: Colors.black.withOpacity(0.6)),
            //   textAlign: TextAlign.center,
            // ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingSessionCard extends StatelessWidget {
  final Color primary;
  final Color onPrimary;
  final VoidCallback onReschedule;
  final VoidCallback onViewDetails;

  const _UpcomingSessionCard({
    required this.primary,
    required this.onPrimary,
    required this.onReschedule,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final subtitleColor = Colors.black.withOpacity(0.65);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary.withOpacity(0.95),
            primary.withOpacity(0.70),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // top row
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.event_available, color: onPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Upcoming Session",
                    style: TextStyle(
                      color: onPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Main message
            Text(
              "Your next meeting with the therapist is at",
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "15th January • 4:00 PM",
              style: TextStyle(
                color: onPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 8),

            // Extra details row (placeholder)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, color: onPrimary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Therapist: Assigned ",
                      style: TextStyle(color: Colors.white.withOpacity(0.92)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Online",
                    style: TextStyle(
                      color: onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onViewDetails,
                    icon: Icon(Icons.info_outline, color: onPrimary),
                    label: Text(
                      "Details",
                      style: TextStyle(color: onPrimary, fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withOpacity(0.6)),
                      backgroundColor: Colors.white.withOpacity(0.10),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onReschedule,
                    icon: const Icon(Icons.edit_calendar),
                    label: const Text(
                      "Reschedule",
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Text(
              "If you can’t attend, reschedule early to keep your support plan on track.",
              style: TextStyle(color: subtitleColor),
            ),
          ],
        ),
      ),
    );
  }
}