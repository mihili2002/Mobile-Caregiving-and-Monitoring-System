import 'package:flutter/material.dart';

class DailyTasksCard extends StatefulWidget {
  const DailyTasksCard({super.key});

  @override
  State<DailyTasksCard> createState() => _DailyTasksCardState();
}

class _DailyTasksCardState extends State<DailyTasksCard> {
  // Mock data for now
  final List<Map<String, dynamic>> _tasks = [
    {"title": "Morning Walk", "time": "7:00 AM", "completed": true, "period": "Morning", "icon": Icons.directions_walk},
    {"title": "Blood Pressure", "time": "9:00 AM", "completed": true, "period": "Morning", "icon": Icons.favorite},
    {"title": "Breakfast", "time": "9:30 AM", "completed": true, "period": "Morning", "icon": Icons.free_breakfast},
    {"title": "Read Book", "time": "2:00 PM", "completed": false, "period": "Afternoon", "icon": Icons.menu_book},
    {"title": "Afternoon Nap", "time": "3:00 PM", "completed": false, "period": "Afternoon", "icon": Icons.bed},
  ];

  double get _progress {
    int completed = _tasks.where((t) => t['completed']).length;
    return completed / _tasks.length;
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
                Icon(Icons.check_circle_outline, color: Colors.green),
                SizedBox(width: 8),
                Text("Daily Tasks", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 8),
            Text(
              "${(_progress * 100).toInt()}% completed",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 8,
                backgroundColor: Colors.green.shade50,
                color: Colors.green,
              ),
            ),
            SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        task['completed'] = !task['completed'];
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: task['completed'] ? Colors.green.shade200 : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        color: task['completed'] ? Colors.green.shade50 : Colors.white,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: task['completed'] ? Colors.green : Colors.grey.shade300,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              task['completed'] ? Icons.check : Icons.circle_outlined,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task['title'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    decoration: task['completed'] ? TextDecoration.lineThrough : null,
                                    color: task['completed'] ? Colors.green.shade800 : Colors.black87,
                                  ),
                                ),
                                Text(
                                  task['time'],
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(task['icon'], size: 12, color: Colors.orange.shade800),
                                SizedBox(width: 4),
                                Text(
                                  task['period'],
                                  style: TextStyle(color: Colors.orange.shade800, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
