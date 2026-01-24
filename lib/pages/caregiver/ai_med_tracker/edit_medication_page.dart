import 'package:flutter/material.dart';
import '../../../models/medication_model.dart';

class EditMedicationPage extends StatefulWidget {
  final MedicationModel med;
  const EditMedicationPage({super.key, required this.med});

  @override
  State<EditMedicationPage> createState() => _EditMedicationPageState();
}

class _EditMedicationPageState extends State<EditMedicationPage> {
  late TextEditingController _name;
  late TextEditingController _dosage;

  final timingOptions = const [
    "before_meal",
    "after_meal",
    "with_meal",
    "unknown",
  ];

  String timing = "unknown";

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.med.drugName);
    _dosage = TextEditingController(text: widget.med.dosage);
    timing = widget.med.timing;
    if (!timingOptions.contains(timing)) timing = "unknown";
  }

  @override
  void dispose() {
    _name.dispose();
    _dosage.dispose();
    super.dispose();
  }

  void _save() {
    final updated = MedicationModel(
      drugName: _name.text.trim(),
      dosage: _dosage.text.trim(),
      frequency: widget.med.frequency,
      timing: timing,
      meals: widget.med.meals,
      duration: widget.med.duration,
      notes: widget.med.notes,
    );
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Prescription")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: "Drug Name",
                prefixIcon: Icon(Icons.add_box_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dosage,
              decoration: const InputDecoration(
                labelText: "Dosage",
                prefixIcon: Icon(Icons.numbers),
              ),
            ),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Timing Strategy", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: timing,
              items: timingOptions
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => timing = v ?? "unknown"),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Note: AI will adjust reminders based on the Elder's actual meal times.",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text("Save Prescription"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
