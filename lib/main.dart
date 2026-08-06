// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'providers/app_state.dart';
import 'screens/dashboard_view.dart';
import 'screens/import_view.dart';
import 'screens/calls_view.dart';
import 'screens/salesman_view.dart';
import 'screens/settings_view.dart';
import 'services/notification_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // REQUIRED on Android 14+ before ANY status bar color changes work
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Now set the status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // transparent, not white — let the app content show through
      statusBarIconBrightness: Brightness.dark, // dark icons (visible on light backgrounds)
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  await NotificationService().initialize();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NotificationService.navigatorKey,
      title: 'Pharmacy Dues Tracker',
      theme: AppTheme.lightTheme,
      home: const AppShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final List<Widget> _views = const [
    DashboardView(),
    ImportView(),
    CallsView(),
    SalesmanView(),
    SettingsView(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkPermissionsAndBattery();
      await _checkExactAlarmCapability();
      _checkColdStartNotification();
    });
  }

  void _checkColdStartNotification() {
    final payload = NotificationService.initialLaunchPayload;
    if (payload != null) {
      NotificationService.navigateToPayload(payload);
      NotificationService.initialLaunchPayload = null; // Consume
    }
  }

  Future<void> _checkExactAlarmCapability() async {
    final canSchedule = await NotificationService().canScheduleExactNotifications();
    print('--- _checkExactAlarmCapability --- canSchedule: $canSchedule');
    if (!canSchedule) {
      if (mounted) {
        final openSettings = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Exact Alarms Required'),
            content: const Text(
              'To receive call reminders at the exact scheduled time, please enable Alarms & Reminders permission for this app.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Later'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );

        if (openSettings == true) {
          final androidImplementation = FlutterLocalNotificationsPlugin()
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
          try {
            await androidImplementation?.requestExactAlarmsPermission();
          } catch (e) {
            print("Failed to open exact alarm settings: '$e'.");
          }
        }
      }
    }
  }

  Future<void> _checkPermissionsAndBattery() async {
    print('--- _checkPermissionsAndBattery START ---');
    final prefs = await SharedPreferences.getInstance();

    final hasAskedPermissions = prefs.getBool('has_asked_permissions') ?? false;
    print('--- _checkPermissionsAndBattery --- hasAskedPermissions: $hasAskedPermissions');
    if (!hasAskedPermissions) {
      final notificationStatus = await Permission.notification.status;
      print('--- _checkPermissionsAndBattery --- notificationStatus: $notificationStatus');

      if (!notificationStatus.isGranted) {
        print('--- _checkPermissionsAndBattery --- requesting notification permission');
        final status = await Permission.notification.request();
        print('--- _checkPermissionsAndBattery --- notification request status: $status');

        if (!status.isGranted) {
          if (mounted) {
            await showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Permissions Needed'),
                content: const Text(
                  'This app needs notification permission to remind you to call pharmacies and salesmen. You can enable it in Settings.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        }
      }
      await prefs.setBool('has_asked_permissions', true);
    }

    final hasAskedBattery = prefs.getBool('has_asked_battery_optimization') ?? false;
    if (!hasAskedBattery) {
      final isIgnored = await Permission.ignoreBatteryOptimizations.isGranted;
      if (!isIgnored) {
        if (mounted) {
          final requestIgnored = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Battery Optimization'),
              content: const Text(
                'For reliable call reminders, please exclude this app from battery optimization. This prevents Android from cancelling your scheduled reminders when the phone is idle.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Later'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Exclude Now'),
                ),
              ],
            ),
          );

          if (requestIgnored == true) {
            await Permission.ignoreBatteryOptimizations.request();
          }
        }
      }
      await prefs.setBool('has_asked_battery_optimization', true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: IndexedStack(
        index: appState.currentTab,
        children: _views,
      ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: appState.currentTab,
          onTap: appState.setTab,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF00695C),
          unselectedItemColor: const Color(0xFF607D8B),
          elevation: 8,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.upload_file_outlined),
              activeIcon: Icon(Icons.upload_file),
              label: 'Import',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.phone_in_talk_outlined),
              activeIcon: Icon(Icons.phone_in_talk),
              label: 'Calls',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.badge_outlined),
              activeIcon: Icon(Icons.badge),
              label: 'Salesmen',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      );
  }
}
