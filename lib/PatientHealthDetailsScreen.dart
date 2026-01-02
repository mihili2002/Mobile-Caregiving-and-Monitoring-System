import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'widgets/role_based_wrapper.dart';
import 'services/elder_health_submission_service.dart';

enum Gender { male, female }

class PatientHealthDetailsScreen extends StatefulWidget {
  const PatientHealthDetailsScreen({Key? key}) : super(key: key);

  @override
  State<PatientHealthDetailsScreen> createState() =>
      _PatientHealthDetailsScreenState();
}

class _PatientHealthDetailsScreenState extends State<PatientHealthDetailsScreen> {
  // Controllers
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _systolicController = TextEditingController();
  final TextEditingController _diastolicController = TextEditingController();
  final TextEditingController _bloodSugarController = TextEditingController();
  final TextEditingController _cholesterolController = TextEditingController();
  final TextEditingController _dailyStepsController = TextEditingController();
  final TextEditingController _sleepHoursController = TextEditingController();
  final TextEditingController _foodAllergiesController = TextEditingController();
  final TextEditingController _foodAversionsController = TextEditingController();

  Gender? _gender;
  final List<String> _chronicConditions = [];
  bool _geneticRisk = false;

  String? _exerciseFrequency; // Low, Moderate, High
  bool _smoking = false;
  bool _alcohol = false;

  String? _dietaryHabit;
  String? _preferredCuisine;

  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();
  final ElderHealthSubmissionService _submissionService =
      ElderHealthSubmissionService();

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _bloodSugarController.dispose();
    _cholesterolController.dispose();
    _dailyStepsController.dispose();
    _sleepHoursController.dispose();
    _foodAllergiesController.dispose();
    _foodAversionsController.dispose();
    super.dispose();
  }

  String? _requiredNumberValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    if (double.tryParse(value) == null) return 'Enter a valid number';
    return null;
  }

  void _clearForm() {
    _formKey.currentState?.reset();

    _ageController.clear();
    _heightController.clear();
    _weightController.clear();
    _systolicController.clear();
    _diastolicController.clear();
    _bloodSugarController.clear();
    _cholesterolController.clear();
    _dailyStepsController.clear();
    _sleepHoursController.clear();
    _foodAllergiesController.clear();
    _foodAversionsController.clear();

    setState(() {
      _gender = null;
      _chronicConditions.clear();
      _geneticRisk = false;
      _exerciseFrequency = null;
      _smoking = false;
      _alcohol = false;
      _dietaryHabit = null;
      _preferredCuisine = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix validation errors')),
      );
      return;
    }
    if (_gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select gender')),
      );
      return;
    }
    if (_dietaryHabit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select dietary habit')),
      );
      return;
    }
    if (_preferredCuisine == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select preferred cuisine')),
      );
      return;
    }
    if (_exerciseFrequency == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select exercise frequency')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception("User not logged in.");
      }

      // ✅ FIX: token is nullable, must validate it
      final token = await currentUser.getIdToken();
      if (token == null || token.isEmpty) {
        throw Exception("Failed to get Firebase token. Please login again.");
      }

      final payload = {
        "age": int.parse(_ageController.text.trim()),
        "gender": _gender == Gender.male ? "Male" : "Female",
        "height_cm": double.parse(_heightController.text.trim()),
        "weight_kg": double.parse(_weightController.text.trim()),
        "chronic_conditions": _chronicConditions,
        "genetic_risk": _geneticRisk,
        "blood_pressure": {
          "systolic": int.parse(_systolicController.text.trim()),
          "diastolic": int.parse(_diastolicController.text.trim()),
        },
        "blood_sugar_mg_dl": double.parse(_bloodSugarController.text.trim()),
        "cholesterol_mg_dl": double.parse(_cholesterolController.text.trim()),
        "daily_steps": int.parse(_dailyStepsController.text.trim()),
        "exercise_frequency": _exerciseFrequency == "Low"
            ? 1
            : _exerciseFrequency == "Moderate"
                ? 2
                : 3,
        "sleep_hours": double.parse(_sleepHoursController.text.trim()),
        "smoking": _smoking,
        "alcohol": _alcohol,
        "dietary_habit": _dietaryHabit,
        "food_allergies": _foodAllergiesController.text.trim().isEmpty
            ? null
            : _foodAllergiesController.text.trim(),
        "preferred_cuisine": _preferredCuisine,
        "food_aversions": _foodAversionsController.text.trim().isEmpty
            ? null
            : _foodAversionsController.text.trim(),
        "extra": {"notes": "Submitted from mobile app"}
      };

      await _submissionService.submitHealthDetails(
        token: token,
        payload: payload,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Health details submitted successfully ✅")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RoleBasedWrapper()),
      );
    } catch (e) {
      debugPrint("❌ Submission error: $e");

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error submitting details: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _sectionCard({required Widget child}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Upload Health Details"),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _basicInfoCard(),
                  _healthConditionsCard(),
                  _lifestyleCard(),
                  _dietaryCard(),

                  const SizedBox(height: 14),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Submit Details to Doctor",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),

                  OutlinedButton(
                    onPressed: _isLoading ? null : _clearForm,
                    child: const Text("Clear Form"),
                  ),
                ],
              ),
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.25),
              child: const Center(child: CircularProgressIndicator()),
            )
        ],
      ),
    );
  }

  // ---------------- SECTIONS ----------------
  Widget _basicInfoCard() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Basic Information",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Age"),
            validator: _requiredNumberValidator,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _gender = Gender.male),
                  child: const Text("Male"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _gender = Gender.female),
                  child: const Text("Female"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _heightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Height (cm)"),
                  validator: _requiredNumberValidator,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Weight (kg)"),
                  validator: _requiredNumberValidator,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _healthConditionsCard() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Health Conditions",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _condChip("Diabetes"),
              _condChip("Hypertension"),
              _condChip("Heart Disease"),
              _condChip("None"),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _systolicController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Systolic"),
                  validator: _requiredNumberValidator,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _diastolicController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Diastolic"),
                  validator: _requiredNumberValidator,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _bloodSugarController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Blood Sugar (mg/dL)"),
            validator: _requiredNumberValidator,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _cholesterolController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Cholesterol (mg/dL)"),
            validator: _requiredNumberValidator,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text("Genetic Risk"),
              const Spacer(),
              Switch(
                value: _geneticRisk,
                onChanged: (v) => setState(() => _geneticRisk = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lifestyleCard() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Lifestyle Information",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _dailyStepsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Daily Steps"),
            validator: _requiredNumberValidator,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _exerciseFrequency,
            decoration:
                const InputDecoration(labelText: "Exercise Frequency"),
            items: const [
              DropdownMenuItem(value: "Low", child: Text("Low")),
              DropdownMenuItem(value: "Moderate", child: Text("Moderate")),
              DropdownMenuItem(value: "High", child: Text("High")),
            ],
            onChanged: (v) => setState(() => _exerciseFrequency = v),
            validator: (v) => v == null ? "Required" : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _sleepHoursController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Sleep Hours"),
            validator: _requiredNumberValidator,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text("Smoking"),
              const Spacer(),
              Switch(value: _smoking, onChanged: (v) => setState(() => _smoking = v)),
            ],
          ),
          Row(
            children: [
              const Text("Alcohol"),
              const Spacer(),
              Switch(value: _alcohol, onChanged: (v) => setState(() => _alcohol = v)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dietaryCard() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Dietary Preferences",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _dietChip("Vegetarian"),
              _dietChip("Vegan"),
              _dietChip("Non-Vegetarian"),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _foodAllergiesController,
            decoration: const InputDecoration(labelText: "Food Allergies (optional)"),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _preferredCuisine,
            decoration: const InputDecoration(labelText: "Preferred Cuisine"),
            items: const [
              DropdownMenuItem(value: "Indian", child: Text("Indian")),
              DropdownMenuItem(value: "Chinese", child: Text("Chinese")),
              DropdownMenuItem(value: "Mediterranean", child: Text("Mediterranean")),
              DropdownMenuItem(value: "Continental", child: Text("Continental")),
              DropdownMenuItem(value: "Mixed", child: Text("Mixed")),
            ],
            onChanged: (v) => setState(() => _preferredCuisine = v),
            validator: (v) => v == null ? "Required" : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _foodAversionsController,
            decoration: const InputDecoration(labelText: "Food Aversions (optional)"),
          ),
        ],
      ),
    );
  }

  // ---------------- CHIPS ----------------
  Widget _condChip(String label) {
    final selected = _chronicConditions.contains(label);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (v) {
        setState(() {
          if (label == "None") {
            _chronicConditions.clear();
            if (v) _chronicConditions.add("None");
          } else {
            _chronicConditions.remove("None");
            if (v) {
              _chronicConditions.add(label);
            } else {
              _chronicConditions.remove(label);
            }
          }
        });
      },
    );
  }

  Widget _dietChip(String label) {
    final selected = _dietaryHabit == label;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (v) => setState(() => _dietaryHabit = v ? label : null),
    );
  }
}
