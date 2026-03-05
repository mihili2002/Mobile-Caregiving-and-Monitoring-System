import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/routine_models.dart';
import '../../services/routine_service.dart';
import 'add_medication_page.dart';
import 'ai_med_tracker/upload_prescription_page.dart';

class ElderMedicationsPage extends StatefulWidget {
  final AppUser elder;
  final AppUser caregiver;

  const ElderMedicationsPage({
    super.key,
    required this.elder,
    required this.caregiver,
  });

  @override
  State<ElderMedicationsPage> createState() => _ElderMedicationsPageState();
}

class _ElderMedicationsPageState extends State<ElderMedicationsPage> {
  final _routineService = RoutineService();
  List<Medication> _medications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedications();
  }

  Future<void> _loadMedications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final medications =
          await _routineService.getMedicationsByElderId(widget.elder.uid);
      if (mounted) {
        setState(() {
          _medications = medications;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading medications: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteMedication(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Medication'),
        content: const Text('Are you sure you want to delete this medication?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _routineService.deleteMedication(_medications[index]);
        if (mounted) {
          setState(() {
            _medications.removeAt(index);
          });
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Medication deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting medication: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.elder.name ?? "Elder"} - Medications',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Upload Prescription',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      UploadPrescriptionPage(elderId: widget.elder.uid),
                ),
              ).then((_) => _loadMedications());
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.purple.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _medications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.medical_information_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No medications added',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap the + button to add a medication',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      UploadPrescriptionPage(elderId: widget.elder.uid),
                                ),
                              ).then((_) => _loadMedications());
                            },
                            icon: const Icon(Icons.upload_file),
                            label: const Text("Upload Prescription / Scan"),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              textStyle: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadMedications,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (_medications.any((m) => !m.isOverdue)) ...[
                            _buildSectionHeader('Current Medications', Icons.check_circle_outline, Colors.green),
                            const SizedBox(height: 8),
                            ..._medications
                                .asMap()
                                .entries
                                .where((e) => !e.value.isOverdue)
                                .map((e) => _buildMedicationCard(e.key)),
                            const SizedBox(height: 24),
                          ],
                          if (_medications.any((m) => m.isOverdue)) ...[
                            _buildSectionHeader('Past Medications', Icons.history, Colors.grey),
                            const SizedBox(height: 8),
                            ..._medications
                                .asMap()
                                .entries
                                .where((e) => e.value.isOverdue)
                                .map((e) => _buildMedicationCard(e.key)),
                          ],
                        ],
                      ),
                    ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.purple,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AddMedicationPage(elderId: widget.elder.uid),
            ),
          ).then((_) => _loadMedications());
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildMedicationCard(int index) {
    final med = _medications[index];
    final frequencyText =
        (med.frequency != null && med.frequency!.contains('Daily')) 
            ? 'Daily' 
            : (med.frequency?.join(', ') ?? 'Not specified');

    final isOverdue = med.isOverdue;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isOverdue 
              ? [
                  Colors.grey.withOpacity(0.1),
                  Colors.grey.withOpacity(0.05),
                ]
              : [
                  Colors.purple.withOpacity(0.1),
                  Colors.purple.withOpacity(0.05),
                ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            med.drugName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isOverdue ? Colors.grey[700] : Colors.black,
                            ),
                          ),
                          if (isOverdue) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.orange),
                              ),
                              child: const Text(
                                "OVERDUE",
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        med.dosage ?? 'No dosage info',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red,
                  onPressed: () => _deleteMedication(index),
                  tooltip: 'Delete medication',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 20,
                  color: isOverdue ? Colors.grey : Colors.purple,
                ),
                const SizedBox(width: 8),
                Text(
                  frequencyText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isOverdue ? Colors.grey : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 20,
                  color: isOverdue ? Colors.grey : Colors.purple,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    med.times?.join(', ') ?? 'No times set',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isOverdue ? Colors.grey : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.date_range,
                  size: 20,
                  color: isOverdue ? Colors.grey : Colors.purple,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${med.startDate ?? "N/A"} to ${med.endDate ?? "N/A"}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isOverdue ? Colors.grey : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}