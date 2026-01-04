import 'package:flutter/material.dart';
import 'services/risk_api.dart';
import 'RiskResultScreen.dart';

class TherapistRiskFormScreen extends StatefulWidget {
  static const routeName = '/therapist-risk-form';

  const TherapistRiskFormScreen({super.key});

  @override
  State<TherapistRiskFormScreen> createState() => _TherapistRiskFormScreenState();
}

class _TherapistRiskFormScreenState extends State<TherapistRiskFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text fields
  final _residentId = TextEditingController(text: "resident_001");
  final _age = TextEditingController(text: "45");
  final _sleepHours = TextEditingController(text: "5");
  final _physicalActivity = TextEditingController(text: "1");
  final _socialSupport = TextEditingController(text: "4");
  final _anxietyScore = TextEditingController(text: "7");
  final _depressionScore = TextEditingController(text: "8");
  final _stressLevel = TextEditingController(text: "6");
  final _selfEsteem = TextEditingController(text: "5");
  final _lifeSatisfaction = TextEditingController(text: "5");
  final _loneliness = TextEditingController(text: "7");

  // Dropdowns
  String gender = "Male";
  String education = "Undergraduate";
  String medicationUse = "Yes";
  String substanceUse = "Occasional";

  String familyHistory = "No";
  String chronicIllnesses = "Yes";
  String therapy = "No";
  String meditation = "No";

  String financialStress = "Medium";
  String workStress = "Low";

  bool _loading = false;
  String? _error;

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

  int _toInt(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  Widget _drop({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: (v) => onChanged(v ?? value),
      validator: (v) => (v == null || v.trim().isEmpty) ? "Required" : null,
    );
  }

  Widget _numField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return "Required";
        if (num.tryParse(v.trim()) == null) return "Enter a number";
        return null;
      },
    );
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      if (!_formKey.currentState!.validate()) {
        setState(() => _loading = false);
        return;
      }

      final features = <String, dynamic>{
        // categorical (OneHotEncoder)
        "Gender": gender,
        "Education_Level": education,
        "Medication_Use": medicationUse,
        "Substance_Use": substanceUse,

        // numeric
        "Age": _toInt(_age),
        "Sleep_Hours": _toInt(_sleepHours),
        "Physical_Activity_Hrs": _toInt(_physicalActivity),
        "Social_Support_Score": _toInt(_socialSupport),
        "Anxiety_Score": _toInt(_anxietyScore),
        "Depression_Score": _toInt(_depressionScore),
        "Stress_Level": _toInt(_stressLevel),

        // These are numeric in your pipeline; backend maps Yes/No -> 1/0
        "Family_History_Mental_Illness": familyHistory,
        "Chronic_Illnesses": chronicIllnesses,
        "Therapy": therapy,
        "Meditation": meditation,

        // Backend maps Low/Medium/High -> 0/1/2
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

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RiskResultScreen(result: result),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Therapist Assessment Form")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _residentId,
                  decoration: const InputDecoration(
                    labelText: "Resident ID",
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? "Required" : null,
                ),
                const SizedBox(height: 12),

                // Categorical section
                _drop(
                  label: "Gender",
                  value: gender,
                  items: const ["Male", "Female"],
                  onChanged: (v) => setState(() => gender = v),
                ),
                const SizedBox(height: 12),
                _drop(
                  label: "Education Level",
                  value: education,
                  items: const ["High School", "Undergraduate", "Postgraduate"],
                  onChanged: (v) => setState(() => education = v),
                ),
                const SizedBox(height: 12),
                _drop(
                  label: "Medication Use",
                  value: medicationUse,
                  items: const ["Yes", "No"],
                  onChanged: (v) => setState(() => medicationUse = v),
                ),
                const SizedBox(height: 12),
                _drop(
                  label: "Substance Use",
                  value: substanceUse,
                  items: const ["Never", "Occasional", "Frequent"],
                  onChanged: (v) => setState(() => substanceUse = v),
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

                // Numeric section
                _numField("Age", _age),
                const SizedBox(height: 12),
                _numField("Sleep Hours", _sleepHours),
                const SizedBox(height: 12),
                _numField("Physical Activity Hours", _physicalActivity),
                const SizedBox(height: 12),
                _numField("Social Support Score", _socialSupport),
                const SizedBox(height: 12),
                _numField("Anxiety Score", _anxietyScore),
                const SizedBox(height: 12),
                _numField("Depression Score", _depressionScore),
                const SizedBox(height: 12),
                _numField("Stress Level", _stressLevel),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

                // Yes/No section
                _drop(
                  label: "Family History (Mental Illness)",
                  value: familyHistory,
                  items: const ["Yes", "No"],
                  onChanged: (v) => setState(() => familyHistory = v),
                ),
                const SizedBox(height: 12),
                _drop(
                  label: "Chronic Illnesses",
                  value: chronicIllnesses,
                  items: const ["Yes", "No"],
                  onChanged: (v) => setState(() => chronicIllnesses = v),
                ),
                const SizedBox(height: 12),
                _drop(
                  label: "Therapy",
                  value: therapy,
                  items: const ["Yes", "No"],
                  onChanged: (v) => setState(() => therapy = v),
                ),
                const SizedBox(height: 12),
                _drop(
                  label: "Meditation",
                  value: meditation,
                  items: const ["Yes", "No"],
                  onChanged: (v) => setState(() => meditation = v),
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

                // Stress + self scores
                _drop(
                  label: "Financial Stress",
                  value: financialStress,
                  items: const ["Low", "Medium", "High"],
                  onChanged: (v) => setState(() => financialStress = v),
                ),
                const SizedBox(height: 12),
                _drop(
                  label: "Work Stress",
                  value: workStress,
                  items: const ["Low", "Medium", "High"],
                  onChanged: (v) => setState(() => workStress = v),
                ),
                const SizedBox(height: 12),
                _numField("Self Esteem Score", _selfEsteem),
                const SizedBox(height: 12),
                _numField("Life Satisfaction Score", _lifeSatisfaction),
                const SizedBox(height: 12),
                _numField("Loneliness Score", _loneliness),

                const SizedBox(height: 16),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),

                ElevatedButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.analytics),
                  label: Text(_loading ? "Predicting..." : "Predict Risk"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
