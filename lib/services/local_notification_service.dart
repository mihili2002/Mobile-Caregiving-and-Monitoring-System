import 'package:flutter/material.dart'; // Needed for debugPrint
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // init timezone database
    tzdata.initializeTimeZones();

    debugPrint("LocalNotificationService initialized");

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    

    await _plugin.initialize(initSettings);

    debugPrint("FlutterLocalNotificationsPlugin initialized");

    // Android 13+ permission
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

        debugPrint("Notification permission requested (Android 13+)");


  }

  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {

    //DEBUG PRINTS
    debugPrint("---------------------------------------------------");
    debugPrint("📌 scheduleDaily() CALLED");
    debugPrint("Notification ID: $id");
    debugPrint("Title: $title");
    debugPrint("Body: $body");
    debugPrint("Requested Time: $hour:$minute");

  
  
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

     debugPrint("Initial Scheduled Time: $scheduled");

  
    // if time already passed today, schedule for tomorrow
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
      debugPrint("⏩ Time already passed → Rescheduled for tomorrow: $scheduled");
    }

    const androidDetails = AndroidNotificationDetails(
      'meal_reminders',
      'Meal Reminders',
      channelDescription: 'Reminders to eat meals',
      importance: Importance.max,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    debugPrint("Calling zonedSchedule() now...");

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // repeats daily at same time
    );

    debugPrint("Notification Scheduled Successfully!");
    debugPrint("Scheduled Final Time: $scheduled");
    debugPrint("---------------------------------------------------");

  }

  

  Future<void> cancel(int id) async {
    debugPrint("❌ Cancelling notification ID: $id");
    await _plugin.cancel(id);
    debugPrint("Notification cancelled");
  }
}
