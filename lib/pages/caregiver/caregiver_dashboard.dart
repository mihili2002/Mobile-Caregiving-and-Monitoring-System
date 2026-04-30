import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/notification_model.dart';
import '../../auth/auth_service.dart';
import '../../services/user_service.dart';
import '../../services/notification_service.dart';
import '../../pages/profile_page.dart';
import '../../auth/login_page.dart';
import 'manage_elders_page.dart';
import '../../features/voice_chatbot/screens/elders_emotions_page.dart';
import '../../features/voice_chatbot/screens/all_emotion_screen.dart';
class CaregiverDashboard extends StatefulWidget {
  final AppUser user;

  const CaregiverDashboard({super.key, required this.user});

  @override
  State<CaregiverDashboard> createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends State<CaregiverDashboard> {
  final _userService = UserService();
  final _notificationService = NotificationService();
  int _totalElders = 0;
  bool _isLoading = true;

  // --------- Theme (Green / Mint) ----------
  static const _green900 = Color(0xFF0AAE9B);
  static const _green700 = Color(0xFF13B8A6);
  static const _green200 = Color(0xFFA7DCCB);
  static const _mint = Color(0xFFF2FBF7);
  static const _surface = Colors.white;

  @override
  void initState() {
    super.initState();
    _loadEldersCount();
  }

  Future<void> _loadEldersCount() async {
    try {
      final allUsers = await _userService.getUsersByRole(UserRole.elder);
      if (!mounted) return;
      setState(() {
        _totalElders = allUsers.length;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _displayName() {
    final name = widget.user.name?.trim();
    if (name == null || name.isEmpty) return "Caregiver";
    return name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _mint,
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadEldersCount,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 14),
                _buildStatsCard(),
                const SizedBox(height: 18),
                _buildNotificationSection(),
                const SizedBox(height: 18),
                _buildSectionTitle("Quick Actions"),
                const SizedBox(height: 12),
                _buildQuickActionsGrid(),
                const SizedBox(height: 18),
                _buildSectionTitle("Tips"),
                const SizedBox(height: 10),
                _buildTipCard(
                  icon: Icons.lightbulb_outline,
                  title: "Daily check-in",
                  body:
                      "Ask how the elder feels, review routines, and confirm medications are taken on time.",
                ),
                const SizedBox(height: 10),
                _buildTipCard(
                  icon: Icons.shield_outlined,
                  title: "Emergency readiness",
                  body:
                      "Keep emergency contacts updated and ensure the elder’s key medical info is available.",
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: _green900,
      foregroundColor: Colors.white,
      centerTitle: false,
      title: const Text(
        "Caregiver Dashboard",
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      actions: [
        IconButton(
          tooltip: "Profile",
          icon: const Icon(Icons.person_outline),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfilePage(user: widget.user),
              ),
            );
          },
        ),
        IconButton(
          tooltip: "Logout",
          icon: const Icon(Icons.logout_rounded),
          onPressed: () => _showLogoutDialog(context),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _green200.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 10),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _green700.withOpacity(0.95),
                  _green900.withOpacity(0.95),
                ],
              ),
            ),
            child: const Icon(Icons.health_and_safety, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome, ${_displayName()} 👋",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: _green900.withOpacity(0.95),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _pill(
                      icon: Icons.verified_user_outlined,
                      text: "Caregiver",
                    ),
                    _pill(
                      icon: Icons.task_alt,
                      text: "Manage & monitor",
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  "Manage elders, routines, medications, and keep track of care activities.",
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.35,
                    color: Colors.black.withOpacity(0.55),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _green200.withOpacity(0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _green200.withOpacity(0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _green900.withOpacity(0.95)),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: _green900.withOpacity(0.95),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _green900.withOpacity(0.18),
            _green200.withOpacity(0.10),
            Colors.white.withOpacity(0.95),
          ],
        ),
        border: Border.all(color: _green200.withOpacity(0.85)),
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            offset: const Offset(0, 12),
            color: Colors.black.withOpacity(0.05),
          )
        ],
      ),
      child: _isLoading
          ? Row(
              children: const [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                SizedBox(width: 12),
                Text(
                  "Loading statistics…",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _green200.withOpacity(0.35),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.elderly,
                    size: 34,
                    color: _green900.withOpacity(0.95),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _totalElders.toString(),
                        style: TextStyle(
                          fontSize: 34,
                          height: 1.0,
                          fontWeight: FontWeight.w900,
                          color: _green900.withOpacity(0.95),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Elders under care",
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.55),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green900,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ManageEldersPage(caregiver: widget.user),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text(
                    "View",
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
    );
  }

  // ==========================================================
  // NOTIFICATION SECTION
  // ==========================================================

  Widget _buildNotificationSection() {
    return StreamBuilder<List<CaregiverNotification>>(
      stream: _notificationService.streamCaregiverNotifications(widget.user.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final notifications = snapshot.data
                ?.where((n) => n.needsReview)
                .toList() ??
            [];

        if (notifications.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("Skipped Tasks Needing Review"),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: notifications.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return _buildNotificationCard(notification);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNotificationCard(CaregiverNotification notification) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            blurRadius: 15,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: Colors.red, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  notification.taskName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Elder skipped: \"${notification.reason}\"",
            style: TextStyle(
                fontSize: 13,
                color: Colors.black.withOpacity(0.6),
                fontWeight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _notificationService.markAsReviewed(
                    widget.user.uid, notification),
                style: TextButton.styleFrom(
                  foregroundColor: _green900,
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
                child: const Text("Mark Reviewed"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
    );
  }

  // ✅ UPDATED: Added "Emotions" card
  Widget _buildQuickActionsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 1.05,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildFeatureCard(
          title: "Manage Elders",
          icon: Icons.people_alt_outlined,
          color: const Color(0xFF16A34A),
          description: "View and manage elders",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ManageEldersPage(caregiver: widget.user),
              ),
            );
          },
        ),
        _buildFeatureCard(
          title: "Emotions",
          icon: Icons.mood_outlined,
          color: const Color(0xFF0EA5E9),
          description: "View emotion insights",
         onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EldersEmotionsPage(
        baseUrl: "http://127.0.0.1:8000", // change to your real API url
      ),
    ),
  );
},

        ),
        _buildFeatureCard(
          title: "Daily Routines",
          icon: Icons.calendar_month_outlined,
          color: const Color(0xFF22C55E),
          description: "Manage daily activities",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ManageEldersPage(caregiver: widget.user),
              ),
            );
          },
        ),
        _buildFeatureCard(
          title: "Medications",
          icon: Icons.medication_outlined,
          color: const Color(0xFF7C3AED),
          description: "Manage medications",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ManageEldersPage(caregiver: widget.user),
              ),
            );
          },
        ),
        _buildFeatureCard(
          title: "Reports",
          icon: Icons.assessment_outlined,
          color: const Color(0xFFF59E0B),
          description: "View care reports",
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Reports feature coming soon")),
            );
          },
        ),
        _buildFeatureCard(
          title: "Emergency",
          icon: Icons.emergency_outlined,
          color: const Color(0xFFEF4444),
          description: "Emergency contacts",
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Emergency feature coming soon")),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required IconData icon,
    required Color color,
    required String description,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface.withOpacity(0.96),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _green200.withOpacity(0.85)),
            boxShadow: [
              BoxShadow(
                blurRadius: 18,
                offset: const Offset(0, 10),
                color: Colors.black.withOpacity(0.05),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 30, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.25,
                  color: Colors.black.withOpacity(0.55),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Align(
                alignment: Alignment.bottomRight,
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: Colors.black.withOpacity(0.35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipCard({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _green200.withOpacity(0.85)),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 10),
            color: Colors.black.withOpacity(0.04),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _green200.withOpacity(0.25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: _green900),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: Colors.black.withOpacity(0.55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final authService = AuthService();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      try {
        await authService.signOut();

        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Logged out successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error signing out: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
