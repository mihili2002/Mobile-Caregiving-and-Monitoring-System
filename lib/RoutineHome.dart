import 'package:flutter/material.dart';
import '../../models/user_model.dart';
//import '../login_page.dart';
import './auth/login_page.dart';
import './auth/auth_service.dart';

// Widgets
//import 'widgets/dashboard_header.dart';
import './pages/elder/widgets/appointments_card.dart';
import './pages/elder/widgets/digital_clock_widget.dart';
import './pages/elder/widgets/time_reminders_widget.dart';
import './pages/elder/widgets/quick_stats_widget.dart';
import './pages/elder/widgets/daily_tasks_card.dart';
import './pages/elder/widgets/medications_card.dart';
import './pages/elder/widgets/weather_widget.dart';
import './pages/elder/widgets/family_photos_widget.dart';
import './pages/elder/widgets/emergency_footer.dart';
import './pages/elder/widgets/dashboard_header.dart';
//import 'daily_routine_page.dart'; 
import './pages/elder/daily_routine_page.dart';
import './pages/elder/voice_chatbot_page.dart';
import 'services/voice_reminder_service.dart';

class RoleProfilePage extends StatefulWidget {
  final AppUser user;

  const RoleProfilePage({super.key, required this.user});

  @override
  State<RoleProfilePage> createState() => _RoleProfilePageState();
}

class _RoleProfilePageState extends State<RoleProfilePage> {
  final AuthService _authService = AuthService();
  final VoiceReminderService _reminderService = VoiceReminderService();

  @override
  void initState() {
    super.initState();
    debugPrint("DEBUG: RoutineHome initState called for ${widget.user.uid}");
    _reminderService.start(widget.user.uid);
    _reminderService.listen(widget.user.uid);
  }

    void _logout() async {
    await _authService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header with Greeting
             // DashboardHeader(user: widget.user),
              const SizedBox(height: 24),

              // 2. Big Digital Clock (Centerpiece)
              const Center(child: DigitalClockWidget()),
              const SizedBox(height: 32),

              // 3. "My Schedule" - The most important action
          _buildBigNavCard(
  context,
  title: "My Daily Schedule",
  subtitle: "View your tasks and medications",
  icon: Icons.calendar_today,
  color: Colors.teal,
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
const SizedBox(height: 16),

              // 4. "Voice Companion" - AI Helper
              _buildBigNavCard(
                context,
                title: "Voice Companion",
                subtitle: "Talk to your assistant",
                icon: Icons.mic,
                color: Colors.blueAccent,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VoiceChatbotPage(user: widget.user))),
              ),
              const SizedBox(height: 16),

              // 5. Weather & Quick Stats Row
              Row(
                children: [
                  Expanded(child: WeatherWidget()),
                ],
              ),
              const SizedBox(height: 24),

              // 6. Quick Contacts
              const FamilyPhotosWidget(),
              const SizedBox(height: 32),

              // 7. Emergency
              EmergencyFooter(
                emergencyContactName: "John (Son)",
                emergencyContactNumber: "911", 
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VoiceChatbotPage(user: widget.user))),
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.mic, color: Colors.white, size: 30),
      ),
    );
  }

  Widget _buildBigNavCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Card(
      elevation: 4,
      shadowColor: color.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: color),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700])),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}