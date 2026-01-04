import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'widgets/role_based_wrapper.dart';
import 'services/elder_health_submission_service.dart';
import 'pages/elder/meal_plans/meal_plan_details_screen.dart';

enum Gender { male, female }

class PatientHealthDetailsScreen extends StatefulWidget {
  final String? submissionId;
  final String? status;

  const PatientHealthDetailsScreen({
    Key? key,
    this.submissionId,
    this.status,
  }) : super(key: key);

  bool get isReadOnly => status == "approved";

  @override
  State<PatientHealthDetailsScreen> createState() =>
      _PatientHealthDetailsScreenState();
}

class _PatientHealthDetailsScreenState
    extends State<PatientHealthDetailsScreen> {
  // ---------------- CONTROLLERS ----------------
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _systolicController = TextEditingController();
  final TextEditingController _diastolicController = TextEditingController();
  final TextEditingController _bloodSugarController = TextEditingController();
  final TextEditingController _cholesterolController = TextEditingController();
  final TextEditingController _dailyStepsController = TextEditingController();
  final TextEditingController _sleepHoursController = TextEditingController();
  final TextEditingController _foodAllergiesController =
  TextEditingController();
  final TextEditingController _foodAversionsController =
  TextEditingController();
  final TextEditingController _calorieController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();
  final TextEditingController _carbController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();

  // ---------------- STATE ----------------
  Gender? _gender;
  final List<String> _chronicConditions = [];
  bool _geneticRisk = false;
  String? _exerciseFrequency;
  bool _smoking = false;
  bool _alcohol = false;
  String? _dietaryHabit;
  String? _preferredCuisine;

  bool _isLoading = false;
  bool get _readOnly => widget.isReadOnly;

  final _formKey = GlobalKey<FormState>();
  final ElderHealthSubmissionService _submissionService =
  ElderHealthSubmissionService();

  // ---------------- INIT ----------------
  @override
  void initState() {
    super.initState();
    if (widget.submissionId != null) {
      _loadSubmission();
    }
  }

  // ---------------- LOAD SUBMISSION ----------------
  Future<void> _loadSubmission() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final token = await user.getIdToken();
      if (token == null) return;

      final data = await _submissionService.getSubmissionDetails(
        token: token,
        submissionId: widget.submissionId!,
      );

      _ageController.text = data["age"].toString();
      _heightController.text = data["height_cm"].toString();
      _weightController.text = data["weight_kg"].toString();
      _systolicController.text =
          data["blood_pressure"]["systolic"].toString();
      _diastolicController.text =
          data["blood_pressure"]["diastolic"].toString();
      _bloodSugarController.text =
          data["blood_sugar_mg_dl"].toString();
      _cholesterolController.text =
          data["cholesterol_mg_dl"].toString();
      _dailyStepsController.text =
          data["daily_steps"].toString();
      _sleepHoursController.text =
          data["sleep_hours"].toString();

      _calorieController.text =
          data["caloric_intake"].toString();
      _proteinController.text =
          data["protein_intake"].toString();
      _carbController.text =
          data["carbohydrate_intake"].toString();
      _fatController.text =
          data["fat_intake"].toString();

      _foodAllergiesController.text =
          data["food_allergies"] ?? "";
      _foodAversionsController.text =
          data["food_aversions"] ?? "";

      _gender = data["gender"] == "Male" ? Gender.male : Gender.female;
      _dietaryHabit = data["dietary_habit"];
      _preferredCuisine = data["preferred_cuisine"];
      _exerciseFrequency = _mapExercise(data["exercise_frequency"]);
      _smoking = data["smoking"] ?? false;
      _alcohol = data["alcohol"] ?? false;
      _geneticRisk = data["genetic_risk"] ?? false;

      _chronicConditions
        ..clear()
        ..addAll(List<String>.from(data["chronic_conditions"] ?? []));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _mapExercise(int v) =>
      v == 1 ? "Low" : v == 2 ? "Moderate" : "High";

  // ---------------- SUBMIT ----------------
  Future<void> _submit() async {
    if (_readOnly) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final token =
      await FirebaseAuth.instance.currentUser!.getIdToken();

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
        "blood_sugar_mg_dl":
        double.parse(_bloodSugarController.text.trim()),
        "cholesterol_mg_dl":
        double.parse(_cholesterolController.text.trim()),
        "daily_steps": int.parse(_dailyStepsController.text.trim()),
        "exercise_frequency":
        _exerciseFrequency == "Low"
            ? 1
            : _exerciseFrequency == "Moderate"
            ? 2
            : 3,
        "sleep_hours":
        double.parse(_sleepHoursController.text.trim()),
        "smoking": _smoking,
        "alcohol": _alcohol,
        "dietary_habit": _dietaryHabit,
        "caloric_intake":
        double.parse(_calorieController.text.trim()),
        "protein_intake":
        double.parse(_proteinController.text.trim()),
        "carbohydrate_intake":
        double.parse(_carbController.text.trim()),
        "fat_intake":
        double.parse(_fatController.text.trim()),
        "food_allergies":
        _foodAllergiesController.text.trim().isEmpty
            ? null
            : _foodAllergiesController.text.trim(),
        "preferred_cuisine": _preferredCuisine,
        "food_aversions":
        _foodAversionsController.text.trim().isEmpty
            ? null
            : _foodAversionsController.text.trim(),
      };

      if (widget.submissionId == null) {
        await _submissionService.submitHealthDetails(
          token: token!,
          payload: payload,
        );
      } else {
        await _submissionService.updateHealthDetails(
          token: token!,
          submissionId: widget.submissionId!,
          payload: payload,
        );
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RoleBasedWrapper()),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _readOnly
              ? "Health Details (Approved)"
              : "Upload Health Details",
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _basicInfoCard(),
                  _healthConditionsCard(),
                  _lifestyleCard(),
                  _nutritionTargetsCard(),
                  _dietaryCard(),
                  const SizedBox(height: 16),

                  if (!_readOnly)
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: const Text("Submit Details"),
                    ),

                  if (_readOnly)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.restaurant_menu),
                      label: const Text("Show Meal Plan"),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MealPlanDetailsScreen(
                              submissionId: widget.submissionId!,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  // ---------------- HELPERS ----------------
  bool _enabled() => !_readOnly;

  InputDecoration _dec(String label) =>
      InputDecoration(labelText: label);

  Widget _field(
      TextEditingController c,
      String label, {
        bool number = true,
      }) =>
      TextFormField(
        controller: c,
        enabled: _enabled(),
        keyboardType:
        number ? TextInputType.number : TextInputType.text,
        decoration: _dec(label),
      );

  // ---------------- SECTIONS (ORIGINAL UI PRESERVED) ----------------
  Widget _basicInfoCard() => _sectionCard(
    title: "Basic Information",
    children: [
      _field(_ageController, "Age"),
      _genderRow(),
      Row(
        children: [
          Expanded(child: _field(_heightController, "Height (cm)")),
          const SizedBox(width: 10),
          Expanded(child: _field(_weightController, "Weight (kg)")),
        ],
      ),
    ],
  );

  Widget _healthConditionsCard() => _sectionCard(
    title: "Health Conditions",
    children: [
      Wrap(
        spacing: 8,
        children: [
          _condChip("Diabetes"),
          _condChip("Hypertension"),
          _condChip("Heart Disease"),
          _condChip("None"),
        ],
      ),
      Row(
        children: [
          Expanded(child: _field(_systolicController, "Systolic")),
          const SizedBox(width: 10),
          Expanded(child: _field(_diastolicController, "Diastolic")),
        ],
      ),
      _field(_bloodSugarController, "Blood Sugar (mg/dL)"),
      _field(_cholesterolController, "Cholesterol (mg/dL)"),
      SwitchListTile(
        title: const Text("Genetic Risk"),
        value: _geneticRisk,
        onChanged: _enabled()
            ? (v) => setState(() => _geneticRisk = v)
            : null,
      ),
    ],
  );

  Widget _lifestyleCard() => _sectionCard(
    title: "Lifestyle Information",
    children: [
      _field(_dailyStepsController, "Daily Steps"),
      DropdownButtonFormField<String>(
        value: _exerciseFrequency,
        decoration:
        const InputDecoration(labelText: "Exercise Frequency"),
        items: const [
          DropdownMenuItem(value: "Low", child: Text("Low")),
          DropdownMenuItem(
              value: "Moderate", child: Text("Moderate")),
          DropdownMenuItem(value: "High", child: Text("High")),
        ],
        onChanged:
        _enabled() ? (v) => setState(() => _exerciseFrequency = v) : null,
      ),
      _field(_sleepHoursController, "Sleep Hours"),
      SwitchListTile(
        title: const Text("Smoking"),
        value: _smoking,
        onChanged:
        _enabled() ? (v) => setState(() => _smoking = v) : null,
      ),
      SwitchListTile(
        title: const Text("Alcohol"),
        value: _alcohol,
        onChanged:
        _enabled() ? (v) => setState(() => _alcohol = v) : null,
      ),
    ],
  );

  Widget _nutritionTargetsCard() => _sectionCard(
    title: "Daily Nutrition Targets",
    children: [
      _field(_calorieController, "Calories (kcal)"),
      _field(_proteinController, "Protein (g/day)"),
      _field(_carbController, "Carbohydrates (g/day)"),
      _field(_fatController, "Fat (g/day)"),
    ],
  );

  Widget _dietaryCard() => _sectionCard(
    title: "Dietary Preferences",
    children: [
      Wrap(
        spacing: 8,
        children: [
          _dietChip("Vegetarian"),
          _dietChip("Vegan"),
          _dietChip("Non-Vegetarian"),
        ],
      ),
      TextFormField(
        controller: _foodAllergiesController,
        enabled: _enabled(),
        decoration:
        const InputDecoration(labelText: "Food Allergies"),
      ),
      DropdownButtonFormField<String>(
        value: _preferredCuisine,
        decoration:
        const InputDecoration(labelText: "Preferred Cuisine"),
        items: const [
          DropdownMenuItem(value: "Indian", child: Text("Indian")),
          DropdownMenuItem(value: "Chinese", child: Text("Chinese")),
          DropdownMenuItem(
              value: "Mediterranean", child: Text("Mediterranean")),
          DropdownMenuItem(
              value: "Continental", child: Text("Continental")),
          DropdownMenuItem(value: "Mixed", child: Text("Mixed")),
        ],
        onChanged:
        _enabled() ? (v) => setState(() => _preferredCuisine = v) : null,
      ),
      TextFormField(
        controller: _foodAversionsController,
        enabled: _enabled(),
        decoration:
        const InputDecoration(labelText: "Food Aversions"),
      ),
    ],
  );

  // ---------------- UI HELPERS ----------------
  Widget _sectionCard({
    required String title,
    required List<Widget> children,
  }) =>
      Card(
        margin: const EdgeInsets.symmetric(vertical: 10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ...children.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: e,
              )),
            ],
          ),
        ),
      );

  Widget _genderRow() => Row(
    children: [
      Expanded(
        child: OutlinedButton(
          onPressed:
          _enabled() ? () => setState(() => _gender = Gender.male) : null,
          child: const Text("Male"),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: OutlinedButton(
          onPressed:
          _enabled() ? () => setState(() => _gender = Gender.female) : null,
          child: const Text("Female"),
        ),
      ),
    ],
  );

  Widget _condChip(String label) {
    final selected = _chronicConditions.contains(label);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: _enabled()
          ? (v) {
        setState(() {
          if (label == "None") {
            _chronicConditions.clear();
            if (v) _chronicConditions.add("None");
          } else {
            _chronicConditions.remove("None");
            v
                ? _chronicConditions.add(label)
                : _chronicConditions.remove(label);
          }
        });
      }
          : null,
    );
  }

  Widget _dietChip(String label) {
    final selected = _dietaryHabit == label;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected:
      _enabled() ? (v) => setState(() => _dietaryHabit = v ? label : null) : null,
    );
  }
}
