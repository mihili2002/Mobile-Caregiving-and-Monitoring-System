import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'widgets/role_based_wrapper.dart';
import 'services/elder_health_submission_service.dart';
import 'pages/elder/meal_plans/meal_plan_details_screen.dart';
import 'models/user_model.dart';

enum Gender { male, female }

class PatientHealthDetailsScreen extends StatefulWidget {
  final String? submissionId;
  final String? status;
  final String? elderId;
  final String? elderName;
  final UserRole? userRole;

  const PatientHealthDetailsScreen({
    Key? key,
    this.submissionId,
    this.status,
    this.elderId,
    this.elderName,
    this.userRole,
  }) : super(key: key);

  bool get isReadOnly => status == "approved";

  @override
  State<PatientHealthDetailsScreen> createState() =>
      _PatientHealthDetailsScreenState();
}

class _PatientHealthDetailsScreenState
    extends State<PatientHealthDetailsScreen> {
  // ------------ CONTROLLERS --------
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

  // ------------ STATE --------
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

  // ------------ ROLE-BASED FLAGS --------
  bool get _isDoctorRole => widget.userRole == UserRole.doctor;
  bool get _isCaregiverRole => widget.userRole == UserRole.caregiver;
  bool get _isElderRole => widget.userRole == UserRole.elder;

  // ------------ INIT --------
  @override
  void initState() {
    super.initState();
    if (widget.submissionId != null) {
      _loadSubmission();
    }
  }

  Future<void> _pickAndProcessPDF() async {
    try {
      // 1. Pick the file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true, // Crucial for accessing result.files.first.bytes
      );

      if (result == null || result.files.first.bytes == null) return;

      setState(() => _isLoading = true);

      // 2. Get Firebase Token and Upload
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not authenticated");

      final token = await user.getIdToken();

      final Map<String, dynamic> data = await _submissionService.extractDataFromPDF(
        token: token!,
        fileBytes: result.files.first.bytes!,
        fileName: result.files.first.name,
      );

      print("Extracted Keys: ${data.keys.toList()}");
      print("Caloric Intake Value: ${data['caloric_intake']} (Type: ${data['caloric_intake'].runtimeType})");

      // 3. Auto-fill the controllers and state with null-safety
      setState(() {
        // Helper to handle nulls and convert to string for Controllers
        String s(dynamic val) => (val ?? "").toString();

        _ageController.text = s(data["age"]);
        _heightController.text = s(data["height_cm"]);
        _weightController.text = s(data["weight_kg"]);
        _bloodSugarController.text = s(data["blood_sugar_mg_dl"]);
        _cholesterolController.text = s(data["cholesterol_mg_dl"]);
        _foodAllergiesController.text = s(data["food_allergies"]);

        // --- ADDED INTAKE FIELDS ---
        _calorieController.text = s(data["caloric_intake"]);
        _proteinController.text = s(data["protein_intake"]);
        _carbController.text = s(data["carbohydrate_intake"]);
        _fatController.text = s(data["fat_intake"]);
        // ---------------------------

        // Gender Mapping
        if (data["gender"] != null) {
          final g = data["gender"].toString().toLowerCase();
          _gender = (g == "male") ? Gender.male : (g == "female" ? Gender.female : null);
        }

        // Nested Blood Pressure
        if (data["blood_pressure"] != null && data["blood_pressure"] is Map) {
          _systolicController.text = s(data["blood_pressure"]["systolic"]);
          _diastolicController.text = s(data["blood_pressure"]["diastolic"]);
        }

        // Chronic Conditions
        if (data["chronic_conditions"] != null && data["chronic_conditions"] is List) {
          _chronicConditions.clear();
          _chronicConditions.addAll(List<String>.from(data["chronic_conditions"]));
        }

        // Dropdown and Chip values
        _dietaryHabit = data["dietary_habit"];

        final allowedCuisines = ["Indian", "Chinese", "Mediterranean", "Continental", "Mixed"];
        if (allowedCuisines.contains(data["preferred_cuisine"])) {
          _preferredCuisine = data["preferred_cuisine"];
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("PDF processed and fields filled successfully!"),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ------------ LOAD SUBMISSION --------
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

      _calorieController.text = (data["caloric_intake"] ?? "").toString();
      _proteinController.text = (data["protein_intake"] ?? "").toString();
      _carbController.text = (data["carbohydrate_intake"] ?? "").toString();
      _fatController.text = (data["fat_intake"] ?? "").toString();

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

  String _mapExercise(int v) =>
      v == 1 ? "Low" : v == 2 ? "Moderate" : "High";

  // ------------ SUBMIT --------
  Future<void> _submit() async {
    if (_readOnly) return;
    if (!_formKey.currentState!.validate()) return;

    // Additional validation for dietary habit
    // if (_dietaryHabit == null) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(
    //       content: Text("Please select a dietary habit"),
    //       backgroundColor: Colors.red,
    //     ),
    //   );
    //   return;
    // }

    setState(() => _isLoading = true);

    try {
      final token = await FirebaseAuth.instance.currentUser!.getIdToken();

      // Validate required fields for doctor role
      if (_isDoctorRole) {
        if (_ageController.text.trim().isEmpty) {
          throw Exception("Age is required");
        }
        if (_gender == null) {
          throw Exception("Gender is required");
        }
        if (_heightController.text.trim().isEmpty) {
          throw Exception("Height is required");
        }
        if (_weightController.text.trim().isEmpty) {
          throw Exception("Weight is required");
        }
        if (_systolicController.text.trim().isEmpty) {
          throw Exception("Systolic blood pressure is required");
        }
        if (_diastolicController.text.trim().isEmpty) {
          throw Exception("Diastolic blood pressure is required");
        }
      }

      // Validate required fields for caregiver role
      if (_isCaregiverRole) {
        if (_dailyStepsController.text.trim().isEmpty) {
          throw Exception("Daily steps is required");
        }
        if (_sleepHoursController.text.trim().isEmpty) {
          throw Exception("Sleep hours is required");
        }
        if (_exerciseFrequency == null) {
          throw Exception("Exercise frequency is required");
        }
        if (_preferredCuisine == null) {
          throw Exception("Preferred cuisine is required");
        }
      }

      // Validate required fields for elder role
      if (_isElderRole) {
        if (_ageController.text.trim().isEmpty) {
          throw Exception("Age is required");
        }
        if (_gender == null) {
          throw Exception("Gender is required");
        }
        if (_preferredCuisine == null) {
          throw Exception("Preferred cuisine is required");
        }
      }

      // Cross-field and range validations
      _validateRangesBeforeSubmit();

      // Build payload
// 1. Initialize the map with the mandatory ID
      final Map<String, dynamic> payload = {
        "elder_id": widget.elderId,
      };

// 2. Helper function to only add non-null values to the map
      void addIfNotNull(String key, dynamic value) {
        if (value != null) {
          payload[key] = value;
        }
      }

// --- Medical Fields ---
      addIfNotNull("age", _parseIntOrNull(_ageController.text));
      addIfNotNull("gender", _gender == null ? null : (_gender == Gender.male ? "Male" : "Female"));
      addIfNotNull("height_cm", _parseDoubleOrNull(_heightController.text));
      addIfNotNull("weight_kg", _parseDoubleOrNull(_weightController.text));
      addIfNotNull("chronic_conditions", _chronicConditions.isEmpty ? null : _chronicConditions);
      addIfNotNull("genetic_risk", _geneticRisk);

// Handle Nested Blood Pressure (Only add if at least one value exists)
      Map<String, dynamic> bp = {};
      final systolic = _parseIntOrNull(_systolicController.text);
      final diastolic = _parseIntOrNull(_diastolicController.text);
      if (systolic != null) bp["systolic"] = systolic;
      if (diastolic != null) bp["diastolic"] = diastolic;
      if (bp.isNotEmpty) payload["blood_pressure"] = bp;

      addIfNotNull("blood_sugar_mg_dl", _parseDoubleOrNull(_bloodSugarController.text));
      addIfNotNull("cholesterol_mg_dl", _parseDoubleOrNull(_cholesterolController.text));

// --- Caregiver / Lifestyle Fields ---
// Note: Use ?? 0 only for fields your backend REQUIRES to be non-null integers
      addIfNotNull("daily_steps", _parseIntOrNull(_dailyStepsController.text));
      addIfNotNull("exercise_frequency", _exerciseFrequency == "Low" ? 1 : _exerciseFrequency == "Moderate" ? 2 : 3);
      addIfNotNull("sleep_hours", _parseDoubleOrNull(_sleepHoursController.text));
      addIfNotNull("smoking", _smoking);
      addIfNotNull("alcohol", _alcohol);
      addIfNotNull("dietary_habit", _dietaryHabit);
      addIfNotNull("caloric_intake", _parseDoubleOrNull(_calorieController.text));
      addIfNotNull("protein_intake", _parseDoubleOrNull(_proteinController.text));
      addIfNotNull("carbohydrate_intake", _parseDoubleOrNull(_carbController.text));
      addIfNotNull("fat_intake", _parseDoubleOrNull(_fatController.text));

      // Textfield trims
      final allergies = _foodAllergiesController.text.trim();
      if (allergies.isNotEmpty) payload["food_allergies"] = allergies;

      addIfNotNull("preferred_cuisine", _preferredCuisine);

      final aversions = _foodAversionsController.text.trim();
      if (aversions.isNotEmpty) payload["food_aversions"] = aversions;

      // Debug to verify you aren't sending nulls
      print("CLEAN PAYLOAD: $payload");

      await _submissionService.submitHealthDetails(
        token: token!,
        payload: payload,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Health details saved successfully"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getAppBarTitle() {
    if (_isDoctorRole) {
      return "Medical Details - ${widget.elderName ?? 'Elder'}";
    } else if (_isCaregiverRole) {
      return "Lifestyle & Nutrition - ${widget.elderName ?? 'Elder'}";
    }
    return _readOnly ? "Health Details (Approved)" : "Upload Health Details";
  }

  // ------------ UI --------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        actions: [
          if (!_readOnly)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _pickAndProcessPDF,
              tooltip: "Fill from PDF",
            ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Doctor: Medical fields
                  if (_isDoctorRole) ...[
                    _basicInfoCard(),
                    _healthConditionsCard(),
                  ] else if (_isCaregiverRole) ...[
                    // Caregiver: allow filling chronic conditions + lifestyle
                    _chronicConditionsOnlyCard(),
                    _lifestyleCard(),
                    _nutritionIntakesCard(),
                    _dietaryCard(),
                  ] else ...[
                    // Elder: All fields
                    _basicInfoCard(),
                    _healthConditionsCard(),
                    _lifestyleCard(),
                    _nutritionIntakesCard(),
                    _dietaryCard(),
                  ],
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

  // ------------ HELPERS --------
  bool _enabled() => !_readOnly;

  InputDecoration _dec(String label) =>
      InputDecoration(labelText: label);

  // Safe parsing helpers
  int? _parseIntOrNull(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    try {
      return int.parse(trimmed);
    } catch (_) {
      return null;
    }
  }

  double? _parseDoubleOrNull(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    try {
      return double.parse(trimmed);
    } catch (_) {
      return null;
    }
  }

  Widget _field(
      TextEditingController c,
      String label, {
        bool number = true,
        bool required = true,
        double? min,
        double? max,
        bool integerOnly = false,
      }) =>
      TextFormField(
        controller: c,
        enabled: _enabled(),
        keyboardType:
            number ? TextInputType.number : TextInputType.text,
        decoration: _dec(label),
        validator: (value) {
          if (required) {
            if (value == null || value.trim().isEmpty) {
              return "$label is required";
            }
          }

          if (number && value != null && value.trim().isNotEmpty) {
            final trimmed = value.trim();
            final parsedDouble = double.tryParse(trimmed);
            final parsedInt = int.tryParse(trimmed);
            if (integerOnly) {
              if (parsedInt == null) return "Please enter a valid integer";
              final v = parsedInt.toDouble();
              if (min != null && v < min) return "$label must be >= ${min.toStringAsFixed(0)}";
              if (max != null && v > max) return "$label must be <= ${max.toStringAsFixed(0)}";
            } else {
              final v = parsedDouble ?? parsedInt?.toDouble();
              if (v == null) return "Please enter a valid number";
              if (min != null && v < min) return "$label must be >= $min";
              if (max != null && v > max) return "$label must be <= $max";
            }
          }

          return null;
        },
      );

  // Validate cross-field logical constraints before submit
  void _validateRangesBeforeSubmit() {
    // Blood pressure logical check
    final systolic = _parseIntOrNull(_systolicController.text);
    final diastolic = _parseIntOrNull(_diastolicController.text);
    if (systolic != null && diastolic != null) {
      if (systolic < diastolic) {
        throw Exception("Systolic must be greater than or equal to Diastolic");
      }
    }

    // Role-based extra checks
    if ((_isCaregiverRole || _isElderRole) && (_dietaryHabit == null || _dietaryHabit!.isEmpty)) {
      throw Exception("Please select a dietary habit");
    }

    // Age check for Doctor/Elder roles
    final age = _parseIntOrNull(_ageController.text);
    if ((_isDoctorRole || _isElderRole) && age != null) {
      if (age <= 0 || age > 120) throw Exception("Please enter a realistic age (1-120)");
    }
  }

  // ------------ SECTIONS --------
  Widget _basicInfoCard() => _sectionCard(
    title: "Basic Information",
    children: [
      _field(_ageController, "Age", integerOnly: true, min: 1, max: 120),
      _genderRow(),
      Row(
        children: [
          Expanded(child: _field(_heightController, "Height (cm)", integerOnly: true, min: 30, max: 250)),
          const SizedBox(width: 10),
          Expanded(child: _field(_weightController, "Weight (kg)", min: 2, max: 200)),
        ],
      ),
    ],
  );

  Widget _healthConditionsCard() => _sectionCard(
    title: "Health Conditions",
    children: [
      // Wrap(
      //   spacing: 12,
      //   runSpacing: 12,
      //   children: [
      //     _condChip("Diabetes"),
      //     _condChip("Hypertension"),
      //     _condChip("Heart Disease"),
      //     _condChip("None"),
      //   ],
      // ),
      Row(
        children: [
          Expanded(child: _field(_systolicController, "Systolic", integerOnly: true, min: 50, max: 300)),
          const SizedBox(width: 10),
          Expanded(child: _field(_diastolicController, "Diastolic", integerOnly: true, min: 30, max: 200)),
        ],
      ),
      _field(_bloodSugarController, "Blood Sugar (mg/dL)", min: 20, max: 1000),
      _field(_cholesterolController, "Cholesterol (mg/dL)", min: 50, max: 1000),
      SwitchListTile(
        title: const Text("Genetic Risk"),
        value: _geneticRisk,
        onChanged: _enabled()
            ? (v) => setState(() => _geneticRisk = v)
            : null,
      ),
    ],
  );

  // A slimmer card exposing only chronic condition chips (for caregiver use)
  Widget _chronicConditionsOnlyCard() => _sectionCard(
    title: "Health Conditions",
    children: [
      SizedBox(
        width: double.infinity,
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _condChip("Diabetes"),
            _condChip("Hypertension"),
            _condChip("Heart Disease"),
            _condChip("None"),
          ],
        ),
      ),
    ],
  );

  Widget _lifestyleCard() => _sectionCard(
    title: "Lifestyle Information",
    children: [
      _field(_dailyStepsController, "Daily Steps", integerOnly: true, min: 0, max: 10000),
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
        validator: (value) {
          if (value == null || value.isEmpty) {
            return "Exercise frequency is required";
          }
          return null;
        },
        onChanged:
            _enabled() ? (v) => setState(() => _exerciseFrequency = v) : null,
      ),
      _field(_sleepHoursController, "Sleep Hours", min: 0, max: 24),
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

  Widget _nutritionIntakesCard() => _sectionCard(
    title: "Daily Nutrition Intakes",
    children: [
      _field(_calorieController, "Caloric Intake (kcal)", required: false, min: 0, max: 10000),
      _field(_proteinController, "Protein (g/day)", required: false, min: 0, max: 5000),
      _field(_carbController, "Carbohydrates (g/day)", required: false, min: 0, max: 5000),
      _field(_fatController, "Fat (g/day)", required: false, min: 0, max: 5000),
    ],
  );

  Widget _dietaryCard() => _sectionCard(
    title: "Dietary Preferences",
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _dietChip("Vegetarian"),
          _dietChip("Vegan"),
          _dietChip("Non-Vegetarian"),
        ],
      ),
      if (_dietaryHabit == null)
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            "Please select a dietary habit",
            style: TextStyle(color: Colors.red.shade600, fontSize: 12),
          ),
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
        validator: (value) {
          if (value == null || value.isEmpty) {
            return "Preferred cuisine is required";
          }
          return null;
        },
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

  // ------------ UI HELPERS --------
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
          onPressed: () => setState(() => _gender = Gender.male),
          style: OutlinedButton.styleFrom(
            backgroundColor: _gender == Gender.male ? const Color(0xFF11BFA8) : Colors.white,
            foregroundColor: _gender == Gender.male ? Colors.white : Colors.black87,
            side: BorderSide(
              color: _gender == Gender.male ? const Color(0xFF11BFA8) : Colors.black26,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: const Text("Male", style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: OutlinedButton(
          onPressed: () => setState(() => _gender = Gender.female),
          style: OutlinedButton.styleFrom(
            backgroundColor: _gender == Gender.female ? const Color(0xFF11BFA8) : Colors.white,
            foregroundColor: _gender == Gender.female ? Colors.white : Colors.black87,
            side: BorderSide(
              color: _gender == Gender.female ? const Color(0xFF11BFA8) : Colors.black26,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: const Text("Female", style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ),
    ],
  );

  Widget _condChip(String label) {
    final bool selected = _chronicConditions.contains(label);
    final bool isNone = label == "None";

    return ChoiceChip(
      label: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: selected
                ? Colors.white
                : (isNone ? Colors.red.shade800 : Colors.grey.shade900),
          ),
        ),
      ),
      selected: selected,
      selectedColor: isNone ? Colors.red.shade600 : const Color.fromARGB(255, 36, 196, 177),
      backgroundColor: isNone ? Colors.red.shade50 : Colors.grey.shade200,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected
              ? Colors.transparent
              : (isNone ? Colors.red.shade300 : Colors.grey.shade400),
          width: 1.5,
        ),
      ),
      elevation: selected ? 3 : 0,
      pressElevation: 4,
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
    final bool selected = _dietaryHabit == label;

    return ChoiceChip(
      label: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : Colors.grey.shade900,
          ),
        ),
      ),
      selected: selected,
      selectedColor: const Color(0xFF67D2DA),
      backgroundColor: Colors.grey.shade200,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      elevation: selected ? 3 : 0,
      pressElevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? Colors.transparent : Colors.grey.shade400,
          width: 1.5,
        ),
      ),
      onSelected: _enabled()
          ? (v) {
              setState(() => _dietaryHabit = v ? label : null);
            }
          : null,
    );
  }
}
