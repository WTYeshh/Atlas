import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_10y.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import '../repositories/settings_repository.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  // Tap handler callbacks
  void Function(String?)? onNotificationTap;
  String? initialPayload;

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
        print('Notification clicked: ${response.payload}');
        if (onNotificationTap != null) {
          onNotificationTap!(response.payload);
        }
      },
    );

    // 4. Check if the app was launched by tapping a notification
    final NotificationAppLaunchDetails? launchDetails =
        await _notificationsPlugin.getNotificationAppLaunchDetails();
    if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
      initialPayload = launchDetails.notificationResponse?.payload;
    }

    // 5. Schedule repeating morning and night alerts
    await scheduleDailyGreetings();
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

  // Schedule weekly notification at specific day and time
  Future<void> scheduleWeeklyNotification({
    required int id,
    required String title,
    required String body,
    required int dayOfWeek, // 1 = Monday, 7 = Sunday
    required int hour,
    required int minute,
    String? payload,
  }) async {
    if (kIsWeb) {
      print('Scheduled Weekly Notification: $title - $body on Day $dayOfWeek at $hour:$minute');
      return;
    }

    // Calculate next occurrence of the day of the week and time
    DateTime now = DateTime.now();
    int daysUntil = (dayOfWeek - now.weekday) % 7;
    if (daysUntil < 0) daysUntil += 7;
    
    DateTime scheduledTime = DateTime(now.year, now.month, now.day, hour, minute).add(Duration(days: daysUntil));
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 7));
    }

    final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(scheduledTime, tz.local);

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'atlas_attendance_channel',
      'Atlas Attendance Reminders',
      channelDescription: 'Scheduled reminders for marking daily class attendance',
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
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: payload,
    );
  }

  // Schedule daily repeating notification
  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    if (kIsWeb) {
      print('Scheduled Daily Notification: $title - $body at $hour:$minute');
      return;
    }

    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(scheduledTime, tz.local);

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'atlas_daily_greeting_channel',
      'Atlas Daily Greetings',
      channelDescription: 'Scheduled reminders for morning tasks and night reviews',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduledDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
    } catch (e) {
      print('NotificationService: Error scheduling daily reminder: $e');
    }
  }

  Future<void> scheduleDailyGreetings() async {
    final profile = await SettingsRepository().getUserProfile();
    final name = profile['name'] ?? 'User';

    // 8:00 AM Morning Greeting
    await scheduleDailyNotification(
      id: 60000,
      title: '☀️ Good Morning $name!',
      body: "Here are your tasks and events for today. Tap to check them out!",
      hour: 8,
      minute: 0,
      payload: 'greeting:morning',
    );
    
    // 9:00 PM Night Greeting
    await scheduleDailyNotification(
      id: 60001,
      title: '🌙 Good Night $name!',
      body: "Let's review what was completed today and reschedule pending tasks.",
      hour: 21,
      minute: 0,
      payload: 'greeting:night',
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
