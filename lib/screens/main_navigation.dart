import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'calendar_screen.dart';
import 'notes_screen.dart';
import 'tasks_screen.dart';
import 'assistant_screen.dart';
import 'settings_screen.dart';
import '../services/update_service.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/navigation_provider.dart';

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  final List<Widget> _screens = [
    const HomeScreen(),
    const CalendarScreen(),
    const NotesScreen(),
    const TasksScreen(),
    const AssistantScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdatesAutomatic();
    });
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
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
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
              ? 'ATLAS'
              : selectedIndex == 1
                  ? 'Calendar'
                  : selectedIndex == 2
                      ? 'Notes Vault'
                      : selectedIndex == 3
                          ? 'Tasks'
                          : 'Smart Assistant',
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
        actions: [
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
              icon: Icon(Icons.folder_open_outlined),
              activeIcon: Icon(Icons.folder),
              label: 'Notes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.checklist_outlined),
              activeIcon: Icon(Icons.checklist),
              label: 'Tasks',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Assistant',
            ),
          ],
        ),
      ),
    );
  }
}
