import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AppointmentsCard extends StatelessWidget {
  const AppointmentsCard({super.key});

  Future<void> _makeCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
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
              children: [
                Icon(Icons.calendar_month, color: Colors.indigo),
                SizedBox(width: 8),
                Text("Appointments", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 16),
            _buildAppointmentItem(
              title: "General Checkup",
              doctor: "Dr. Sarah Johnson",
              date: "Today at 2:30 PM",
              location: "City Health Clinic",
              type: "Checkup",
              color: Colors.teal,
              phoneNumber: "555-0123",
            ),
            Divider(height: 32),
            _buildAppointmentItem(
              title: "Cardiology Follow-up",
              doctor: "Dr. Michael Chen",
              date: "Tomorrow at 10:00 AM",
              location: "Heart Care Center",
              type: "Specialist",
              color: Colors.orange,
              phoneNumber: "555-0199",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentItem({
    required String title,
    required String doctor,
    required String date,
    required String location,
    required String type,
    required Color color,
    required String phoneNumber,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(
                type,
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.person_outline, size: 14, color: Colors.grey),
            SizedBox(width: 4),
            Text(doctor, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          ],
        ),
        SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.access_time, size: 14, color: Colors.grey),
            SizedBox(width: 4),
            Text(date, style: TextStyle(color: Colors.grey[800], fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _makeCall(phoneNumber),
                icon: Icon(Icons.call, size: 18),
                label: Text("Call Clinic"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text("View Details", style: TextStyle(color: Colors.black87)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
