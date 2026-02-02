import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/user_service.dart';
import '../../services/elder_profile_service.dart';
import '../../models/user_model.dart';
import '../../widgets/role_based_wrapper.dart';

class ElderOnboardingFlow extends StatefulWidget {
  final AppUser? user;
  
  const ElderOnboardingFlow({super.key, this.user});

  @override
  State<ElderOnboardingFlow> createState() => _ElderOnboardingFlowState();
}

class _ElderOnboardingFlowState extends State<ElderOnboardingFlow> {
  final PageController _controller = PageController();
  final UserService _userService = UserService();
  
  bool _isLoading = false;
  int _currentPage = 0;
  final int _totalPages = 5;

  // --- STATE VARIABLES (16 Features) ---
  
  // 1. Demographics / Bio
  double _age = 65;
  String _longTermIllness = "No"; // Yes/No
  
  // 2. Physical
  double _sleepWell = 3;      // 1-5
  double _tiredDay = 3;       // 1-5
  
  // 3. Cognitive
  double _forgetRecent = 3;   // 1-5
  double _diffTasks = 3;      // 1-5
  double _forgetMeds = 3;     // 1-5
  double _tasksHarder = 3;    // 1-5
  
  // 4. Emotional / Social
  double _lonely = 3;         // 1-5
  double _sadAnxious = 3;     // 1-5
  double _socialTalk = 3;     // 1-5
  double _enjoyHobbies = 3;   // 1-5
  
  // 5. App Preferences
  double _comfyApp = 3;       // 1-5
  double _remindHelpful = 3;  // 1-5
  double _remindTime = 3;     // 1-5
  String _remindPref = "Gentle Voice"; // Options

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300), 
        curve: Curves.easeInOut
      );
      setState(() => _currentPage++);
    } else {
      _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    
    if (user != null) {
      Map<String, dynamic> profileData = {
        'uid': user.uid,
        'name': widget.user?.name ?? user.displayName, 
        
        // 16 Features
        'age': _age.toInt(),
        'long_term_illness': _longTermIllness,
        
        'sleep_well_1to5': _sleepWell.toInt(),
        'tired_day_1to5': _tiredDay.toInt(),
        
        'forget_recent_1to5': _forgetRecent.toInt(),
        'difficulty_remember_tasks_1to5': _diffTasks.toInt(),
        'forget_take_meds_1to5': _forgetMeds.toInt(),
        'tasks_harder_1to5': _tasksHarder.toInt(),
        
        'lonely_1to5': _lonely.toInt(),
        'sad_anxious_1to5': _sadAnxious.toInt(),
        'social_talk_1to5': _socialTalk.toInt(),
        'enjoy_hobbies_1to5': _enjoyHobbies.toInt(),
        
        'comfortable_app_1to5': _comfyApp.toInt(),
        'reminders_helpful_1to5': _remindHelpful.toInt(),
        'reminders_right_time_1to5': _remindTime.toInt(),
        'reminders_preference': _remindPref,
        
        'completed_at': DateTime.now().toIso8601String(),
      };

      final response = await _userService.createElderProfile(profileData);

      if (response != null && mounted) {
        // Mark as complete locally/in Firestore
        await ElderProfileService().completeOnboarding(user.uid);

        // Cache Predictions Locally
        try {
           final profile = response['profile'];
           if (profile != null) {
              final prefs = await SharedPreferences.getInstance();
              if (profile['prediction_tier'] != null) {
                 await prefs.setString('cached_risk_tier', profile['prediction_tier']);
              }
              if (profile['prediction_probability'] != null) {
                 // Ensure double
                 double prob = 0.0;
                 if (profile['prediction_probability'] is int) prob = (profile['prediction_probability'] as int).toDouble();
                 else if (profile['prediction_probability'] is double) prob = profile['prediction_probability'];
                 
                 await prefs.setDouble('cached_risk_prob', prob);
              }
           }
        } catch(e) {
           print("Error caching predictions: $e");
        }

        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (_) => const RoleBasedWrapper())
        );
      } else {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("Failed to save profile. Please try again."))
           );
        }
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Step ${_currentPage+1} of $_totalPages")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildPage1_Bio(),
                  _buildPage2_Physical(),
                  _buildPage3_Cognitive(),
                  _buildPage4_Social(),
                  _buildPage5_Preferences(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                  child: Text(_currentPage == _totalPages - 1 ? "Finish Setup" : "Next"),
                ),
              ),
            )
          ],
        ),
    );
  }

  // --- PAGES ---

  Widget _buildPage1_Bio() {
    return _buildPageContainer(
      title: "About You",
      children: [
        _buildSliderQuestion("What is your age?", _age, 50, 100, (v) => setState(() => _age = v)),
        Text("${_age.toInt()} Years Old", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        const SizedBox(height: 30),
        const Text("Do you have any long-term illnesses?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          segments: const [
             ButtonSegment(value: "Yes", label: Text("Yes")),
             ButtonSegment(value: "No", label: Text("No")),
          ],
          selected: {_longTermIllness},
          onSelectionChanged: (Set<String> newSelection) {
            setState(() => _longTermIllness = newSelection.first);
          },
        )
      ]
    );
  }
  
  Widget _buildPage2_Physical() {
    return _buildPageContainer(
      title: "Physical Well-being",
      children: [
        _buildLikertQuestion("I sleep well at night", _sleepWell, (v) => setState(() => _sleepWell = v)),
        _buildLikertQuestion("I often feel tired during the day", _tiredDay, (v) => setState(() => _tiredDay = v)),
      ]
    );
  }

  Widget _buildPage3_Cognitive() {
    return _buildPageContainer(
      title: "Memory & Focus",
      children: [
        _buildLikertQuestion("I often forget recent events", _forgetRecent, (v) => setState(() => _forgetRecent = v)),
        _buildLikertQuestion("I have difficulty remembering tasks", _diffTasks, (v) => setState(() => _diffTasks = v)),
        _buildLikertQuestion("I forget to take medications", _forgetMeds, (v) => setState(() => _forgetMeds = v)),
        _buildLikertQuestion("Daily tasks feel harder than before", _tasksHarder, (v) => setState(() => _tasksHarder = v)),
      ]
    );
  }

  Widget _buildPage4_Social() {
    return _buildPageContainer(
      title: "Social & Emotional",
      children: [
        _buildLikertQuestion("I often feel lonely", _lonely, (v) => setState(() => _lonely = v)),
        _buildLikertQuestion("I feel sad or anxious", _sadAnxious, (v) => setState(() => _sadAnxious = v)),
        _buildLikertQuestion("I talk to friends/family regularly", _socialTalk, (v) => setState(() => _socialTalk = v)),
        _buildLikertQuestion("I enjoy my hobbies", _enjoyHobbies, (v) => setState(() => _enjoyHobbies = v)),
      ]
    );
  }
  
  Widget _buildPage5_Preferences() {
    return _buildPageContainer(
      title: "App Preferences",
      children: [
        _buildLikertQuestion("I am comfortable using apps", _comfyApp, (v) => setState(() => _comfyApp = v)),
        _buildLikertQuestion("Reminders are helpful to me", _remindHelpful, (v) => setState(() => _remindHelpful = v)),
        _buildLikertQuestion("Reminders come at the right time", _remindTime, (v) => setState(() => _remindTime = v)),
        const SizedBox(height: 20),
        const Text("Preferred Reminder Style", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        DropdownButton<String>(
          isExpanded: true,
          value: _remindPref,
          items: ["Gentle Voice", "Loud Alarm", "Text Only", "Phone Call"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => _remindPref = v!),
        )
      ]
    );
  }

  // --- HELPERS ---

  Widget _buildPageContainer({required String title, required List<Widget> children}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal)),
          const SizedBox(height: 30),
          ...children
        ],
      )
    );
  }

  Widget _buildSliderQuestion(String question, double val, double min, double max, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        Slider(value: val, min: min, max: max, divisions: (max-min).toInt(), onChanged: onChanged),
      ],
    );
  }

  Widget _buildLikertQuestion(String statement, double val, Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(statement, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text("Disagree", style: TextStyle(fontSize: 12, color: Colors.grey)),
              Expanded(
                child: Slider(
                  value: val, 
                  min: 1, 
                  max: 5, 
                  divisions: 4, 
                  label: val.toInt().toString(),
                  activeColor: Colors.teal,
                  onChanged: onChanged
                ),
              ),
              const Text("Agree", style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          )
        ],
      ),
    );
  }
}