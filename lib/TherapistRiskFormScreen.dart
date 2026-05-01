import 'package:flutter/material.dart';
import 'services/risk_api.dart';
import 'RiskResultScreen.dart';
import 'auth/auth_service.dart';
import 'auth/login_page.dart';

class TherapistRiskFormScreen extends StatefulWidget {
  static const routeName = '/therapist-risk-form';

  const TherapistRiskFormScreen({super.key});

  @override
  State<TherapistRiskFormScreen> createState() =>
      _TherapistRiskFormScreenState();
}

class _TherapistRiskFormScreenState extends State<TherapistRiskFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _residentId = TextEditingController();
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
  String? medicationUse;
  String? substanceUse;

  String? familyHistory;
  String? chronicIllnesses;
  String? therapy;
  String? meditation;

  String? financialStress;
  String? workStress;

  bool _loading = false;
  String? _error;

  int _toInt(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  @override
  void dispose() {
    _residentId.dispose();
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

  Widget sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 20),
      child: Row(
        children: [
          Icon(icon, color: Colors.teal),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return "Required";
          if (num.tryParse(v.trim()) == null) return "Enter number";
          return null;
        },
      ),
    );
  }

  Widget _drop({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
        validator: (v) => v == null ? "Required" : null,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final features = <String, dynamic>{
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

      final result = await RiskApi.predictRisk(
        residentId: _residentId.text.trim(),
        features: features,
      );

      if (!mounted) return;

      setState(() => _loading = false);

      final navResult = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RiskResultScreen(result: result),
        ),
      );

      if (navResult == 'approved' && mounted) {
        Navigator.pop(context, 'approved');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Widget sectionCard(List<Widget> children) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: children),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3FF),
      body: SafeArea(
        child: Column(
          children: [
            // ---------------- HEADER ----------------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 18, 12, 18),
              decoration: const BoxDecoration(
                color: Color(0xFF11BFA8),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(22),
                  bottomRight: Radius.circular(22),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "ElderCare",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Mental Health Assessment",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: "Logout",
                    onPressed: () async {
                      await AuthService().signOut();
                      if (mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                          (route) => false,
                        );
                      }
                    },
                    icon: const Icon(Icons.logout, color: Colors.white),
                  ),
                ],
              ),
            ),

            // ---------------- BODY ----------------
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      sectionTitle("Resident Information", Icons.person),
                      sectionCard([
                        TextFormField(
                          controller: _residentId,
                          decoration: const InputDecoration(
                            labelText: "Resident ID",
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? "Required" : null,
                        ),
                      ]),
                      sectionTitle("Basic Information", Icons.info),
                      sectionCard([
                        _drop(
                          label: "Gender",
                          value: gender,
                          items: const ["Male", "Female"],
                          onChanged: (v) => setState(() => gender = v),
                        ),
                        _drop(
                          label: "Education Level",
                          value: education,
                          items: const [
                            "High School",
                            "Undergraduate",
                            "Postgraduate",
                          ],
                          onChanged: (v) => setState(() => education = v),
                        ),
                      ]),
                      sectionTitle("Health & Lifestyle", Icons.favorite),
                      sectionCard([
                        _numField("Age", _age),
                        _numField("Sleep Hours", _sleepHours),
                        _numField("Physical Activity Hours", _physicalActivity),
                        _numField("Social Support Score", _socialSupport),
                      ]),
                      sectionTitle("Mental Health Scores", Icons.psychology),
                      sectionCard([
                        _numField("Anxiety Score", _anxietyScore),
                        _numField("Depression Score", _depressionScore),
                        _numField("Stress Level", _stressLevel),
                      ]),
                      sectionTitle("Medical History", Icons.medical_services),
                      sectionCard([
                        _drop(
                          label: "Family History (Mental Illness)",
                          value: familyHistory,
                          items: const ["Yes", "No"],
                          onChanged: (v) => setState(() => familyHistory = v),
                        ),
                        _drop(
                          label: "Chronic Illnesses",
                          value: chronicIllnesses,
                          items: const ["Yes", "No"],
                          onChanged: (v) => setState(() => chronicIllnesses = v),
                        ),
                        _drop(
                          label: "Therapy",
                          value: therapy,
                          items: const ["Yes", "No"],
                          onChanged: (v) => setState(() => therapy = v),
                        ),
                        _drop(
                          label: "Meditation",
                          value: meditation,
                          items: const ["Yes", "No"],
                          onChanged: (v) => setState(() => meditation = v),
                        ),
                      ]),
                      sectionTitle("Psychological Indicators", Icons.bar_chart),
                      sectionCard([
                        _drop(
                          label: "Financial Stress",
                          value: financialStress,
                          items: const ["Low", "Medium", "High"],
                          onChanged: (v) =>
                              setState(() => financialStress = v),
                        ),
                        _drop(
                          label: "Work Stress",
                          value: workStress,
                          items: const ["Low", "Medium", "High"],
                          onChanged: (v) => setState(() => workStress = v),
                        ),
                        _numField("Self Esteem Score", _selfEsteem),
                        _numField("Life Satisfaction Score", _lifeSatisfaction),
                        _numField("Loneliness Score", _loneliness),
                      ]),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _loading ? null : _submit,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.analytics),
                        label: Text(
                          _loading ? "Predicting..." : "Predict Risk",
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}