import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'screens/auth_screen.dart';
import 'screens/main_navigation.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/calendar_provider.dart';
import 'providers/tasks_provider.dart';
import 'services/notification_service.dart';
import 'services/auto_reminder_service.dart';
import 'services/discord_digest_service.dart';
import 'providers/repository_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications
  final notificationService = NotificationService();
  await notificationService.init();
  await notificationService.requestPermissions();

  runApp(
    const ProviderScope(
      child: AtlasApp(),
    ),
  );
}

class AtlasApp extends ConsumerStatefulWidget {
  const AtlasApp({super.key});

  @override
  ConsumerState<AtlasApp> createState() => _AtlasAppState();
}

class _AtlasAppState extends ConsumerState<AtlasApp> {
  @override
  void initState() {
    super.initState();
    // Schedule all auto-reminders after the first frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleAutoReminders();
    });
  }

  Future<void> _scheduleAutoReminders() async {
    try {
      final dbRepo = ref.read(databaseRepositoryProvider);
      final calendarRepo = ref.read(calendarRepositoryProvider);
      await AutoReminderService().rescheduleAll(
        dbRepo: dbRepo,
        calendarRepo: calendarRepo,
      );
      // Trigger Discord digest check
      await ref.read(discordDigestServiceProvider).checkAndTriggerDigests();
    } catch (e) {
      print('AtlasApp: Failed to schedule auto-reminders/digests: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Atlas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: authState.isLoading
          ? Scaffold(
              backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'ATLAS',
                      style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
                        letterSpacing: 4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : authState.isAuthenticated
              ? const MainNavigation()
              : const AuthScreen(),
    );
  }
}
