import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class MedicationsCard extends StatefulWidget {
  const MedicationsCard({super.key});

  @override
  State<MedicationsCard> createState() => _MedicationsCardState();
}

class _MedicationsCardState extends State<MedicationsCard> with SingleTickerProviderStateMixin {
  final FlutterTts _flutterTts = FlutterTts();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<Map<String, dynamic>> _meds = [
    {"name": "Heart Medicine", "dosage": "1 Tablet", "time": "8:00 AM", "taken": true, "status": "Taken"},
    {"name": "Vitamin D", "dosage": "1 Capsule", "time": "9:00 AM", "taken": true, "status": "Taken"},
    {"name": "Blood Thinner", "dosage": "1 Tablet", "time": "1:00 PM", "taken": false, "status": "Next"},
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _speakMeds() async {
    String text = "Your upcoming medication is Blood Thinner at 1:00 PM.";
    await _flutterTts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.medication, color: Colors.blue),
                    SizedBox(width: 8),
                    Text("Medications", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.volume_up, color: Colors.blue),
                  onPressed: _speakMeds,
                  tooltip: "Read Aloud",
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Next Med Alert
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Next Heart Medicine", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900)),
                        Text("1 tablet at 1:00 PM", style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _meds.length,
              itemBuilder: (context, index) {
                final med = _meds[index];
                bool isNext = med['status'] == 'Next';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: med['taken'] ? Colors.green.shade200 : (isNext ? Colors.blue.shade200 : Colors.grey.shade200),
                      ),
                      borderRadius: BorderRadius.circular(16),
                      color: med['taken'] ? Colors.green.shade50 : (isNext ? Colors.blue.shade50 : Colors.white),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(med['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(med['dosage'], style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                          ],
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: med['taken'] ? Colors.green : (isNext ? Colors.blue : Colors.grey[300]),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                med['taken'] ? Icons.check : Icons.access_time,
                                size: 14,
                                color: med['taken'] || isNext ? Colors.white : Colors.grey[700],
                              ),
                              SizedBox(width: 4),
                              Text(
                                med['time'],
                                style: TextStyle(
                                  color: med['taken'] || isNext ? Colors.white : Colors.grey[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
