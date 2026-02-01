import 'package:flutter/material.dart';
import '../../../models/user_model.dart';

class ScheduleTherapistMeetingPage extends StatefulWidget {
  final AppUser user;
  const ScheduleTherapistMeetingPage({super.key, required this.user});

  @override
  State<ScheduleTherapistMeetingPage> createState() => _ScheduleTherapistMeetingPageState();
}

class _ScheduleTherapistMeetingPageState extends State<ScheduleTherapistMeetingPage> {
  DateTime? _date;
  TimeOfDay? _time;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _submit() {
    if (_date == null || _time == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please pick date and time.")),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ Meeting scheduled !")),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final dateText = _date == null ? "Pick a date" : "${_date!.year}-${_date!.month}-${_date!.day}";
    final timeText = _time == null ? "Pick a time" : _time!.format(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Schedule Meeting")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.person),
                title: const Text("Elder"),
                subtitle: Text(widget.user.name ?? widget.user.email),
              ),
            ),
            const SizedBox(height: 12),

            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_month),
                title: Text(dateText),
                trailing: const Icon(Icons.edit_calendar),
                onTap: _pickDate,
              ),
            ),
            const SizedBox(height: 10),

            Card(
              child: ListTile(
                leading: const Icon(Icons.access_time),
                title: Text(timeText),
                trailing: const Icon(Icons.schedule),
                onTap: _pickTime,
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _noteController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: "Note to therapist (optional)",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check_circle),
                label: const Text("Confirm Meeting "),
              ),
            ),
          ],
        ),
      ),
    );
  }
}