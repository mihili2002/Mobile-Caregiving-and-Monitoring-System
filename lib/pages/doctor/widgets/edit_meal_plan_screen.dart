import 'package:flutter/material.dart';
import '../../../models/meal_plan_model.dart';

class EditMealPlanScreen extends StatefulWidget {
  final MealPlanModel plan;

  const EditMealPlanScreen({super.key, required this.plan});

  @override
  State<EditMealPlanScreen> createState() => _EditMealPlanScreenState();
}

class _EditMealPlanScreenState extends State<EditMealPlanScreen> {
  late List<_EditableDay> days;

  @override
  void initState() {
    super.initState();

    days = widget.plan.days
        .map((d) => _EditableDay.fromMealPlanDay(d))
        .toList();
  }

  void _save() {
    // Convert editable structure back to MealPlanModel types
    final updatedDays = days.map((ed) {
      return MealPlanDay(
        day: ed.day,
        meals: MealDayMeals(
          breakfast: ed.meals['Breakfast']!.map((e) => MealItem(portion: e.portion, foodName: e.foodName, notes: e.notes)).toList(),
          lunch: ed.meals['Lunch']!.map((e) => MealItem(portion: e.portion, foodName: e.foodName, notes: e.notes)).toList(),
          dinner: ed.meals['Dinner']!.map((e) => MealItem(portion: e.portion, foodName: e.foodName, notes: e.notes)).toList(),
          snacks: ed.meals['Snacks']!.map((e) => MealItem(portion: e.portion, foodName: e.foodName, notes: e.notes)).toList(),
        ),
      );
    }).toList();

    final updated = MealPlanModel(
      id: widget.plan.id,
      elderId: widget.plan.elderId,
      planId: widget.plan.planId,
      status: widget.plan.status,
      startDate: widget.plan.startDate,
      endDate: widget.plan.endDate,
      warnings: widget.plan.warnings,
      nutrientTargets: widget.plan.nutrientTargets,
      days: updatedDays,
    );

    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Meal Plan'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: days.length,
        itemBuilder: (context, idx) {
          final day = days[idx];

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ExpansionTile(
              title: Text('Day ${day.day}'),
              children: [
                ...['Breakfast', 'Lunch', 'Dinner', 'Snacks'].map((mealType) {
                  final list = day.meals[mealType]!;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(mealType, style: const TextStyle(fontWeight: FontWeight.bold)),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  list.add(_EditableMealItem(portion: '', foodName: '', notes: ''));
                                });
                              },
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add'),
                            )
                          ],
                        ),
                        const SizedBox(height: 6),
                        ...list.asMap().entries.map((entry) {
                          final i = entry.key;
                          final item = entry.value;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: TextFormField(
                                    initialValue: item.foodName,
                                    decoration: const InputDecoration(labelText: 'Food'),
                                    onChanged: (v) => item.foodName = v,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    initialValue: item.portion,
                                    decoration: const InputDecoration(labelText: 'Portion'),
                                    onChanged: (v) => item.portion = v,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                                  onPressed: () {
                                    setState(() => list.removeAt(i));
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EditableDay {
  final int day;
  final Map<String, List<_EditableMealItem>> meals;

  _EditableDay({required this.day, required this.meals});

  factory _EditableDay.fromMealPlanDay(MealPlanDay d) {
    List<_EditableMealItem> toEditable(List<MealItem> items) => items.map((m) => _EditableMealItem(portion: m.portion, foodName: m.foodName, notes: m.notes)).toList();

    return _EditableDay(day: d.day, meals: {
      'Breakfast': toEditable(d.meals.breakfast),
      'Lunch': toEditable(d.meals.lunch),
      'Dinner': toEditable(d.meals.dinner),
      'Snacks': toEditable(d.meals.snacks),
    });
  }
}

class _EditableMealItem {
  String portion;
  String foodName;
  String notes;

  _EditableMealItem({required this.portion, required this.foodName, required this.notes});
}
