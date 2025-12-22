import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'ElderDashboardScreen.dart';

enum Gender { male, female }

class PatientHealthDetailsScreen extends StatefulWidget {
  const PatientHealthDetailsScreen({Key? key}) : super(key: key);

  @override
  State<PatientHealthDetailsScreen> createState() => _PatientHealthDetailsScreenState();
}

class _PatientHealthDetailsScreenState extends State<PatientHealthDetailsScreen> {
  // Text controllers for fields
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

  String? _dietaryHabit; // Vegetarian, Vegan, Non-Vegetarian
  String? _preferredCuisine; // Indian, Chinese, Western

  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();

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

  // Basic numeric validation helper
  String? _requiredNumberValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    if (double.tryParse(value) == null) return 'Enter a valid number';
    return null;
  }

  // Clear all fields
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

  // Submit handler saves to Firestore
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fix validation errors')));
      return;
    }
    if (_gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select gender')));
      return;
    }
    if (_dietaryHabit == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select dietary habit')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final doc = {
        'age': int.tryParse(_ageController.text.trim()),
        'gender': _gender == Gender.male ? 'Male' : 'Female',
        'height': double.tryParse(_heightController.text.trim()),
        'weight': double.tryParse(_weightController.text.trim()),
        'chronicConditions': _chronicConditions,
        'bloodPressure': {
          'systolic': int.tryParse(_systolicController.text.trim()),
          'diastolic': int.tryParse(_diastolicController.text.trim()),
        },
        'bloodSugar': double.tryParse(_bloodSugarController.text.trim()),
        'cholesterol': double.tryParse(_cholesterolController.text.trim()),
        'geneticRisk': _geneticRisk,
        'dailySteps': int.tryParse(_dailyStepsController.text.trim()),
        'exerciseFrequency': _exerciseFrequency,
        'sleepHours': double.tryParse(_sleepHoursController.text.trim()),
        'smoking': _smoking,
        'alcohol': _alcohol,
        'dietaryHabit': _dietaryHabit,
        'foodAllergies': _foodAllergiesController.text.trim().isEmpty ? null : _foodAllergiesController.text.trim(),
        'preferredCuisine': _preferredCuisine,
        'foodAversions': _foodAversionsController.text.trim().isEmpty ? null : _foodAversionsController.text.trim(),
        'createdAt': Timestamp.now(),
      };

      // Save to Firestore
      await FirebaseFirestore.instance.collection('elder_health_profiles').add(doc);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Details saved successfully')));

      // Navigate to ElderDashboardScreen and replace current screen
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ElderDashboardScreen()));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving details: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _sectionCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(padding: padding ?? const EdgeInsets.all(12), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        title: const Text('Patient Health Details'),
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
                  _sectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Basic Information', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _ageController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Age'),
                          validator: _requiredNumberValidator,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => setState(() => _gender = Gender.male),
                                style: OutlinedButton.styleFrom(backgroundColor: _gender == Gender.male ? Theme.of(context).colorScheme.primary.withOpacity(0.12) : null),
                                child: const Text('Male'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => setState(() => _gender = Gender.female),
                                style: OutlinedButton.styleFrom(backgroundColor: _gender == Gender.female ? Theme.of(context).colorScheme.primary.withOpacity(0.12) : null),
                                child: const Text('Female'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                            child: TextFormField(
                              controller: _heightController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Height (cm)'),
                              validator: _requiredNumberValidator,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _weightController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Weight (kg)'),
                              validator: _requiredNumberValidator,
                            ),
                          ),
                        ])
                      ],
                    ),
                  ),

                  _sectionCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Health Conditions', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _condChip('Diabetes'),
                          _condChip('Hypertension'),
                          _condChip('Heart Disease'),
                          _condChip('None'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: TextFormField(
                            controller: _systolicController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Systolic'),
                            validator: _requiredNumberValidator,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _diastolicController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Diastolic'),
                            validator: _requiredNumberValidator,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _bloodSugarController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Blood Sugar Level (mg/dL)'),
                        validator: _requiredNumberValidator,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _cholesterolController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Cholesterol Level (mg/dL)'),
                        validator: _requiredNumberValidator,
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Text('Genetic Risk:'),
                        const SizedBox(width: 12),
                        Switch(value: _geneticRisk, onChanged: (v) => setState(() => _geneticRisk = v))
                      ])
                    ]),
                  ),

                  _sectionCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Lifestyle Information', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _dailyStepsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Daily Steps'),
                        validator: _requiredNumberValidator,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _exerciseFrequency,
                        items: const [
                          DropdownMenuItem(value: 'Low', child: Text('Low')),
                          DropdownMenuItem(value: 'Moderate', child: Text('Moderate')),
                          DropdownMenuItem(value: 'High', child: Text('High')),
                        ],
                        onChanged: (v) => setState(() => _exerciseFrequency = v),
                        decoration: const InputDecoration(labelText: 'Exercise Frequency'),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _sleepHoursController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Sleep Hours per night'),
                        validator: _requiredNumberValidator,
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Text('Smoking:'),
                        const SizedBox(width: 12),
                        Switch(value: _smoking, onChanged: (v) => setState(() => _smoking = v)),
                        const SizedBox(width: 24),
                        const Text('Alcohol:'),
                        const SizedBox(width: 12),
                        Switch(value: _alcohol, onChanged: (v) => setState(() => _alcohol = v)),
                      ])
                    ]),
                  ),

                  _sectionCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Dietary Preferences', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, children: [
                        _dietChip('Vegetarian'),
                        _dietChip('Vegan'),
                        _dietChip('Non-Vegetarian'),
                      ]),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _foodAllergiesController,
                        decoration: const InputDecoration(labelText: 'Food Allergies (optional)'),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _preferredCuisine,
                        items: const [
                          DropdownMenuItem(value: 'Indian', child: Text('Indian')),
                          DropdownMenuItem(value: 'Chinese', child: Text('Chinese')),
                          DropdownMenuItem(value: 'Western', child: Text('Western')),
                        ],
                        onChanged: (v) => setState(() => _preferredCuisine = v),
                        decoration: const InputDecoration(labelText: 'Preferred Cuisine'),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _foodAversionsController,
                        decoration: const InputDecoration(labelText: 'Food Aversions (optional)'),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 12),
                  // Buttons
                  Column(children: [
                    // Primary gradient button
                    GestureDetector(
                      onTap: _isLoading ? null : _submit,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary]),
                        ),
                        child: Center(
                          child: Text('Submit Details to Doctor', style: Theme.of(context).primaryTextTheme.labelLarge?.copyWith(color: Colors.white)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(onPressed: _isLoading ? null : _clearForm, child: const Text('Clear Form'))
                  ])
                ],
              ),
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            )
        ],
      ),
    );
  }

  // Widget builders for chips
  Widget _condChip(String label) {
    final selected = _chronicConditions.contains(label);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (v) {
        setState(() {
          if (label == 'None') {
            _chronicConditions.clear();
            if (v) _chronicConditions.add('None');
          } else {
            _chronicConditions.remove('None');
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
