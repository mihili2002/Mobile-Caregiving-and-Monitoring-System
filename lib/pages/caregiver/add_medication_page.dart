import 'package:flutter/material.dart';
import '../../models/routine_models.dart';
import '../../services/routine_service.dart';

class AddMedicationPage extends StatefulWidget {
  final String elderId;
  const AddMedicationPage({Key? key, required this.elderId}) : super(key: key);

  @override
  _AddMedicationPageState createState() => _AddMedicationPageState();
}

class _AddMedicationPageState extends State<AddMedicationPage> {
  final _formKey = GlobalKey<FormState>();
  final _routineService = RoutineService();

  String _drugName = '';
  String _dosage = '';
  String _selectedTiming = 'before_breakfast';
  bool _isLoading = false;

  final Map<String, String> _timingOptions = {
    'before_breakfast': 'Before Breakfast ~ 07:30',
    'after_breakfast': 'After Breakfast ~ 08:30',
    'before_lunch': 'Before Lunch ~ 12:30',
    'after_lunch': 'After Lunch ~ 13:30',
    'before_dinner': 'Before Dinner ~ 18:30',
    'after_dinner': 'After Dinner ~ 19:30',
    'bedtime': 'Bedtime ~ 21:00',
  };

  void _saveForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    // 1. Map Timing to approximate proxy time for AI
    String proxyTime = "08:00"; 
    if (_selectedTiming.contains('lunch')) proxyTime = "13:00";
    if (_selectedTiming.contains('dinner')) proxyTime = "19:00";
    if (_selectedTiming == 'bedtime') proxyTime = "21:00";

    // 2. Create Model
    Medication newMed = Medication(
      elderId: widget.elderId,
      drugName: _drugName,
      dosage: _dosage,
      frequency: ["Daily"], // Defaulting to daily for meal-based meds
      times: [proxyTime], // Proxy for AI
      timing: _selectedTiming,
      isActive: true,
    );

    // 3. Send to Backend
    try {
      final result = await _routineService.addMedication(newMed);
      if (mounted) {
        if (result != null) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Medication Added Successfully")),
          );
        } else {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text("Error: Failed to save medication to database.")),
             );
             setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Medication Manually"),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              decoration: const InputDecoration(
                labelText: "Drug Name",
                hintText: "e.g., Metformin",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.medication),
              ),
              validator: (val) => val!.isEmpty ? "Required" : null,
              onSaved: (val) => _drugName = val!,
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: "Dosage",
                hintText: "e.g., 500mg",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.numbers),
              ),
              validator: (val) => val!.isEmpty ? "Required" : null,
              onSaved: (val) => _dosage = val!,
            ),
            const SizedBox(height: 20),
            
            const Text("Timing Strategy", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedTiming,
                  isExpanded: true,
                  items: _timingOptions.entries.map((e) {
                    return DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedTiming = val!),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Note: AI will adjust reminders based on the Elder's actual meal times.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Save Prescription"),
              ),
            )
          ],
        ),
      ),
    );
  }
}