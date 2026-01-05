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

class _PatientHealthDetailsScreenState extends State<PatientHealthDetailsScreen> {
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
  final TextEditingController _foodAllergiesController = TextEditingController();
  final TextEditingController _foodAversionsController = TextEditingController();
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

  // ---------------- COLORS (UI FIX) ----------------
  // ✅ Use same green style as your "Vegetarian" sample
  static const Color kPrimaryGreen = Color(0xFF00A693); // teal-green
  static const Color kCardBg = Colors.white;
  static const Color kBorder = Color(0xFFE6E6E6);
  static const Color kTextDark = Color(0xFF222222);

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
      _bloodSugarController.text = data["blood_sugar_mg_dl"].toString();
      _cholesterolController.text = data["cholesterol_mg_dl"].toString();
      _dailyStepsController.text = data["daily_steps"].toString();
      _sleepHoursController.text = data["sleep_hours"].toString();

      _calorieController.text = data["caloric_intake"].toString();
      _proteinController.text = data["protein_intake"].toString();
      _carbController.text = data["carbohydrate_intake"].toString();
      _fatController.text = data["fat_intake"].toString();

      _foodAllergiesController.text = data["food_allergies"] ?? "";
      _foodAversionsController.text = data["food_aversions"] ?? "";

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

  String _mapExercise(int v) => v == 1 ? "Low" : v == 2 ? "Moderate" : "High";

  // ---------------- SUBMIT ----------------
  Future<void> _submit() async {
    if (_readOnly) return;
    if (!_formKey.currentState!.validate()) return;

    // ✅ extra validation for selection UI
    if (_gender == null) {
      _toast("Please select gender");
      return;
    }
    if (_dietaryHabit == null) {
      _toast("Please select dietary habit");
      return;
    }
    if (_exerciseFrequency == null) {
      _toast("Please select exercise frequency");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = await FirebaseAuth.instance.currentUser!.getIdToken();

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
        "caloric_intake": double.parse(_calorieController.text.trim()),
        "protein_intake": double.parse(_proteinController.text.trim()),
        "carbohydrate_intake": double.parse(_carbController.text.trim()),
        "fat_intake": double.parse(_fatController.text.trim()),
        "food_allergies": _foodAllergiesController.text.trim().isEmpty
            ? null
            : _foodAllergiesController.text.trim(),
        "preferred_cuisine": _preferredCuisine,
        "food_aversions": _foodAversionsController.text.trim().isEmpty
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

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: Text(
          _readOnly ? "Health Details (Approved)" : "Upload Health Details",
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
                  const SizedBox(height: 18),

                  // ✅ GREEN submit button (like your photo)
                  if (!_readOnly)
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _isLoading ? null : _submit,
                        child: const Text(
                          "Submit Details",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                  if (_readOnly)
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.restaurant_menu),
                        label: const Text(
                          "Show Meal Plan",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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
                    ),

                  const SizedBox(height: 20),
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

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF3F3F3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: kPrimaryGreen.withOpacity(0.8), width: 1.4),
        ),
      );

  Widget _field(
    TextEditingController c,
    String hint, {
    bool number = true,
  }) =>
      TextFormField(
        controller: c,
        enabled: _enabled(),
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: _dec(hint),
        style: const TextStyle(fontSize: 15),
        validator: (v) {
          if (_readOnly) return null;
          if (v == null || v.trim().isEmpty) return "Required";
          return null;
        },
      );

  // ---------------- SECTIONS ----------------
  Widget _basicInfoCard() => _sectionCard(
        title: "Basic Information",
        children: [
          _field(_ageController, "Age"),
          const SizedBox(height: 10),

          // ✅ Gender label + segmented style
          const Text(
            "Gender",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 8),
          _genderSegmented(),
          const SizedBox(height: 12),

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
          const Text(
            "Conditions",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
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
              Expanded(child: _field(_systolicController, "Systolic")),
              const SizedBox(width: 10),
              Expanded(child: _field(_diastolicController, "Diastolic")),
            ],
          ),
          const SizedBox(height: 10),
          _field(_bloodSugarController, "Blood Sugar (mg/dL)"),
          const SizedBox(height: 10),
          _field(_cholesterolController, "Cholesterol (mg/dL)"),
          const SizedBox(height: 6),

          // ✅ Genetic Risk clean row
          _switchRow(
            label: "Genetic Risk",
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
          const SizedBox(height: 10),

          DropdownButtonFormField<String>(
            value: _exerciseFrequency,
            decoration: _dec("Exercise Frequency"),
            items: const [
              DropdownMenuItem(value: "Low", child: Text("Low")),
              DropdownMenuItem(value: "Moderate", child: Text("Moderate")),
              DropdownMenuItem(value: "High", child: Text("High")),
            ],
            onChanged: _enabled() ? (v) => setState(() => _exerciseFrequency = v) : null,
            validator: (v) {
              if (_readOnly) return null;
              if (v == null) return "Required";
              return null;
            },
          ),

          const SizedBox(height: 10),
          _field(_sleepHoursController, "Sleep Hours"),
          const SizedBox(height: 6),

          _switchRow(
            label: "Smoking",
            value: _smoking,
            onChanged: _enabled() ? (v) => setState(() => _smoking = v) : null,
          ),
          _switchRow(
            label: "Alcohol",
            value: _alcohol,
            onChanged: _enabled() ? (v) => setState(() => _alcohol = v) : null,
          ),
        ],
      );

  Widget _nutritionTargetsCard() => _sectionCard(
        title: "Daily Nutrition Targets",
        children: [
          _field(_calorieController, "Calories (kcal)"),
          const SizedBox(height: 10),
          _field(_proteinController, "Protein (g/day)"),
          const SizedBox(height: 10),
          _field(_carbController, "Carbohydrates (g/day)"),
          const SizedBox(height: 10),
          _field(_fatController, "Fat (g/day)"),
        ],
      );

  Widget _dietaryCard() => _sectionCard(
        title: "Dietary Preferences",
        children: [
          const Text(
            "Dietary Preference",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 10),

          // ✅ Clear + visible dietary chips like your photo
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _dietChip("Vegetarian"),
              _dietChip("Vegan"),
              _dietChip("Non-Vegetarian"),
            ],
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _foodAllergiesController,
            enabled: _enabled(),
            decoration: _dec("Food Allergies"),
          ),
          const SizedBox(height: 10),

          DropdownButtonFormField<String>(
            value: _preferredCuisine,
            decoration: _dec("Preferred Cuisine"),
            items: const [
              DropdownMenuItem(value: "Indian", child: Text("Indian")),
              DropdownMenuItem(value: "Chinese", child: Text("Chinese")),
              DropdownMenuItem(value: "Mediterranean", child: Text("Mediterranean")),
              DropdownMenuItem(value: "Continental", child: Text("Continental")),
              DropdownMenuItem(value: "Mixed", child: Text("Mixed")),
            ],
            onChanged: _enabled() ? (v) => setState(() => _preferredCuisine = v) : null,
          ),
          const SizedBox(height: 10),

          TextFormField(
            controller: _foodAversionsController,
            enabled: _enabled(),
            decoration: _dec("Food Aversions"),
          ),
        ],
      );

  // ---------------- UI HELPERS ----------------
  Widget _sectionCard({
    required String title,
    required List<Widget> children,
  }) =>
      Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: kTextDark,
              ),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      );

  // ✅ Segmented Gender selector (works perfectly + clear)
  Widget _genderSegmented() {
    final selectedIndex = _gender == null
        ? null
        : (_gender == Gender.male ? 0 : 1);

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _segBtn(
              label: "Male",
              selected: selectedIndex == 0,
              onTap: _enabled() ? () => setState(() => _gender = Gender.male) : null,
              left: true,
            ),
          ),
          Expanded(
            child: _segBtn(
              label: "Female",
              selected: selectedIndex == 1,
              onTap: _enabled() ? () => setState(() => _gender = Gender.female) : null,
              right: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _segBtn({
    required String label,
    required bool selected,
    required VoidCallback? onTap,
    bool left = false,
    bool right = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.horizontal(
        left: left ? const Radius.circular(14) : Radius.zero,
        right: right ? const Radius.circular(14) : Radius.zero,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? kPrimaryGreen : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: left ? const Radius.circular(14) : Radius.zero,
            right: right ? const Radius.circular(14) : Radius.zero,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: selected ? Colors.white : kTextDark,
          ),
        ),
      ),
    );
  }

  // ✅ Better switch row like your UI
  Widget _switchRow({
    required String label,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
        color: const Color(0xFFF3F3F3),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch(
            value: value,
            activeColor: kPrimaryGreen,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // ✅ Health condition chip (clear selected state like your photo)
  Widget _condChip(String label) {
    final selected = _chronicConditions.contains(label);

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: kPrimaryGreen,
      backgroundColor: const Color(0xFFF0F0F0),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: selected ? Colors.white : kTextDark,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: selected ? kPrimaryGreen : kBorder,
          width: 1,
        ),
      ),
      onSelected: _enabled()
          ? (v) {
              setState(() {
                if (label == "None") {
                  _chronicConditions.clear();
                  if (v) _chronicConditions.add("None");
                } else {
                  _chronicConditions.remove("None");
                  v ? _chronicConditions.add(label) : _chronicConditions.remove(label);
                }
              });
            }
          : null,
    );
  }

  // ✅ Dietary chip (adds ✅ when selected + green)
  Widget _dietChip(String label) {
    final selected = _dietaryHabit == label;

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected) ...[
            const Icon(Icons.check, size: 16, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Text(label),
        ],
      ),
      selected: selected,
      showCheckmark: false,
      selectedColor: kPrimaryGreen,
      backgroundColor: const Color(0xFFF0F0F0),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: selected ? Colors.white : kTextDark,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: selected ? kPrimaryGreen : kBorder,
          width: 1,
        ),
      ),
      onSelected: _enabled()
          ? (v) => setState(() => _dietaryHabit = v ? label : null)
          : null,
    );
  }
}
