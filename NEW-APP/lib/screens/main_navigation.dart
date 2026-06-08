import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'calendar_screen.dart';
import 'tasks_screen.dart';
import 'academic_tracker_screen.dart';
import 'academy_guild_screen.dart';
import 'settings_screen.dart';
import '../services/update_service.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/navigation_provider.dart';
import 'package:intl/intl.dart';
import '../core/secure_storage.dart';
import 'daily_greeting_dialog.dart';
import '../services/notification_service.dart';

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  final List<Widget> _screens = [
    const HomeScreen(),
    const CalendarScreen(),
    const TasksScreen(),
    const AcademicTrackerScreen(),
    const AcademyGuildScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Register notification tap callback to show greeting popup when tapped
    NotificationService().onNotificationTap = (payload) {
      if (payload != null && payload.startsWith('greeting:')) {
        final modeStr = payload.split(':')[1];
        final mode = modeStr == 'morning' ? GreetingMode.morning : GreetingMode.night;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            DailyGreetingDialog.show(context, autoTriggered: false, forceMode: mode);
          }
        });
      }
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdatesAutomatic();
      _checkAndShowDailyGreeting();
    });
  }

  Future<void> _checkAndShowDailyGreeting() async {
    // Check if the app was launched by tapping a daily greeting notification
    final initialPayload = NotificationService().initialPayload;
    if (initialPayload != null) {
      NotificationService().initialPayload = null; // Clear it
      if (initialPayload.startsWith('greeting:')) {
        final modeStr = initialPayload.split(':')[1];
        final mode = modeStr == 'morning' ? GreetingMode.morning : GreetingMode.night;
        DailyGreetingDialog.show(context, autoTriggered: false, forceMode: mode);
        return; // Skip normal automatic trigger since user explicitly opened a slot
      }
    }

    final todayStr = DateFormat('dd-MM-yy').format(DateTime.now());
    final hour = DateTime.now().hour;

    if (hour < 17) {
      // Morning Mode
      final lastMorning = await SecureStorage().getLastMorningGreetingDate();
      if (lastMorning != todayStr && mounted) {
        DailyGreetingDialog.show(
          context,
          autoTriggered: true,
          forceMode: GreetingMode.morning,
        );
      }
    } else {
      // Night Mode
      final lastNight = await SecureStorage().getLastNightGreetingDate();
      if (lastNight != todayStr && mounted) {
        DailyGreetingDialog.show(
          context,
          autoTriggered: true,
          forceMode: GreetingMode.night,
        );
      }
    }
  }

  Future<void> _checkForUpdatesAutomatic() async {
    final updateService = UpdateService();
    final updateInfo = await updateService.checkForUpdates();
    if (updateInfo != null && mounted) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => _buildUpdateDialog(context, updateInfo),
      );
    }
  }

  Widget _buildUpdateDialog(BuildContext context, UpdateInfo info) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.system_update, color: Theme.of(context).primaryColor),
          const SizedBox(width: 10),
          const Text('New Update Available'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Version: ${info.version} (Build ${info.buildNumber})',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'What\'s New:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.maxFinite,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              info.releaseNotes,
              style: const TextStyle(fontSize: 12, height: 1.4),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Do you want to download and install this update now?',
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Later'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            final uri = Uri.parse(info.downloadUrl);
            try {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not open download link.')),
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
          ),
          child: Text('Update Now', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(navigationIndexProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          selectedIndex == 0
              ? 'NOVA STUDY'
              : selectedIndex == 1
                  ? 'Calendar'
                  : selectedIndex == 2
                      ? 'Tasks'
                      : selectedIndex == 3
                          ? 'Academics'
                          : 'Scholar Guild',
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.emoji_emotions_outlined),
            tooltip: "Test Greeting",
            onSelected: (value) {
              if (value == 'morning') {
                DailyGreetingDialog.show(
                  context,
                  autoTriggered: false,
                  forceMode: GreetingMode.morning,
                );
              } else if (value == 'night_pending') {
                DailyGreetingDialog.show(
                  context,
                  autoTriggered: false,
                  forceMode: GreetingMode.night,
                );
              } else if (value == 'night_completed') {
                DailyGreetingDialog.show(
                  context,
                  autoTriggered: false,
                  forceMode: GreetingMode.night,
                  mockAllCompleted: true,
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'morning',
                child: Text('Morning Mode Preview'),
              ),
              const PopupMenuItem(
                value: 'night_pending',
                child: Text('Night Mode Preview (Pending)'),
              ),
              const PopupMenuItem(
                value: 'night_completed',
                child: Text('Night Mode Preview (All Completed)'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: selectedIndex,
          type: BottomNavigationBarType.fixed,
          onTap: (index) {
            ref.read(navigationIndexProvider.notifier).state = index;
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month),
              label: 'Calendar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.checklist_outlined),
              activeIcon: Icon(Icons.checklist),
              label: 'Tasks',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.school_outlined),
              activeIcon: Icon(Icons.school),
              label: 'Academics',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.military_tech_outlined),
              activeIcon: Icon(Icons.military_tech),
              label: 'Guild',
            ),
          ],
        ),
      ),
    );
  }
}
