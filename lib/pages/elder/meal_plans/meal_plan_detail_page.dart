import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/meal_plan_model.dart';
import '../../../services/meal_plan_service.dart';
import '../../../services/local_notification_service.dart';

class MealPlanDetailPage extends StatefulWidget {
  final String? planId;
  final MealPlanModel? plan;

  const MealPlanDetailPage({
    super.key,
    this.planId,
    this.plan,
  });

  @override
  State<MealPlanDetailPage> createState() => _MealPlanDetailPageState();
}

class _MealPlanDetailPageState extends State<MealPlanDetailPage> {
  final MealPlanService _service = MealPlanService();

  MealPlanModel? _plan;
  bool _loading = true;

  // (1) Today shortcut + (2) Auto-open day
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _dayKeys = {};
  List<bool> _expandedDays = [];

  // (5) Completed states (persisted locally) - per MEAL TYPE
  final Set<String> _completedMealKeys = <String>{};

  // (6) Remind-me times (persisted + real notifications) - per MEAL TYPE
  final Map<String, TimeOfDay> _reminders = <String, TimeOfDay>{};

  // (7) Substitution overrides (local UI-only) - per MEAL TYPE
  final Map<String, String> _substitutions = <String, String>{};

  // -------------------- Local persistence keys --------------------
  String _completedStorageKey(String planId) => "meal_done_keys_$planId";
  String _lastOpenDayStorageKey(String planId) => "meal_last_open_day_$planId";
  String _reminderStorageKey(String planId) => "meal_reminders_$planId";

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      if (widget.plan != null) {
        _plan = widget.plan;
      } else if (widget.planId != null) {
        _plan = await _service.getMealPlanById(widget.planId!);
      }

      if (_plan == null) return;

      // ✅ Restore persisted "Done" state
      await _restoreCompletedMeals(planId: _plan!.id);

      // ✅ Restore persisted reminders + schedule real notifications again
      await _restoreRemindersAndReschedule(planId: _plan!.id);

      // Init expansion states for API-based days
      if (_plan!.days.isNotEmpty) {
        final openIndex = await _chooseAutoOpenDayIndex(_plan!);

        _expandedDays = List<bool>.filled(_plan!.days.length, false);
        _expandedDays[openIndex] = true;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _goToDay(openIndex);
        });
      }
    } catch (e) {
      debugPrint("MealPlanDetail load error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // -------------------- Persistence: restore/save --------------------
  Future<void> _restoreCompletedMeals({required String planId}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_completedStorageKey(planId));
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded =
          (jsonDecode(raw) as List).map((e) => e.toString()).toSet();
      _completedMealKeys
        ..clear()
        ..addAll(decoded);
    } catch (_) {
      // ignore corrupt data
    }
  }

  Future<void> _saveCompletedMeals({required String planId}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_completedMealKeys.toList());
    await prefs.setString(_completedStorageKey(planId), raw);
  }

  Future<void> _saveLastOpenDay(
      {required String planId, required int index}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastOpenDayStorageKey(planId), index);
  }

  Future<int?> _getLastOpenDay({required String planId}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastOpenDayStorageKey(planId));
  }

  // ✅ Reminders persistence (HH:mm)
  String _timeToString(TimeOfDay t) =>
      "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";

  TimeOfDay? _timeFromString(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  Future<void> _saveReminders({required String planId}) async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, String>{};
    _reminders.forEach((k, v) => map[k] = _timeToString(v));
    await prefs.setString(_reminderStorageKey(planId), jsonEncode(map));
  }

  Future<void> _restoreRemindersAndReschedule({required String planId}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_reminderStorageKey(planId));
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;

      _reminders.clear();

      for (final entry in decoded.entries) {
        final k = entry.key.toString();
        final v = entry.value.toString();
        final tod = _timeFromString(v);
        if (tod == null) continue;
        _reminders[k] = tod;
      }

      // Re-schedule notifications for all restored reminders
      for (final entry in _reminders.entries) {
        final mealKey = entry.key;
        final tod = entry.value;

        final mealType = _mealTypeFromMealKey(mealKey);
        final dayNo = _dayNumberFromMealKey(mealKey);
        final notifId = _notificationIdForMealKey(mealKey);

        try {
          await LocalNotificationService.instance.scheduleDaily(
            id: notifId,
            title: "Meal Reminder: $mealType",
            body: "Time to have your $mealType (Day $dayNo).",
            hour: tod.hour,
            minute: tod.minute,
          );
        } catch (e) {
          debugPrint("Reschedule failed for $mealKey: $e");
        }
      }
    } catch (_) {
      // ignore corrupt data
    }
  }

  // -------------------- Helpers --------------------
  String _dateOnly(dynamic dt) {
    try {
      if (dt is DateTime) return dt.toString().split(" ")[0];
      final parsed = DateTime.tryParse(dt.toString());
      if (parsed != null) return parsed.toString().split(" ")[0];
      return dt.toString();
    } catch (_) {
      return dt.toString();
    }
  }

  int _todayIndexFromPlan(MealPlanModel plan) {
    DateTime? start;
    try {
      if (plan.startDate is DateTime) {
        start = plan.startDate as DateTime;
      } else {
        start = DateTime.tryParse(plan.startDate.toString());
      }
    } catch (_) {
      start = null;
    }

    if (start == null) return 0;

    final now = DateTime.now();
    final startOnly = DateTime(start.year, start.month, start.day);
    final todayOnly = DateTime(now.year, now.month, now.day);

    final diff = todayOnly.difference(startOnly).inDays;
    final maxIndex = max(0, plan.days.length - 1);
    return diff.clamp(0, maxIndex);
  }

  void _goToDay(int index) {
    final key = _dayKeys[index];
    final ctx = key?.currentContext;
    if (ctx == null) return;

    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
      alignment: 0.06,
    );
  }

  String _mealEmoji(String title) {
    final t = title.toLowerCase();
    if (t.contains("breakfast")) return "🍳";
    if (t.contains("lunch")) return "🥗";
    if (t.contains("dinner")) return "🍲";
    return "🍌"; // snacks
  }

  TimeOfDay _defaultTimeFor(String mealType) {
    final t = mealType.toLowerCase();
    if (t.contains("breakfast")) return const TimeOfDay(hour: 8, minute: 0);
    if (t.contains("lunch")) return const TimeOfDay(hour: 12, minute: 30);
    if (t.contains("dinner")) return const TimeOfDay(hour: 19, minute: 0);
    return const TimeOfDay(hour: 16, minute: 0); // snacks
  }

  /// Completion key is per meal-type
  String _mealTypeKey(int dayNumber, String mealType) {
    return "d$dayNumber|$mealType";
  }

  int _dayNumberFromMealKey(String mealKey) {
    final parts = mealKey.split('|');
    if (parts.isEmpty) return 0;
    final d = parts.first.trim(); // d1
    if (!d.startsWith('d')) return 0;
    return int.tryParse(d.substring(1)) ?? 0;
  }

  String _mealTypeFromMealKey(String mealKey) {
    final parts = mealKey.split('|');
    if (parts.length < 2) return "Meal";
    return parts[1].trim();
  }

  int _notificationIdForMealKey(String mealKey) {
    // stable positive int ID, same every time for the same mealKey
    return mealKey.hashCode & 0x7fffffff;
  }

  List<String> _previewNames(List<MealItem> items) =>
      items.map((e) => e.foodName).toList();

  // -------------------- ✅ choose which day to auto-open --------------------
  Future<int> _chooseAutoOpenDayIndex(MealPlanModel plan) async {
    final planId = plan.id;

    final lastOpen = await _getLastOpenDay(planId: planId);
    if (lastOpen != null && lastOpen >= 0 && lastOpen < plan.days.length) {
      if (!_isDayFullyDone(plan.days[lastOpen])) {
        return lastOpen;
      }
    }

    for (int i = 0; i < plan.days.length; i++) {
      if (!_isDayFullyDone(plan.days[i])) return i;
    }

    final allDone = plan.days.isNotEmpty && plan.days.every(_isDayFullyDone);
    if (allDone) return max(0, plan.days.length - 1);

    return _todayIndexFromPlan(plan);
  }

  bool _isDayFullyDone(MealPlanDay dayObj) {
    final dayNo = dayObj.day;

    bool isMealTypeDone(String mealType, List<MealItem> items) {
      if (items.isEmpty) return true;
      final k = _mealTypeKey(dayNo, mealType);
      return _completedMealKeys.contains(k);
    }

    return isMealTypeDone("Breakfast", dayObj.meals.breakfast) &&
        isMealTypeDone("Lunch", dayObj.meals.lunch) &&
        isMealTypeDone("Dinner", dayObj.meals.dinner) &&
        isMealTypeDone("Snacks", dayObj.meals.snacks);
  }

  // -------------------- (6) Remind me (REAL local notification) --------------------
  Future<void> _setReminder({
    required String mealKey,
    required String mealType,
  }) async {
    final initial = _reminders[mealKey] ?? _defaultTimeFor(mealType);

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: "Set reminder time",
    );

    if (picked == null) return;

    setState(() => _reminders[mealKey] = picked);

    debugPrint(
  "Scheduling notification at ${picked.hour}:${picked.minute} for mealKey=$mealKey"
);


    

    if (_plan != null) {
      await _saveReminders(planId: _plan!.id);
    }

    final dayNo = _dayNumberFromMealKey(mealKey);
    final notifId = _notificationIdForMealKey(mealKey);

    try {
      await LocalNotificationService.instance.scheduleDaily(
        id: notifId,
        title: "Meal Reminder: $mealType",
        body: "Time to have your $mealType (Day $dayNo).",
        hour: picked.hour,
        minute: picked.minute,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Notification scheduled for ${picked.format(context)}"),
        ),
      );
    } catch (e) {
      debugPrint("Notification schedule error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to schedule notification. Check setup."),
        ),
      );
    }
  }

  Future<void> _clearReminder({
    required String mealKey,
    required String mealType,
  }) async {
    final notifId = _notificationIdForMealKey(mealKey);

    setState(() => _reminders.remove(mealKey));

    if (_plan != null) {
      await _saveReminders(planId: _plan!.id);
    }

    try {
      await LocalNotificationService.instance.cancel(notifId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Reminder cleared for $mealType")),
      );
    } catch (e) {
      debugPrint("Cancel notification error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to cancel reminder.")),
      );
    }
  }

  // -------------------- (7) Substitution UI --------------------
  List<String> _suggestAlternatives(String mealType, String foodName) {
    final name = foodName.toLowerCase();

    final base = <String>[
      "Add more vegetables (steamed/boiled)",
      "Choose low-oil / less spicy version",
      "Smaller portion + extra water",
    ];

    if (name.contains("rice")) {
      return [
        "Red rice (smaller portion)",
        "Brown rice",
        "String hoppers / roti (whole grain if available)",
        ...base,
      ];
    }

    if (name.contains("fried") || name.contains("deep")) {
      return [
        "Grilled version",
        "Steamed version",
        "Baked version",
        ...base,
      ];
    }

    if (name.contains("chicken")) {
      return [
        "Fish (grilled/steamed)",
        "Dhal / lentil curry",
        "Egg (boiled/omelette low oil)",
        ...base,
      ];
    }

    if (name.contains("milk") || name.contains("yogurt")) {
      return [
        "Low-fat milk",
        "Curd (plain)",
        "Plant milk (if recommended)",
        ...base,
      ];
    }

    final type = mealType.toLowerCase();
    if (type.contains("breakfast")) {
      return [
        "Oat porridge",
        "Whole grain roti + dhal",
        "Fruit + curd (plain)",
        ...base,
      ];
    }
    if (type.contains("lunch") || type.contains("dinner")) {
      return [
        "More vegetables + dhal",
        "Fish curry (low oil) + salad",
        "Soup + small carb portion",
        ...base,
      ];
    }

    return [
      "Fruit (1 portion)",
      "Nuts (small handful)",
      "Plain tea + light snack",
      ...base,
    ];
  }

  void _openSwapSheet({
    required String mealKey,
    required String mealType,
    required String foodName,
  }) {
    final alternatives = _suggestAlternatives(mealType, foodName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              "Swap / Alternatives",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: "Close",
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "For: $foodName",
                          style:
                              TextStyle(color: Colors.black.withOpacity(0.70)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                        itemCount: alternatives.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, idx) {
                          final a = alternatives[idx];
                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              setState(() => _substitutions[mealKey] = a);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text("Selected alternative: $a")),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.black.withOpacity(0.06),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.swap_horiz, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      a,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        height: 1.25,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF11BFA8);
    const bg = Color(0xFFF6F3FF);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_plan == null) {
      return const Scaffold(
        body: Center(child: Text("Meal plan not found")),
      );
    }

    final plan = _plan!;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: teal,
        foregroundColor: Colors.white,
        title: const Text("Meal Plan Details"),
      ),
      body: SafeArea(
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(14),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: teal,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Plan ID: ${plan.id}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Status: ${plan.status}",
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Dates: ${_dateOnly(plan.startDate)} → ${_dateOnly(plan.endDate)}",
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (plan.days.isNotEmpty) ...[
              _todayShortcutCard(teal: teal, plan: plan),
              const SizedBox(height: 14),
            ],

            if (plan.days.isNotEmpty)
              ...List.generate(plan.days.length, (index) {
                final dayObj = plan.days[index];
                final key = _dayKeys.putIfAbsent(index, () => GlobalKey());
                return Container(
                  key: key,
                  child: _dayAccordion(dayObj, index),
                );
              })
            else
              ...plan.meals.keys.map((dayKey) {
                final dayMeals = plan.meals[dayKey] as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ExpansionTile(
                    title: Text(
                      dayKey,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    childrenPadding: const EdgeInsets.all(14),
                    children: [
                      _simpleMealList("Breakfast", dayMeals["Breakfast"]),
                      _simpleMealList("Lunch", dayMeals["Lunch"]),
                      _simpleMealList("Dinner", dayMeals["Dinner"]),
                      _simpleMealList("Snacks", dayMeals["Snacks"]),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  // --- unchanged below (today card / day accordion / meal section / chips / simple list) ---
  // (I kept them exactly the same except adding the "Clear reminder" chip.)

  Widget _todayShortcutCard({
    required Color teal,
    required MealPlanModel plan,
  }) {
    final todayIndex = _todayIndexFromPlan(plan);
    final day = plan.days[todayIndex];

    final breakfast = _previewNames(day.meals.breakfast);
    final lunch = _previewNames(day.meals.lunch);
    final dinner = _previewNames(day.meals.dinner);

    Widget line(String title, List<String> items) {
      final text = items.isEmpty ? "-" : items.take(2).join(", ");
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
            _mealEmoji(title),
             style: const TextStyle(
             fontSize: 20,
             height: 1,
          ),
             textAlign: TextAlign.center,
         ),
            const SizedBox(width: 10),
            SizedBox(
          width: 92,
          child: Text(
          title,
          style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w900,
          fontSize: 15,
        ),
      ),
    ),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                )
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today • Day ${day.day}",
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            "Tap “Go to Today” to open your meals.",
            style: TextStyle(color: Colors.black.withOpacity(0.70), fontSize: 14),
          ),
          line("Breakfast", breakfast),
          line("Lunch", lunch),
          line("Dinner", dinner),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                setState(() {
                  for (int i = 0; i < _expandedDays.length; i++) {
                    _expandedDays[i] = (i == todayIndex);
                  }
                });

                await _saveLastOpenDay(planId: plan.id, index: todayIndex);

                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _goToDay(todayIndex));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: teal,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                "Go to Today",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayAccordion(MealPlanDay dayObj, int index) {
    final expanded = (index < _expandedDays.length) ? _expandedDays[index] : false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: expanded,
          onExpansionChanged: (val) async {
            if (index >= _expandedDays.length) return;
            setState(() => _expandedDays[index] = val);
            if (val && _plan != null) {
              await _saveLastOpenDay(planId: _plan!.id, index: index);
            }
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          trailing: Icon(
            expanded ? Icons.expand_less : Icons.expand_more,
            size: 30,
            color: Colors.black.withOpacity(0.70),
          ),
          title: Text(
            "Day ${dayObj.day}",
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          children: [
            _mealSection(dayObj.day, "Breakfast", dayObj.meals.breakfast),
            _mealSection(dayObj.day, "Lunch", dayObj.meals.lunch),
            _mealSection(dayObj.day, "Dinner", dayObj.meals.dinner),
            _mealSection(dayObj.day, "Snacks", dayObj.meals.snacks),
          ],
        ),
      ),
    );
  }

  Widget _mealSection(int dayNumber, String title, List<MealItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    final sectionKey = _mealTypeKey(dayNumber, title);
    final done = _completedMealKeys.contains(sectionKey);
    final reminder = _reminders[sectionKey];
    final swap = _substitutions[sectionKey];

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: DefaultTextStyle.merge(
      style: TextStyle(
        color: done?Colors.grey : Colors.black,
      ),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(_mealEmoji(title), style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () async {
                    if (_plan == null) return;

                    setState(() {
                      if (done) {
                        _completedMealKeys.remove(sectionKey);
                      } else {
                        _completedMealKeys.add(sectionKey);
                      }
                    });

                    await _saveCompletedMeals(planId: _plan!.id);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: done ? Colors.green.shade100 : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: done
                            ? Colors.green.shade700.withOpacity(0.25)
                            : Colors.black.withOpacity(0.10),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          done ? Icons.check_circle : Icons.circle_outlined,
                          size: 18,
                          color: done
                              ? Colors.green.shade800
                              : Colors.black.withOpacity(0.55),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          done ? "Done" : "Mark",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            color: done
                                ? Colors.green.shade800
                                : Colors.black.withOpacity(0.70),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (swap != null && swap.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.25)),
                ),
                child: Text(
                  "Swap selected: $swap",
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],

            ...items.map((i) {
              return Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i.foodName,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        decoration: done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Portion: ${i.portion}",
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.75),
                        fontSize: 14,
                      ),
                    ),
                    if (i.notes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        "Notes: ${i.notes}",
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.70),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),

            const SizedBox(height: 4),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                // _actionChip(
                //   icon: Icons.alarm,
                //   label: reminder == null
                //       ? "Remind me"
                //       : "Reminder: ${reminder.format(context)}",
                //   onTap: () => _setReminder(mealKey: sectionKey, mealType: title),
                // ),

                // ✅ NEW: Clear reminder cancels the REAL notification + removes saved time
                // if (reminder != null)
                //   _actionChip(
                //     icon: Icons.notifications_off,
                //     label: "Clear reminder",
                //     onTap: () => _clearReminder(mealKey: sectionKey, mealType: title),
                //   ),

                _actionChip(
                  icon: Icons.swap_horiz,
                  label: "Swap",
                  onTap: () => _openSwapSheet(
                    mealKey: sectionKey,
                    mealType: title,
                    foodName: items.first.foodName,
                  ),
                ),
                if (_substitutions.containsKey(sectionKey))
                  _actionChip(
                    icon: Icons.clear,
                    label: "Clear swap",
                    onTap: () => setState(() => _substitutions.remove(sectionKey)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.black.withOpacity(0.10)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.black.withOpacity(0.70)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _simpleMealList(String title, dynamic list) {
    final items = (list is List) ? list : [];
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_mealEmoji(title), style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map(
            (e) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                "• ${e.toString()}",
                style: TextStyle(
                  color: Colors.black.withOpacity(0.78),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
