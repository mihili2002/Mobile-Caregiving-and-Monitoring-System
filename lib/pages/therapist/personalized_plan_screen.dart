import 'dart:math';
import 'package:flutter/material.dart';

enum PlanMode {
  viewOnly,
  generateEditable,
}

class PersonalizedPlanScreen extends StatefulWidget {
  final String residentId;
  final PlanMode mode;

  const PersonalizedPlanScreen({
    super.key,
    required this.residentId,
    required this.mode,
  });

  @override
  State<PersonalizedPlanScreen> createState() => _PersonalizedPlanScreenState();
}

class _PersonalizedPlanScreenState extends State<PersonalizedPlanScreen> {
  bool _editing = false;

  late final TextEditingController _depressionCtrl;
  late final TextEditingController _anxietyCtrl;
  late final TextEditingController _insomniaCtrl;
  late final TextEditingController _emotionalCtrl;

  @override
  void initState() {
    super.initState();

    final randomPlan = _generateRandomPlan();

    _editing = widget.mode == PlanMode.generateEditable;

    _depressionCtrl = TextEditingController(text: randomPlan["Depression"]);
    _anxietyCtrl = TextEditingController(text: randomPlan["Anxiety"]);
    _insomniaCtrl = TextEditingController(text: randomPlan["Insomnia"]);
    _emotionalCtrl = TextEditingController(text: randomPlan["Emotional"]);
  }

  @override
  void dispose() {
    _depressionCtrl.dispose();
    _anxietyCtrl.dispose();
    _insomniaCtrl.dispose();
    _emotionalCtrl.dispose();
    super.dispose();
  }

  Map<String, String> _generateRandomPlan() {
    final r = Random();

    const depressionOptions = [
      "Daily 20–30 min walk + morning sunlight exposure.\nPractice gratitude journaling (3 lines/day).\nWeekly check-in with caregiver or friend.",
      "Structured routine: wake/sleep fixed times.\nAdd 1 enjoyable activity daily.\nLimit isolation: join a small social activity twice/week.",
      "Breathing + mindfulness 10 minutes/day.\nSet small goals and celebrate progress.\nReduce caffeine and maintain hydration.",
    ];

    const anxietyOptions = [
      "4-7-8 breathing when anxious.\nAvoid too much news/social media.\nTry grounding: 5-4-3-2-1 technique.",
      "Schedule “worry time” 15 min/day.\nProgressive muscle relaxation 10 min/day.\nReduce caffeine.",
      "Light exercise 4x/week.\nSleep hygiene.\nTalk therapy session once/week .",
    ];

    const insomniaOptions = [
      "No screens 60 mins before bed.\nKeep room dark/cool.\nAvoid naps after 3pm.",
      "Fixed bedtime/wake time.\nWarm shower + light stretching.\nAvoid heavy meals late night.",
      "Limit caffeine after 2pm.\nRelaxation audio.\nWrite down worries before sleep.",
    ];

    const emotionalOptions = [
      "Daily mood tracking.\nSpend 20 min with a hobby.\nWeekly social interaction goal.",
      "Meditation 10 mins/day.\nShort nature walk.\nPositive self-talk practice.",
      "Music therapy + journaling.\nReduce alcohol/smoking.\nSet 1 meaningful weekly goal.",
    ];

    return {
      "Depression": depressionOptions[r.nextInt(depressionOptions.length)],
      "Anxiety": anxietyOptions[r.nextInt(anxietyOptions.length)],
      "Insomnia": insomniaOptions[r.nextInt(insomniaOptions.length)],
      "Emotional": emotionalOptions[r.nextInt(emotionalOptions.length)],
    };
  }

  Widget _section(String title, TextEditingController ctrl) {
    final enabled = _editing;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              maxLines: 6,
              enabled: enabled,
              decoration: InputDecoration(
                hintText: "Enter plan for $title",
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: enabled ? Colors.white : Colors.grey.withOpacity(0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _approve() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ Plan approved successfully ")),
    );
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.mode == PlanMode.generateEditable;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Personalized Plan"),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Text(
                "Resident: ${widget.residentId}",
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                canEdit
                    ? " You can edit and approve."
                    : "",
                style: TextStyle(color: Colors.black.withOpacity(0.6)),
              ),
              const SizedBox(height: 14),

              _section("Depression Prevention Plan", _depressionCtrl),
              _section("Anxiety Prevention Plan", _anxietyCtrl),
              _section("Insomnia Prevention Plan", _insomniaCtrl),
              _section("Emotional Wellbeing Plan", _emotionalCtrl),

              const SizedBox(height: 12),

              if (canEdit)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _editing = !_editing),
                        icon: Icon(_editing ? Icons.lock : Icons.edit),
                        label: Text(_editing ? "Stop Editing" : "Edit"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _approve,
                        icon: const Icon(Icons.check_circle),
                        label: const Text("Approve"),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
