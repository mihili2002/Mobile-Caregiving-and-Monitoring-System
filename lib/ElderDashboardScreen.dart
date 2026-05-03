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
      duration: const Duration(milliseconds: 800),
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
      backgroundColor: theme.scaffoldBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isMobile = width < 600;
          final isTablet = width >= 600 && width < 1024;
          final isDesktop = width >= 1024;

          // Responsive grid configuration
          // Responsive grid configuration
          int crossAxisCount = 2;
          double spacing = 16.0;
          double horizontalPadding = 20.0;
          double maxContentWidth = 1400.0; // Increased for better web utilization
          double aspectRatio = 0.85;

          if (isDesktop) {
            crossAxisCount = 5;
            spacing = 28.0; // More generous spacing for desktop
            horizontalPadding = 48.0;
            aspectRatio = 1.05; // Balanced square-ish cards for desktop
          } else if (isTablet) {
            crossAxisCount = 3;
            spacing = 24.0;
            horizontalPadding = 32.0;
            aspectRatio = 0.95; // Slightly taller for tablet
          } else {
            // Mobile defaults
            aspectRatio = 0.88; 
          }

          return Stack(
            children: [
              // Subtle background gradient
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.scaffoldBackgroundColor,
                        primary.withOpacity(0.02),
                        secondary.withOpacity(0.02),
                      ],
                    ),
                  ),
                ),
              ),

              // Decorative background shape
              Positioned(
                top: -80,
                right: -80,
                child: Container(
                  width: isDesktop ? 500 : 300,
                  height: isDesktop ? 500 : 300,
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.04),
                    shape: BoxShape.circle,
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),

              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        // Header section
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 20),
                          sliver: SliverToBoxAdapter(
                            child: _buildHeader(context, theme, primary),
                          ),
                        ),

                        // Welcome card section
                        SliverPadding(
                          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                          sliver: SliverToBoxAdapter(
                            child: _buildWelcomeCard(theme, primary, isDesktop),
                          ),
                        ),

                        // Section Title
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(horizontalPadding, 40, horizontalPadding, 20),
                          sliver: SliverToBoxAdapter(
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: primary,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Quick Actions',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black.withOpacity(0.7),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Grid section
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 60),
                          sliver: SliverGrid(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: spacing,
                              mainAxisSpacing: spacing,
                              childAspectRatio: aspectRatio,
                            ),
                            delegate: SliverChildListDelegate([
                              _buildAnimatedFeatureCard(
                                0,
                                title: 'Voice Chatbot',
                                subtitle: 'Always here to help',
                                icon: Icons.mic_rounded,
                                color: primary,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ChatScreen(elderUid: widget.user.uid)),
                                ),
                              ),
                              _buildAnimatedFeatureCard(
                                1,
                                title: 'Journal',
                                subtitle: 'Capture thoughts',
                                icon: Icons.auto_stories_rounded,
                                color: const Color(0xFF009688),
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
                                color: const Color(0xFF4DB6AC),
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
                                color: const Color(0xFF26A69A),
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
                                color: secondary,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ElderTherapistSupportPage(user: widget.user)),
                                ),
                              ),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme, Color primary) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(Icons.favorite_rounded, color: primary, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ELDEASE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: primary.withOpacity(0.6),
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'Dashboard',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        _buildHeaderAction(
          icon: Icons.logout_rounded,
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
        ),
        const SizedBox(width: 12),
        _buildHeaderAction(
          icon: Icons.person_rounded,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ElderProfilePage()),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderAction({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
          ),
          child: Icon(icon, color: Colors.black54, size: 20),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(ThemeData theme, Color primary, bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 32 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.black.withOpacity(0.02)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Text('👋', style: TextStyle(fontSize: 32)),
          ),
          const SizedBox(width: 20),
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
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
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
    required Color color,
    required VoidCallback onTap,
  }) {
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        (0.05 * index).clamp(0, 1),
        (0.05 * index + 0.6).clamp(0, 1),
        curve: Curves.easeOutCubic,
      ),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(animation),
        child: _FeatureCard(
          title: title,
          subtitle: subtitle,
          icon: icon,
          color: color,
          onTap: onTap,
        ),
      ),
    );
  }
}

class _FeatureCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1024;
    final cardPadding = isDesktop ? 24.0 : 20.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          elevation: _isHovered ? 12 : 2,
          shadowColor: widget.color.withOpacity(0.15),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(24),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.all(cardPadding),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _isHovered ? widget.color.withOpacity(0.3) : Colors.black.withOpacity(0.04),
                  width: _isHovered ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.color,
                      size: isDesktop ? 32 : 28,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    widget.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                      fontSize: isDesktop ? 18 : 16,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                      fontSize: isDesktop ? 13 : 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
