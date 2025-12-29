import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyFooter extends StatelessWidget {
  final String emergencyContactName;
  final String emergencyContactNumber;

  const EmergencyFooter({
    super.key,
    required this.emergencyContactName,
    required this.emergencyContactNumber,
  });

  Future<void> _callEmergency() async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: emergencyContactNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 40),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(32), // More rounded
        border: Border.all(color: Colors.red.shade200, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.red.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
        ]
      ),
      child: Column(
        children: [
          Row(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               Icon(Icons.warning_amber_rounded, color: Colors.red.shade900, size: 32),
               const SizedBox(width: 8),
               Text(
                 "In Case of Emergency",
                 style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 20),
               ),
             ],
          ),
          const SizedBox(height: 16),
          Text(
             "Contact: $emergencyContactName",
             style: TextStyle(color: Colors.red.shade700, fontSize: 18),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 64, // Taller button
            child: ElevatedButton.icon(
              onPressed: _callEmergency,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 6,
                shadowColor: Colors.red.withOpacity(0.4),
              ),
              icon: const Icon(Icons.phone_in_talk, size: 32),
              label: const Text("CALL FOR HELP", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
