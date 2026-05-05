import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../services/risk_api.dart';

class ElderRiskFormScreen extends StatefulWidget {
  static const routeName = '/elder-risk-form';

  final AppUser currentUser;

  const ElderRiskFormScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<ElderRiskFormScreen> createState() =>
      _ElderRiskFormScreenState();
}

class _ElderRiskFormScreenState extends State<ElderRiskFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _age = TextEditingController();
  final _sleepHours = TextEditingController();
  final _physicalActivity = TextEditingController();
  final _socialSupport = TextEditingController();
  final _anxietyScore = TextEditingController();
  final _depressionScore = TextEditingController();
  final _stressLevel = TextEditingController();
  final _selfEsteem = TextEditingController();
  final _lifeSatisfaction = TextEditingController();
  final _loneliness = TextEditingController();

  String? gender;
  String? education;

  // backend required
  String? medicationUse = "No";
  String? substanceUse = "No";
  String? familyHistory = "No";
  String? chronicIllnesses = "No";
  String? therapy = "No";
  String? meditation = "No";
  String? financialStress = "Low";
  String? workStress = "Low";

  bool _loading = false;
  String? _error;

  int _toInt(TextEditingController c) =>
      int.tryParse(c.text.trim()) ?? 0;

  @override
  void initState() {
    super.initState();

    _age.text = (widget.currentUser.age ?? 60).toString();
    gender = widget.currentUser.gender ?? "Female";
    education = widget.currentUser.education ?? "Undergraduate";
  }

  @override
  void dispose() {
    _age.dispose();
    _sleepHours.dispose();
    _physicalActivity.dispose();
    _socialSupport.dispose();
    _anxietyScore.dispose();
    _depressionScore.dispose();
    _stressLevel.dispose();
    _selfEsteem.dispose();
    _lifeSatisfaction.dispose();
    _loneliness.dispose();
    super.dispose();
  }

  // ✅ VALIDATION
  String? _validateScore(String? v) {
    if (v == null || v.trim().isEmpty) return "Required";

    final value = int.tryParse(v);
    if (value == null) return "Enter number";

    if (value < 1 || value > 10) {
      return "Enter value between 1–10";
    }

    return null;
  }

  Widget _lockedField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey.shade200,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _numField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        validator: _validateScore,
      ),
    );
  }

  // ✅ UPDATED SUBMIT (NO RESULT SCREEN)
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final features = {
        "Gender": gender,
        "Education_Level": education,
        "Medication_Use": medicationUse,
        "Substance_Use": substanceUse,
        "Age": _toInt(_age),
        "Sleep_Hours": _toInt(_sleepHours),
        "Physical_Activity_Hrs": _toInt(_physicalActivity),
        "Social_Support_Score": _toInt(_socialSupport),
        "Anxiety_Score": _toInt(_anxietyScore),
        "Depression_Score": _toInt(_depressionScore),
        "Stress_Level": _toInt(_stressLevel),
        "Family_History_Mental_Illness": familyHistory,
        "Chronic_Illnesses": chronicIllnesses,
        "Therapy": therapy,
        "Meditation": meditation,
        "Financial_Stress": financialStress,
        "Work_Stress": workStress,
        "Self_Esteem_Score": _toInt(_selfEsteem),
        "Life_Satisfaction_Score": _toInt(_lifeSatisfaction),
        "Loneliness_Score": _toInt(_loneliness),
      };

      await RiskApi.predictRisk(
        residentId: widget.currentUser.uid,
        features: features,
      );

      if (!mounted) return;

      setState(() => _loading = false);

      // ✅ SUCCESS MESSAGE (NO RESULTS SHOWN)
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text("Submitted Successfully"),
          content: const Text(
            "Your answers have been submitted.\n\nA therapist will review your assessment soon.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 20),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget sectionCard(List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: children),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mental Health Assessment"),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              sectionTitle("Personal Information"),
              sectionCard([
                _lockedField("Name", widget.currentUser.name ?? "User"),
                _lockedField("Gender", gender ?? ""),
                _lockedField("Education", education ?? ""),
                _lockedField("Age", _age.text),
              ]),

              sectionTitle("Health & Lifestyle"),
              sectionCard([
                _numField(
                  "How well did you sleep this week? (1 = very poor, 10 = excellent)",
                  _sleepHours,
                ),
                _numField(
                  "How physically active were you this week? (1–10)",
                  _physicalActivity,
                ),
                _numField(
                  "How supported do you feel by family or friends? (1–10)",
                  _socialSupport,
                ),
              ]),

              sectionTitle("Mental Health"),
              sectionCard([
                _numField(
                  "How often did you feel worried this week? (1 = Not at all, 10 = Very often)",
                  _anxietyScore,
                ),
                _numField(
                  "How often did you feel down or unhappy? (1 = Not at all, 10 = Very often)",
                  _depressionScore,
                ),
                _numField(
                  "How often did you feel under pressure? (1 = Not at all, 10 = Very often)",
                  _stressLevel,
                ),
              ]),

              sectionTitle("Well-being"),
              sectionCard([
                _numField(
                  "How confident do you feel about yourself? (1–10)",
                  _selfEsteem,
                ),
                _numField(
                  "How satisfied are you with your life? (1–10)",
                  _lifeSatisfaction,
                ),
                _numField(
                  "How lonely did you feel this week? (1–10)",
                  _loneliness,
                ),
              ]),

              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),

              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: Text(_loading ? "Submitting..." : "Submit Assessment"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}