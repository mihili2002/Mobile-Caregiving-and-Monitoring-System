import 'package:flutter/material.dart';
import '../../models/routine_models.dart';
import '../../services/routine_service.dart';

class ElderMedicationsPage extends StatefulWidget {
  final String elderId;
  final String elderName;

  const ElderMedicationsPage({
    super.key,
    required this.elderId,
    required this.elderName,
  });

  @override
  State<ElderMedicationsPage> createState() => _ElderMedicationsPageState();
}

class _ElderMedicationsPageState extends State<ElderMedicationsPage> {
  final RoutineService _routineService = RoutineService();
  bool _isLoading = true;
  List<Medication> _medications = [];

  @override
  void initState() {
    super.initState();
    _loadMedications();
  }

  Future<void> _loadMedications() async {
    try {
      final meds = await _routineService.getMedicationsByElderId(widget.elderId);
      if (mounted) {
        setState(() {
          _medications = meds;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading medications: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.elderName}\'s Medications'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _medications.isEmpty
              ? const Center(child: Text("No active medications found."))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _medications.length,
                  itemBuilder: (context, index) {
                    final med = _medications[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.medication, color: Colors.blue),
                        title: Text(med.drugName), // Fixed: uses drugName
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // FIX: Handling nullable dosage
                            Text('Dosage: ${med.dosage ?? "Not specified"}'), 
                            // FIX: Handling nullable frequency
                            Text('Frequency: ${_formatFrequency(med.frequency)}'), 
                            Text('Times: ${med.times?.join(", ") ?? "Not scheduled"}'), 
                            const SizedBox(height: 4),
                            Text(
                              'Valid: ${med.startDate ?? "N/A"} to ${med.endDate ?? "N/A"}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
    );
  }

  String _formatFrequency(List<String>? frequency) {
    if (frequency == null || frequency.isEmpty) return "Not specified";
    if (frequency.contains('Daily')) return 'Daily';
    return frequency.join(', ');
  }
}