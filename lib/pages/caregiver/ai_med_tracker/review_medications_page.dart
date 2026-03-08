import 'package:flutter/material.dart';
import '../../../models/medication_model.dart';
import '../../../services/ai_med_extraction_service.dart';
import 'edit_medication_page.dart';

class ReviewMedicationsPage extends StatefulWidget {
  final String elderId;
  final List<MedicationModel> medications;
  final String usedMethod;

  const ReviewMedicationsPage({
    super.key,
    required this.elderId,
    required this.medications,
    required this.usedMethod,
  });

  @override
  State<ReviewMedicationsPage> createState() => _ReviewMedicationsPageState();
}

class _ReviewMedicationsPageState extends State<ReviewMedicationsPage> {
  late List<MedicationModel> _meds;
  final _aiService = AiMedExtractionService();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _meds = List.from(widget.medications);
  }

  void _removeMed(int index) {
    setState(() {
      _meds.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (_meds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot save an empty medication list. Please add medications manually or try scanning again.")),
      );
      setState(() => _saving = false);
      return;
    }
    try {
      await _aiService.saveMedications(
        elderId: widget.elderId,
        medications: _meds,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Prescription saved successfully!")),
      );
      // Navigate back to medications page (pop ReviewMedicationsPage and UploadPrescriptionPage)
      Navigator.of(context).pop();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving: $e")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Review Medications"),
        actions: [
          if (_meds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saving ? null : _save,
            ),
        ],
      ),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _meds.length,
                    itemBuilder: (context, index) {
                      final med = _meds[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ListTile(
                          title: Text(med.drugName),
                          subtitle: Text("${med.dosage} • ${med.timing}"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EditMedicationPage(med: med),
                                    ),
                                  );
                                  if (result != null && result is MedicationModel) {
                                    setState(() {
                                      _meds[index] = result;
                                    });
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeMed(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: (_saving || _meds.isEmpty) ? null : _save,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 18),
            backgroundColor: _meds.isEmpty ? Colors.grey : null,
          ),
          child: Text(_meds.isEmpty ? "No Medications Detected" : "Confirm & Save"),
        ),
      ),
    );
  }
}