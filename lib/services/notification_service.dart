// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../data/pharmacy_repository.dart';
import '../data/reminder_repository.dart';
import 'formatters.dart';
import '../screens/pharmacy_detail_screen.dart';
import '../screens/salesman_detail_screen.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static String? initialLaunchPayload;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    print('--- NotificationService.initialize() called ---');
    tz.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      print('Timezone initialized to: $timeZoneName');
    } catch (e) {
      print('Failed to initialize timezone: $e');
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      } catch (_) {}
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          _handleNotificationTap(response.payload);
        }
      },
    );

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'call_reminders',
        'Call Reminders',
        description: 'Notifications for call reminders',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await androidImplementation.createNotificationChannel(channel);

      final canSchedule = await androidImplementation.canScheduleExactNotifications() ?? false;
      print('--- NotificationService.initialize --- canScheduleExactNotifications: $canSchedule');
      if (!canSchedule) {
        print('--- NotificationService.initialize --- Requesting exact alarm permission');
        await androidImplementation.requestExactAlarmsPermission();
      }
    }

    final NotificationAppLaunchDetails? launchDetails =
        await _notificationsPlugin.getNotificationAppLaunchDetails();
    if (launchDetails != null &&
        launchDetails.didNotificationLaunchApp &&
        launchDetails.notificationResponse != null) {
      initialLaunchPayload = launchDetails.notificationResponse!.payload;
    }
  }

  Future<int> scheduleNotification({
    required int reminderId,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    required String payload,
  }) async {
    final tz.TZDateTime tzScheduledDate = tz.TZDateTime(
      tz.local,
      scheduledDateTime.year,
      scheduledDateTime.month,
      scheduledDateTime.day,
      scheduledDateTime.hour,
      scheduledDateTime.minute,
    );

    print('NOW: ${tz.TZDateTime.now(tz.local)} | SCHEDULED: $tzScheduledDate');

    await _notificationsPlugin.zonedSchedule(
      id: reminderId,
      title: title,
      body: body,
      scheduledDate: tzScheduledDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'call_reminders',
          'Call Reminders',
          channelDescription: 'Reminders to call pharmacies and salesmen',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );

    print('NOTIFICATION SCHEDULED: id=$reminderId');
    return reminderId;
  }

  Future<void> scheduleReminderNotification(int reminderId) async {
    print('--- scheduleReminderNotification START --- reminderId: $reminderId');
    final reminder = await ReminderRepository().getById(reminderId);
    if (reminder == null) {
      print('--- scheduleReminderNotification ERROR: reminder is null ---');
      return;
    }
    if (reminder.scheduledTime == null || reminder.scheduledTime!.isEmpty) {
      print('--- scheduleReminderNotification ERROR: scheduledTime is null/empty ---');
      return;
    }

    String title = '';
    String body = '';

    if (reminder.reminderType == 'pharmacy') {
      final pharmacyId = reminder.pharmacyId!;
      final pharmacy = await PharmacyRepository().getById(pharmacyId);
      if (pharmacy == null) {
        print('--- scheduleReminderNotification ERROR: pharmacy is null ---');
        return;
      }

      title = 'Call ${pharmacy.name}';
      body = '${formatIndianCurrency(pharmacy.totalAmount ?? 0.0)} outstanding';
    } else if (reminder.reminderType == 'salesman') {
      final salesmanName = reminder.salesmanName!;
      final summaries = await PharmacyRepository().getSalesmenSummary();

      SalesmanSummary? foundSummary;
      for (final s in summaries) {
        if (s.salesman.trim().toLowerCase() == salesmanName.trim().toLowerCase()) {
          foundSummary = s;
          break;
        }
      }
      final summary = foundSummary ?? SalesmanSummary(salesman: salesmanName, pharmacyCount: 0, totalDue: 0.0);

      title = 'Call Salesman $salesmanName';
      body = '${summary.pharmacyCount} pharmacies — ${formatIndianCurrency(summary.totalDue)} total outstanding';
    } else {
      print('--- scheduleReminderNotification ERROR: unknown reminderType: ${reminder.reminderType} ---');
      return;
    }

    if (reminder.notes != null && reminder.notes!.trim().isNotEmpty) {
      body += '\nNote: ${reminder.notes!.trim()}';
    }

    final dateParts = reminder.scheduledDate.split('-');
    final timeParts = reminder.scheduledTime!.split(':');
    final scheduledDateTime = DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
    );

    if (scheduledDateTime.isBefore(DateTime.now())) {
      print('--- scheduleReminderNotification ERROR: scheduledDateTime is in the past: $scheduledDateTime ---');
      return;
    }

    final payload = jsonEncode({
      'reminder_type': reminder.reminderType,
      'pharmacy_id': reminder.pharmacyId,
      'salesman_name': reminder.salesmanName,
    });

    print('--- scheduleReminderNotification scheduling with: title: $title, body: $body, scheduledDateTime: $scheduledDateTime');
    await scheduleNotification(
      reminderId: reminderId,
      title: title,
      body: body,
      scheduledDateTime: scheduledDateTime,
      payload: payload,
    );

    await ReminderRepository().updateNotificationId(reminderId, reminderId);
    print('--- scheduleReminderNotification END ---');
  }

  Future<bool> canScheduleExactNotifications() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      final bool? canSchedule = await androidImplementation.canScheduleExactNotifications();
      return canSchedule ?? false;
    }
    return true;
  }

  Future<void> cancelNotification(int notificationId) async {
    await _notificationsPlugin.cancel(id: notificationId);
  }

  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  static void navigateToPayload(String payload) {
    _handleNotificationTap(payload);
  }

  static void _handleNotificationTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final type = data['reminder_type'] as String?;

      if (type == 'pharmacy') {
        final pharmacyId = data['pharmacy_id'] as int?;
        if (pharmacyId != null) {
          _navigateToPharmacyDetail(pharmacyId);
        }
      } else if (type == 'salesman') {
        final salesmanName = data['salesman_name'] as String?;
        if (salesmanName != null) {
          _navigateToSalesmanDetail(salesmanName);
        }
      }
    } catch (e) {
      debugPrint('Error handling notification tap: $e');
    }
  }

  static Future<void> _navigateToPharmacyDetail(int pharmacyId) async {
    final pharmacy = await PharmacyRepository().getById(pharmacyId);
    if (pharmacy != null && navigatorKey.currentState != null) {
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => PharmacyDetailScreen(pharmacy: pharmacy),
        ),
      );
    }
  }

  static Future<void> _navigateToSalesmanDetail(String salesmanName) async {
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => SalesmanDetailScreen(salesmanName: salesmanName),
        ),
      );
    }
  }
}
