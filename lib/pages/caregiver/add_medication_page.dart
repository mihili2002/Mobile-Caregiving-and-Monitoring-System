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
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
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

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          // Ensure end date is not before start date
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 1));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

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
      startDate: _startDate.toIso8601String().split('T')[0],
      endDate: _endDate.toIso8601String().split('T')[0],
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
            const SizedBox(height: 20),
            const Text("Duration Period", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, true),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: "Start Date",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text("${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}"),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, false),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: "End Date",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.event),
                      ),
                      child: Text("${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}"),
                    ),
                  ),
                ),
              ],
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