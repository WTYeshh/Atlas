import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'screens/auth_screen.dart';
import 'screens/main_navigation.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'services/notification_service.dart';
import 'services/share_service.dart';
import 'providers/notes_provider.dart';
import 'providers/calendar_provider.dart';

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
  ShareService? _shareService;

  @override
  void initState() {
    super.initState();
    // Initialize share service once DB repos are set up via ref
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dbRepo = ref.read(databaseRepositoryProvider);
      final calendarRepo = ref.read(calendarRepositoryProvider);
      final driveRepo = ref.read(driveRepositoryProvider);
      
      _shareService = ShareService(dbRepo, calendarRepo, driveRepo);
      _shareService!.init();
    });
  }

  @override
  void dispose() {
    _shareService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Atlas Assistant',
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
