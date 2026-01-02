import 'package:flutter/material.dart';

class MealDayAccordion extends StatelessWidget {
  final String day;
  final Map<String, dynamic> meals;

  const MealDayAccordion({
    super.key,
    required this.day,
    required this.meals,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.6,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        title: Text(day, style: const TextStyle(fontWeight: FontWeight.w900)),
        childrenPadding: const EdgeInsets.only(bottom: 12),
        children: [
          _mealSection("🍳 Breakfast", meals["Breakfast"]),
          _mealSection("🍛 Lunch", meals["Lunch"]),
          _mealSection("🍲 Dinner", meals["Dinner"]),
          _mealSection("🍎 Snacks", meals["Snacks"]),
        ],
      ),
    );
  }

  Widget _mealSection(String label, dynamic items) {
    final List<dynamic> list = (items is List) ? items : [];

    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          "$label: Not provided",
          style: TextStyle(color: Colors.black.withOpacity(0.55)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ...list.map(
                (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("• ", style: TextStyle(fontSize: 16)),
                  Expanded(child: Text(item.toString())),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
