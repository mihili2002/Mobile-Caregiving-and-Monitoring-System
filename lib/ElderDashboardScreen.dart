import 'package:flutter/material.dart';

class ElderDashboardScreen extends StatelessWidget {
  const ElderDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Elder Dashboard'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Welcome to the Elder Dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 1,
                childAspectRatio: 4,
                mainAxisSpacing: 12,
                children: [
                  _dashCard(context, 'My Meal Plan', Icons.restaurant_menu),
                  _dashCard(context, 'Health Summary', Icons.health_and_safety),
                  _dashCard(context, 'Appointments', Icons.calendar_today),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _dashCard(BuildContext context, String title, IconData icon) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
