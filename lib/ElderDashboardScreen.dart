import 'dart:ui';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
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
import 'services/schedule_service.dart';
import 'services/meal_plan_service.dart';
import 'services/behavior_service.dart';
import 'services/user_service.dart';
import 'models/meal_plan_model.dart';

class ElderDashboard extends StatefulWidget {
  final AppUser user;
  const ElderDashboard({Key? key, required this.user}) : super(key: key);

  @override
  State<ElderDashboard> createState() => _ElderDashboardState();
}

class _ElderDashboardState extends State<ElderDashboard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  final ScheduleService _scheduleService = ScheduleService();
  final MealPlanService _mealPlanService = MealPlanService();
  final BehaviorService _behaviorService = BehaviorService();

  List<dynamic> _dailyTasks = [];
  MealPlanModel? _currentMealPlan;
  List<dynamic> _insights = [];
  bool _hasJournalToday = false;
  bool _isLoading = true;
  
  Timer? _clockTimer;
  String _timeString = "";

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _controller.forward();
    _loadDashboardData();
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateTime());
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _updateTime() {
    final DateTime now = DateTime.now();
    final String formattedTime = _formatDateTime(now);
    if (mounted) {
      setState(() {
        _timeString = formattedTime;
      });
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}";
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // Parallel fetching for efficiency
      final results = await Future.wait([
        _scheduleService.getSchedule(widget.user.uid, DateTime.now()),
        _mealPlanService.getCurrentMealPlan(),
        _behaviorService.getInsights(),
        _checkJournalToday(),
      ]);

      if (!mounted) return;

      setState(() {
        final scheduleData = results[0] as Map<String, dynamic>?;
        _dailyTasks = scheduleData != null ? List<dynamic>.from(scheduleData['tasks'] ?? []) : [];
        _currentMealPlan = results[1] as MealPlanModel?;
        _insights = results[2] as List<dynamic>? ?? [];
        _hasJournalToday = results[3] as bool? ?? false;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading dashboard data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _checkJournalToday() async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) return false;

      final baseUrl = UserService.getApiUrl(null);
      final response = await http.get(
        Uri.parse("$baseUrl/chatbot/journals?limit=5"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List? ?? [];
        if (items.isEmpty) return false;

        final today = DateTime.now();
        final todayStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

        return items.any((item) {
          final createdAt = item['createdAtIso'] ?? item['displayTime'] ?? "";
          return createdAt.toString().startsWith(todayStr);
        });
      }
    } catch (e) {
      debugPrint("Error checking journal status: $e");
    }
    return false;
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

          // Responsive configuration
          double horizontalPadding = isDesktop ? 48.0 : (isTablet ? 32.0 : 20.0);
          double maxContentWidth = 1200.0;
          int gridColumns = isDesktop ? 5 : (isTablet ? 3 : 2);
          double gridAspectRatio = isDesktop ? 1.15 : (isTablet ? 1.0 : 0.9);

          return Stack(
            children: [
              // Subtle background
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.scaffoldBackgroundColor,
                        primary.withOpacity(0.01),
                        secondary.withOpacity(0.01),
                      ],
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: RefreshIndicator(
                      onRefresh: _loadDashboardData,
                      child: CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          // 1. Header
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 16),
                            sliver: SliverToBoxAdapter(
                              child: _buildHeader(context, theme, primary),
                            ),
                          ),

                          if (_isLoading)
                            const SliverFillRemaining(
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else ...[
                            // 2. Today Overview (High Priority)
                            SliverPadding(
                              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                              sliver: SliverToBoxAdapter(
                                child: _buildTodayOverview(theme, primary, isDesktop),
                              ),
                            ),

                            // 3. Quick Actions Title
                            SliverPadding(
                              padding: EdgeInsets.fromLTRB(horizontalPadding, 32, horizontalPadding, 16),
                              sliver: SliverToBoxAdapter(
                                child: _buildSectionTitle(theme, 'Quick Actions', primary),
                              ),
                            ),

                            // 4. Quick Actions Grid
                            SliverPadding(
                              padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 24),
                              sliver: SliverGrid(
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: gridColumns,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: gridAspectRatio,
                                ),
                                delegate: SliverChildListDelegate([
                                  _buildFeatureCard(
                                    0,
                                    title: 'Voice Chatbot',
                                    subtitle: 'Always here',
                                    icon: Icons.mic_rounded,
                                    color: primary,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => ChatScreen(elderUid: widget.user.uid)),
                                    ),
                                  ),
                                  _buildFeatureCard(
                                    1,
                                    title: 'Journal',
                                    subtitle: 'Capture thoughts',
                                    icon: Icons.auto_stories_rounded,
                                    color: const Color(0xFF009688),
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => JournalRecordPage(elderId: widget.user.uid)),
                                      );
                                      _loadDashboardData();
                                    },
                                  ),
                                  _buildFeatureCard(
                                    2,
                                    title: 'Daily Routine',
                                    subtitle: 'Track habits',
                                    icon: Icons.task_alt_rounded,
                                    color: const Color(0xFF4DB6AC),
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => DailyRoutinePage(
                                            elderId: widget.user.uid,
                                            elderName: widget.user.name,
                                          ),
                                        ),
                                      );
                                      _loadDashboardData();
                                    },
                                  ),
                                  _buildFeatureCard(
                                    3,
                                    title: 'Meal Planner',
                                    subtitle: 'Healthy eating',
                                    icon: Icons.restaurant_rounded,
                                    color: const Color(0xFF26A69A),
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const ElderMealPlanDashboard()),
                                      );
                                      _loadDashboardData();
                                    },
                                  ),
                                  _buildFeatureCard(
                                    4,
                                    title: 'Therapist',
                                    subtitle: 'Guidance',
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

                            // 5. Context-Aware Content
                            SliverPadding(
                              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                              sliver: SliverList(
                                delegate: SliverChildListDelegate([
                                  const SizedBox(height: 8),
                                  
                                  // Reminders and Progress grouped on desktop
                                  if (isDesktop)
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: _buildUpcomingReminders(theme, primary)),
                                        const SizedBox(width: 24),
                                        Expanded(child: _buildProgressTracker(theme, primary)),
                                      ],
                                    )
                                  else ...[
                                    _buildUpcomingReminders(theme, primary),
                                    const SizedBox(height: 24),
                                    _buildProgressTracker(theme, primary),
                                  ],

                                  const SizedBox(height: 24),

                                  // Health and Meals grouped on desktop
                                  if (isDesktop)
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: _buildHealthMoodCard(theme, primary)),
                                        const SizedBox(width: 24),
                                        Expanded(child: _buildMealPlanPreview(theme, primary)),
                                      ],
                                    )
                                  else ...[
                                    _buildHealthMoodCard(theme, primary),
                                    const SizedBox(height: 24),
                                    _buildMealPlanPreview(theme, primary),
                                  ],

                                  const SizedBox(height: 24),

                                  // AI Suggestions
                                  _buildSmartSuggestions(theme, primary),

                                  const SizedBox(height: 24),

                                  // Emergency Section
                                  _buildEmergencySection(theme, primary),
                                  
                                  const SizedBox(height: 60),
                                ]),
                              ),
                            ),
                          ],
                        ],
                      ),
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

  // --- Header ---
  Widget _buildHeader(BuildContext context, ThemeData theme, Color primary) {
    return Row(
      children: [
        Hero(
          tag: 'logo',
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
            ),
            child: Icon(Icons.favorite_rounded, color: primary, size: 24),
          ),
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
                'Elder Dashboard',
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

  // --- 1. Today Overview ---
  Widget _buildTodayOverview(ThemeData theme, Color primary, bool isDesktop) {
    final now = DateTime.now();
    final dateString = "${now.day} ${_getMonth(now.month)}, ${now.year}";

    final totalTasks = _dailyTasks.length;
    final completedTasks = _dailyTasks.where((t) => t['completed'] == true).length;
    final hasPlan = totalTasks > 0;

    // Find next task
    Map<String, dynamic>? nextTask;
    if (hasPlan) {
      final pending = _dailyTasks.where((t) => t['completed'] != true).toList();
      if (pending.isNotEmpty) {
        pending.sort((a, b) => (a['time'] ?? "").compareTo(b['time'] ?? ""));
        nextTask = pending.first;
      }
    }

    return Container(
      padding: EdgeInsets.all(isDesktop ? 32 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateString,
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hello, ${widget.user.name ?? 'Friend'} 👋',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              if (isDesktop) ...[
                _buildDigitalClock(primary, true),
                if (hasPlan && nextTask != null) ...[
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Text('Next: ${nextTask['task_name']}', style: TextStyle(color: primary, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ],
          ),
          if (!isDesktop) ...[
            const SizedBox(height: 16),
            _buildDigitalClock(primary, false),
          ],
          const SizedBox(height: 20),
          if (hasPlan)
            Row(
              children: [
                _buildOverviewStat(Icons.check_circle_outline_rounded, "$completedTasks/$totalTasks Tasks Done", Colors.green),
                const SizedBox(width: 24),
                _buildOverviewStat(Icons.wb_sunny_outlined, _getRoutinePeriod(now.hour), Colors.orange),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "No plan set for today. Start your day by organizing your routine.",
                  style: TextStyle(color: Colors.black54, fontSize: 14),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DailyRoutinePage(
                          elderId: widget.user.uid,
                          elderName: widget.user.name,
                        ),
                      ),
                    );
                    _loadDashboardData();
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text("Create Today's Plan"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDigitalClock(Color primary, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time_filled_rounded, color: primary, size: isDesktop ? 20 : 18),
          const SizedBox(width: 8),
          Text(
            _timeString,
            style: TextStyle(
              fontSize: isDesktop ? 22 : 18,
              fontWeight: FontWeight.w900,
              color: primary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  String _getRoutinePeriod(int hour) {
    if (hour < 12) return "Morning Routine";
    if (hour < 17) return "Afternoon Routine";
    return "Evening Routine";
  }

  Widget _buildOverviewStat(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
      ],
    );
  }

  // --- 2. Upcoming Reminders ---
  Widget _buildUpcomingReminders(ThemeData theme, Color primary) {
    final pending = _dailyTasks.where((t) => t['completed'] != true).toList();
    pending.sort((a, b) => (a['time'] ?? "").compareTo(b['time'] ?? ""));

    final displayItems = pending.take(3).toList();
    final hasMore = pending.length > 3;
    final moreCount = pending.length - 3;

    return _buildSectionCard(
      title: 'Upcoming Reminders',
      icon: Icons.notification_important_rounded,
      primaryColor: primary,
      child: pending.isEmpty
          ? _buildEmptyState(
              "No reminders scheduled for today.",
              "Set up your routine to receive alerts.",
              Icons.notifications_none_rounded,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DailyRoutinePage(
                      elderId: widget.user.uid,
                      elderName: widget.user.name,
                    ),
                  ),
                );
                _loadDashboardData();
              },
              btnLabel: "Add Reminder",
              primary: primary,
            )
          : Column(
              children: [
                ...displayItems.map((t) {
                  final index = displayItems.indexOf(t);
                  return _buildReminderItem(
                    t['time'] ?? "--:--",
                    t['task_name'] ?? "Task",
                    _getTaskIcon(t['type'] ?? ""),
                    _getTaskColor(t['type'] ?? ""),
                    index == 0,
                  );
                }).toList(),
                if (hasMore) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "+$moreCount more reminders",
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DailyRoutinePage(
                                elderId: widget.user.uid,
                                elderName: widget.user.name,
                              ),
                            ),
                          );
                          _loadDashboardData();
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text("View Full Schedule"),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_rounded, size: 14),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else if (pending.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DailyRoutinePage(
                              elderId: widget.user.uid,
                              elderName: widget.user.name,
                            ),
                          ),
                        );
                        _loadDashboardData();
                      },
                      child: const Text("View Full Schedule"),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  IconData _getTaskIcon(String type) {
    switch (type) {
      case 'medication': return Icons.medication_rounded;
      case 'restaurant':
      case 'meal':
      case 'common': return Icons.restaurant_rounded;
      case 'therapy': return Icons.favorite_rounded;
      default: return Icons.task_alt_rounded;
    }
  }

  Color _getTaskColor(String type) {
    switch (type) {
      case 'medication': return Colors.redAccent;
      case 'meal':
      case 'common': return Colors.green;
      case 'therapy': return Colors.blue;
      default: return Colors.orange;
    }
  }

  Widget _buildReminderItem(String time, String label, IconData icon, Color color, bool isNext) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isNext ? color.withOpacity(0.08) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: isNext ? Border.all(color: color.withOpacity(0.3)) : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(time, style: const TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
          ),
          if (isNext)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
              child: const Text('NEXT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  // --- 3. Routine Progress Tracker ---
  Widget _buildProgressTracker(ThemeData theme, Color primary) {
    final totalTasks = _dailyTasks.length;
    final completedTasks = _dailyTasks.where((t) => t['completed'] == true).length;
    final progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;

    return _buildSectionCard(
      title: 'Routine Progress',
      icon: Icons.insights_rounded,
      primaryColor: primary,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 120,
                width: 120,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 12,
                  backgroundColor: Colors.black.withOpacity(0.05),
                  valueColor: AlwaysStoppedAnimation<Color>(primary),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                children: [
                  Text('${(progress * 100).toInt()}%', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: primary)),
                  const Text('Complete', style: TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (totalTasks > 0) ...[
            Text('$completedTasks of $totalTasks activities completed', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(progress >= 1.0 ? 'Everything done! Amazing job.' : (progress > 0 ? 'You\'re doing great! Keep it up.' : 'Start your first task to see progress.'), 
                 style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ] else
            const Text('Create today\'s routine to start tracking progress.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.black54)),
        ],
      ),
    );
  }

  // --- 4. Health / Mood Status ---
  Widget _buildHealthMoodCard(ThemeData theme, Color primary) {
    // Simple logic: if insights exist, use the first one as mood
    String moodEmoji = "😊";
    String moodLabel = "Feeling Good";
    String insightText = "Your mood has been positive lately.";
    
    if (_insights.isNotEmpty) {
      final latest = _insights.first.toString();
      insightText = latest;
      if (latest.toLowerCase().contains("sad") || latest.toLowerCase().contains("unhappy")) {
        moodEmoji = "😟";
        moodLabel = "Feeling Down";
      }
    }

    return _buildSectionCard(
      title: 'Mood & Health',
      icon: Icons.mood_rounded,
      primaryColor: primary,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(moodEmoji, style: const TextStyle(fontSize: 32)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(moodLabel, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 4),
                Text(
                  insightText,
                  style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 5. Meal Plan Preview ---
  Widget _buildMealPlanPreview(ThemeData theme, Color primary) {
    final hasMealPlan = _currentMealPlan != null && _currentMealPlan!.days.isNotEmpty;
    
    return _buildSectionCard(
      title: 'Today\'s Meals',
      icon: Icons.restaurant_menu_rounded,
      primaryColor: primary,
      child: !hasMealPlan
          ? _buildEmptyState(
              "No meal plan added for today.",
              "Ask your caregiver or set up a plan.",
              Icons.no_meals_rounded,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ElderMealPlanDashboard()),
                );
                _loadDashboardData();
              },
              btnLabel: "Add Meal Plan",
              primary: primary,
            )
          : Column(
              children: [
                _buildDynamicMealItem('Breakfast', _currentMealPlan!.days.first.meals.breakfast),
                _buildDynamicMealItem('Lunch', _currentMealPlan!.days.first.meals.lunch),
                _buildDynamicMealItem('Dinner', _currentMealPlan!.days.first.meals.dinner),
              ],
            ),
    );
  }

  Widget _buildDynamicMealItem(String type, List<MealItem> items) {
    final menu = items.isNotEmpty ? items.map((e) => e.foodName).join(", ") : "Not specified";
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.radio_button_unchecked_rounded, color: Colors.black12, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.black54)),
                Text(menu, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 6. Emergency Section ---
  Widget _buildEmergencySection(ThemeData theme, Color primary) {
    return Row(
      children: [
        Expanded(
          child: _buildActionBtn(
            label: 'Call Caregiver',
            icon: Icons.phone_in_talk_rounded,
            color: primary,
            onTap: () {},
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildActionBtn(
            label: 'EMERGENCY',
            icon: Icons.emergency_rounded,
            color: Colors.red,
            isEmergency: true,
            onTap: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildActionBtn({required String label, required IconData icon, required Color color, required VoidCallback onTap, bool isEmergency = false}) {
    return Material(
      color: isEmergency ? color : Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: isEmergency ? 4 : 0,
      shadowColor: color.withOpacity(0.3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: isEmergency ? null : Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: isEmergency ? Colors.white : color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: isEmergency ? Colors.white : color,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 7. Smart Suggestions ---
  Widget _buildSmartSuggestions(ThemeData theme, Color primary) {
    String suggestion = "Keep up the good work! You are doing great today.";
    
    final totalTasks = _dailyTasks.length;
    final pendingTasks = _dailyTasks.where((t) => t['completed'] != true).length;

    if (totalTasks == 0) {
      suggestion = "Set up today's plan to start receiving reminders and tracking your progress.";
    } else if (!_hasJournalToday) {
      suggestion = "You haven't written in your journal today. Capturing your thoughts can help improve your mood!";
    } else if (pendingTasks > 0) {
      suggestion = "You still have $pendingTasks tasks remaining in your routine. You can do it!";
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: primary, size: 20),
              const SizedBox(width: 10),
              Text('Smart Suggestion', style: TextStyle(color: primary, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '\"$suggestion\"',
            style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black87, fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }

  // --- Helper Components ---

  Widget _buildEmptyState(String msg, String sub, IconData icon, {required VoidCallback onTap, required String btnLabel, required Color primary}) {
    return Column(
      children: [
        Icon(icon, color: Colors.black12, size: 48),
        const SizedBox(height: 12),
        Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        Text(sub, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(btnLabel),
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            side: BorderSide(color: primary.withOpacity(0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title, Color primary) {
    return Row(
      children: [
        Container(width: 4, height: 20, decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 12),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: Colors.black87, letterSpacing: 0.5),
        ),
      ],
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required Color primaryColor, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryColor, size: 20),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    int index, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return _FeatureCard(title: title, subtitle: subtitle, icon: icon, color: color, onTap: onTap);
  }

  String _getMonth(int m) {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return months[m - 1];
  }
}

class _FeatureCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _FeatureCard({required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

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
          shadowColor: widget.color.withOpacity(0.1),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(24),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.all(isDesktop ? 24 : 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _isHovered ? widget.color.withOpacity(0.3) : Colors.black.withOpacity(0.04)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: widget.color.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
                    child: Icon(widget.icon, color: widget.color, size: 32),
                  ),
                  const Spacer(),
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                      fontSize: isDesktop ? 22 : 19,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
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
