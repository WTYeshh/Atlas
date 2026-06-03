import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_10y.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  factory NotificationService() => _instance;

  NotificationService._internal();

  Future<void> init() async {
    if (kIsWeb) {
      print('NotificationService: Local notifications are not supported on Web.');
      return;
    }

    // 1. Initialize timezone database
    tz.initializeTimeZones();

    // 2. Configure Android-specific initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    // 3. Initialize plugin
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification click: redirect user or open screen
        print('Notification clicked: ${response.payload}');
      },
    );
  }

  Future<void> requestPermissions() async {
    if (kIsWeb) return;
    final androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
  }

  // Show immediate notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) {
      print('Notification: $title - $body');
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'atlas_alerts_channel',
      'Atlas Alerts',
      channelDescription: 'Notifications for class updates, tasks, and assistant reminders',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      id,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  // Schedule notification for future date/time
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (kIsWeb) {
      print('Scheduled Notification: $title - $body at $scheduledDate');
      return;
    }

    final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);
    if (tzScheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      // If scheduled time is in the past, show immediately or skip
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'atlas_reminders_channel',
      'Atlas Reminders',
      channelDescription: 'Scheduled reminders for academic events, classes, and assignment deadlines',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzScheduledDate,
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  // Cancel notification by ID
  Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    await _notificationsPlugin.cancel(id);
  }

  // Cancel all active notifications
  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await _notificationsPlugin.cancelAll();
  }
}
