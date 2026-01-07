import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInit = false;

  Future<void> init() async {
    if (kIsWeb || _isInit) return;
    
    tz.initializeTimeZones(); // Initialize timezone DB

    // Android Settings
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS Settings
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      
    );

    const InitializationSettings settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
         // handle notification tap if needed
         if (kDebugMode) {
           print("Notification tapped: ${response.payload}");
         }
      },
    );
    
    _isInit = true;
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    if (kIsWeb) {
      print("SIMULATED WEB NOTIFICATION: '$title' - '$body' scheduled for $scheduledTime");
      return;
    }
    if (!_isInit) await init();

    try {
      // Ensure scheduled time is in the future
      if (scheduledTime.isBefore(DateTime.now())) {
         return; 
      }

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'care_reminders_channel',
            'Care Reminders',
            channelDescription: 'Reminders for daily tasks and medications',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            sound: 'default',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      if (kDebugMode) {
        print("Scheduled notification '$title' for $scheduledTime");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Notification Error: $e");
      }
    }
  }

  Future<void> cancel(int id) async {
    if (kIsWeb) return;
    await _notificationsPlugin.cancel(id);
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _notificationsPlugin.cancelAll();
  }

  static int makeId(String uid, String taskId, int offsetIndex) {
    // Simple hash for deterministic ID
    final composite = "${uid}_${taskId}_$offsetIndex";
    return composite.hashCode;
  }
}