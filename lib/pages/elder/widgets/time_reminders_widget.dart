import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TimeRemindersWidget extends StatefulWidget {
  const TimeRemindersWidget({super.key});

  @override
  State<TimeRemindersWidget> createState() => _TimeRemindersWidgetState();
}

class _TimeRemindersWidgetState extends State<TimeRemindersWidget> {
  bool _masterToggle = true;
  final List<String> _times = ['8:00 AM', '12:00 PM', '3:00 PM', '6:00 PM', '9:00 PM'];
  Set<String> _activeReminders = {'8:00 AM', '6:00 PM'};

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _masterToggle = prefs.getBool('reminders_master') ?? true;
      final saved = prefs.getStringList('active_reminders');
      if (saved != null) {
        _activeReminders = saved.toSet();
      }
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminders_master', _masterToggle);
    await prefs.setStringList('active_reminders', _activeReminders.toList());
  }

  void _toggleReminder(String time) {
    setState(() {
      if (_activeReminders.contains(time)) {
        _activeReminders.remove(time);
      } else {
        _activeReminders.add(time);
      }
    });
    _savePreferences();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.access_alarm, color: Colors.teal),
                  SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Time Reminders",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        "Get alerts for basic announcements",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              Switch(
                value: _masterToggle,
                activeColor: Colors.teal,
                onChanged: (val) {
                  setState(() => _masterToggle = val);
                  _savePreferences();
                },
              ),
            ],
          ),
          if (_masterToggle) ...[
            const SizedBox(height: 16),
            Text("Choose reminder times:", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _times.map((time) {
                final isActive = _activeReminders.contains(time);
                return InkWell(
                  onTap: () => _toggleReminder(time),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.white : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isActive ? Colors.teal : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: isActive ? [
                        BoxShadow(color: Colors.teal.withOpacity(0.1), blurRadius: 4, offset: Offset(0, 2))
                      ] : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isActive ? Icons.check : Icons.add,
                          size: 16,
                          color: isActive ? Colors.teal : Colors.grey,
                        ),
                        SizedBox(width: 6),
                        Text(
                          time,
                          style: TextStyle(
                            color: isActive ? Colors.teal : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ]
        ],
      ),
    );
  }
}
