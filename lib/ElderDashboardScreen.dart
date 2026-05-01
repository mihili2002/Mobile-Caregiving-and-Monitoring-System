import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mobile_caregiving_and_monitoring_system/features/voice_chatbot/screens/chat_screen.dart';
import 'pages/elder/daily_routine_page.dart';
import 'ElderProfilePage.dart';
import 'models/user_model.dart';
import 'pages/elder/meal_plans/elder_meal_plan_dashboard.dart';
import 'pages/elder/therapist_support/elder_therapist_support_page.dart';
import './RoutineHome.dart';
import '../../features/voice_chatbot/screens/journal_record_page.dart';
import 'auth/auth_service.dart';
import 'auth/login_page.dart';

class ElderDashboard extends StatefulWidget {
  final AppUser user;
  const ElderDashboard({Key? key, required this.user}) : super(key: key);

  @override
  State<ElderDashboard> createState() => _ElderDashboardState();
}

class _ElderDashboardState extends State<ElderDashboard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final primary = scheme.primary;
    final secondary = scheme.secondary;

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.scaffoldBackgroundColor,
                    scheme.background,
                  ],
                ),
              ),
            ),
          ),

          // Abstract background shape
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  sliver: SliverToBoxAdapter(
                    child: _buildHeader(context, theme, primary),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: _buildWelcomeCard(theme, primary),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.88,
                    ),
                    delegate: SliverChildListDelegate([
                      _buildAnimatedFeatureCard(
                        0,
                        title: 'Voice Chatbot',
                        subtitle: 'Always here to help',
                        icon: Icons.mic_rounded,
                        gradient: [primary, primary.withOpacity(0.8)],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ChatScreen(elderUid: widget.user.uid)),
                        ),
                      ),
                      _buildAnimatedFeatureCard(
                        1,
                        title: 'Journal',
                        subtitle: 'Capture your thoughts',
                        icon: Icons.auto_stories_rounded,
                        gradient: [const Color(0xFF00BBA7), const Color(0xFF009688)],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => JournalRecordPage(elderId: widget.user.uid)),
                        ),
                      ),
                      _buildAnimatedFeatureCard(
                        2,
                        title: 'Daily Routine',
                        subtitle: 'Track your habits',
                        icon: Icons.task_alt_rounded,
                        gradient: [const Color(0xFF4DB6AC), const Color(0xFF009688)],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DailyRoutinePage(
                              elderId: widget.user.uid,
                              elderName: widget.user.name,
                            ),
                          ),
                        ),
                      ),
                      _buildAnimatedFeatureCard(
                        3,
                        title: 'Meal Planner',
                        subtitle: 'Healthy nutrition',
                        icon: Icons.restaurant_rounded,
                        gradient: [const Color(0xFF26A69A), const Color(0xFF00897B)],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ElderMealPlanDashboard()),
                        ),
                      ),
                      _buildAnimatedFeatureCard(
                        4,
                        title: 'Therapist',
                        subtitle: 'Guidance & support',
                        icon: Icons.favorite_rounded,
                        gradient: [primary.withOpacity(0.9), secondary],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ElderTherapistSupportPage(user: widget.user)),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme, Color primary) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(Icons.favorite_rounded, color: primary, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'eldease',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: primary.withOpacity(0.8),
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Dashboard',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          elevation: 2,
          shadowColor: Colors.black12,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              }
            },
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.logout_rounded, color: Colors.black54),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          elevation: 2,
          shadowColor: Colors.black12,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ElderProfilePage()),
            ),
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.person_rounded, color: Colors.black54),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeCard(ThemeData theme, Color primary) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '👋',
              style: const TextStyle(fontSize: 28),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, ${widget.user.name ?? 'Friend'}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'How are you feeling today?',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedFeatureCard(
    int index, {
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        (0.1 * index).clamp(0, 1),
        (0.1 * index + 0.5).clamp(0, 1),
        curve: Curves.easeOutQuart,
      ),
    );

    return ScaleTransition(
      scale: animation,
      child: FadeTransition(
        opacity: animation,
        child: _FeatureCard(
          title: title,
          subtitle: subtitle,
          icon: icon,
          gradient: gradient,
          onTap: onTap,
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Bottom right gradient circle
              Positioned(
                bottom: -20,
                right: -20,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [gradient[0].withOpacity(0.1), gradient[1].withOpacity(0.01)],
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: gradient,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: gradient[0].withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 26),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
