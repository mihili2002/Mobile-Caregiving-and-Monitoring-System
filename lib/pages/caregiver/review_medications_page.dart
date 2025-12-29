import 'package:flutter/material.dart';
import '../../services/user_service.dart'; // Reuse for baseUrl logic eventually or duplicate
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ReviewMedicationsPage extends StatefulWidget {
  final String elderId;
  final List<dynamic> medications;
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
  late List<dynamic> _meds;
  bool _isSaving = false;

  // Duplicate Base URL Logic for now (or import if refactored)
  String get baseUrl {
    if (kIsWeb) return "http://127.0.0.1:5000";
    if (defaultTargetPlatform == TargetPlatform.android) return "http://10.0.2.2:5000";
    return "http://192.168.8.115:5000";
  }

  @override
  void initState() {
    super.initState();
    _meds = List.from(widget.medications);
  }

  Future<void> _saveMedications() async {
    setState(() => _isSaving = true);
    try {
      final url = Uri.parse('$baseUrl/api/medications/save');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'elder_id': widget.elderId,
          'medications': _meds,
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medications saved successfully!')),
        );
        Navigator.pop(context); // Go back to dashboard or previous screen
        Navigator.pop(context); // Pop twice to clear upload screen too?
      } else {
        throw Exception('Failed to save: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Review Medications")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text("Extraction Method: ${widget.usedMethod}"),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _meds.length,
              itemBuilder: (context, index) {
                final med = _meds[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        TextFormField(
                          initialValue: med['drug_name'],
                          decoration: const InputDecoration(labelText: 'Drug Name'),
                          onChanged: (val) => med['drug_name'] = val,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: med['dosage'],
                                decoration: const InputDecoration(labelText: 'Dosage'),
                                onChanged: (val) => med['dosage'] = val,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                initialValue: med['timing'],
                                decoration: const InputDecoration(labelText: 'Timing'),
                                onChanged: (val) => med['timing'] = val,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveMedications,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Confirm & Save"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
