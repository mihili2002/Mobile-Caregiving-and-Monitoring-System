import 'package:flutter/material.dart';
import '../../models/routine_models.dart';
import '../../services/routine_service.dart';

class AssignTherapyPage extends StatefulWidget {
  final String elderId;
  final String? elderName;
  const AssignTherapyPage({super.key, required this.elderId, this.elderName});

  @override
  State<AssignTherapyPage> createState() => _AssignTherapyPageState();
}

class _AssignTherapyPageState extends State<AssignTherapyPage> {
  final _formKey = GlobalKey<FormState>();
  final RoutineService _routineService = RoutineService();
  
  String _activityName = '';
  String _duration = '';
  String _instructions = '';
  bool _isLoading = false;

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    // Create Model
    TherapistActivity newActivity = TherapistActivity(
      elderId: widget.elderId,
      activityName: _activityName,
      duration: _duration,
      assignedTime: "Flexible",
      isActive: true,
    );

    try {
      await _routineService.addTherapistActivity(newActivity);
      if (mounted) {
         Navigator.pop(context);
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Therapy Assigned!")));
      }
    } catch (e) {
      if (mounted) {
         setState(() => _isLoading = false);
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Assign Therapy for ${widget.elderName ?? 'Elder'}"),
        backgroundColor: Colors.teal,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              decoration: const InputDecoration(labelText: "Activity Name", hintText: "e.g. Leg Lifts"),
              validator: (v) => v!.isEmpty ? "Required" : null,
              onSaved: (v) => _activityName = v!,
            ),
             const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(labelText: "Duration", hintText: "e.g. 10 mins"),
              validator: (v) => v!.isEmpty ? "Required" : null,
              onSaved: (v) => _duration = v!,
            ),
             const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(labelText: "Instructions (Optional)", hintText: "e.g. Do slowly while seated"),
              maxLines: 3,
              onSaved: (v) => _instructions = v ?? '',
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              child: _isLoading ? const CircularProgressIndicator() : const Text("Assign Activity"),
            ),
          ],
        ),
      ),
    );
  }
}
