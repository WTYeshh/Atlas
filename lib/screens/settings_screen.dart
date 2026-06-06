import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../repositories/settings_repository.dart';
import '../repositories/auth_repository.dart';
import '../services/update_service.dart';
import '../services/sync_service.dart';
import '../services/discord_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final SettingsRepository _settingsRepo = SettingsRepository();
  final TextEditingController _googleClientIdController = TextEditingController();
  final TextEditingController _discordBotTokenController = TextEditingController();
  final TextEditingController _discordChannelIdController = TextEditingController();
  
  bool _externalSyncEnabled = true;
  bool _generativeAiEnabled = true;
  bool _discordSyncEnabled = false;
  bool _loadingSettings = true;
  bool _loadingGoogleClientId = true;
  bool _checkingUpdates = false;
  bool _syncingDiscord = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _googleClientIdController.dispose();
    _discordBotTokenController.dispose();
    _discordChannelIdController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final syncEnabled = await _settingsRepo.getExternalSyncEnabled();
    final aiEnabled = await _settingsRepo.getGenerativeAiEnabled();
    final discordEnabled = await _settingsRepo.getDiscordSyncEnabled();
    
    final clientId = await _settingsRepo.getGoogleClientId();
    if (clientId != null && clientId.trim().isNotEmpty) {
      _googleClientIdController.text = clientId;
    } else {
      _googleClientIdController.text = AuthRepository.defaultWebClientId;
    }

    final discordToken = await _settingsRepo.getDiscordBotToken();
    if (discordToken != null) {
      _discordBotTokenController.text = discordToken;
    }

    final discordChannel = await _settingsRepo.getDiscordChannelId();
    if (discordChannel != null) {
      _discordChannelIdController.text = discordChannel;
    }

    setState(() {
      _externalSyncEnabled = syncEnabled;
      _generativeAiEnabled = aiEnabled;
      _discordSyncEnabled = discordEnabled;
      _loadingSettings = false;
      _loadingGoogleClientId = false;
    });
  }

  Future<void> _toggleExternalSync(bool value) async {
    await _settingsRepo.saveExternalSyncEnabled(value);
    setState(() {
      _externalSyncEnabled = value;
    });

    if (value) {
      // Trigger sign-in if they don't have a linked Google account
      final authState = ref.read(authProvider);
      if (authState.userEmail == null || authState.userEmail == 'No Google Account linked') {
        final success = await ref.read(authProvider.notifier).signInAfterToggle();
        if (!success) {
          // If sign-in is cancelled/fails, revert the toggle
          await _settingsRepo.saveExternalSyncEnabled(false);
          setState(() {
            _externalSyncEnabled = false;
          });
          return;
        }
      }
      
      // Auto-trigger sync
      final syncService = ref.read(syncServiceProvider);
      await syncService.syncAll();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google sync disabled. Operating in local mode.')),
      );
    }
  }

  Future<void> _toggleGenerativeAi(bool value) async {
    await _settingsRepo.saveGenerativeAiEnabled(value);
    setState(() {
      _generativeAiEnabled = value;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Generative AI features ${value ? 'enabled' : 'disabled'}.')),
    );
  }

  Future<void> _saveGoogleClientId() async {
    final clientId = _googleClientIdController.text.trim();
    if (clientId.isEmpty || clientId == AuthRepository.defaultWebClientId) {
      await _settingsRepo.deleteGoogleClientId();
      _googleClientIdController.text = AuthRepository.defaultWebClientId;
    } else {
      await _settingsRepo.saveGoogleClientId(clientId);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Client ID saved successfully.')),
      );
    }
  }

  Future<void> _toggleDiscordSync(bool value) async {
    await _settingsRepo.saveDiscordSyncEnabled(value);
    setState(() {
      _discordSyncEnabled = value;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Discord Integration ${value ? 'enabled' : 'disabled'}.')),
      );
    }
  }

  Future<void> _saveDiscordSettings() async {
    final token = _discordBotTokenController.text.trim();
    final channelId = _discordChannelIdController.text.trim();

    // Reset sync cursor if the channel changed to retrieve new channel history
    final existingChannelId = await _settingsRepo.getDiscordChannelId();
    if (existingChannelId != channelId) {
      await _settingsRepo.saveDiscordLastMsgId('');
    }

    await _settingsRepo.saveDiscordBotToken(token);
    await _settingsRepo.saveDiscordChannelId(channelId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Discord settings saved successfully.')),
      );
    }
  }

  Future<void> _testAndSyncDiscord() async {
    setState(() {
      _syncingDiscord = true;
    });
    try {
      final discordService = ref.read(discordServiceProvider);
      final count = await discordService.syncDiscord();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync completed! Processed $count new message(s).')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _syncingDiscord = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _loadingSettings
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Account Card
                  _buildSectionHeader('Account Connection'),
                  const SizedBox(height: 8),
                  _buildAccountCard(context, authState),
                  const SizedBox(height: 24),

                  // Integrations & AI Config
                  _buildSectionHeader('Integrations & AI Config'),
                  const SizedBox(height: 8),
                  _buildExternalSyncCard(context),
                  const SizedBox(height: 12),
                  _buildGeminiConfigCard(context),
                  const SizedBox(height: 12),
                  _buildGoogleClientIdConfigCard(context),
                  const SizedBox(height: 12),
                  _buildDiscordConfigCard(context),
                  const SizedBox(height: 24),

                  // Interface customization
                  _buildSectionHeader('Appearance'),
                  const SizedBox(height: 8),
                  _buildThemeConfigCard(context, themeMode),
                  const SizedBox(height: 24),

                  // Notification configurations
                  _buildSectionHeader('Alert Preferences'),
                  const SizedBox(height: 8),
                  _buildNotificationConfigCard(context),
                  const SizedBox(height: 24),

                  // App Updates Configurations
                  _buildSectionHeader('App Updates'),
                  const SizedBox(height: 8),
                  _buildUpdateConfigCard(context),
                  const SizedBox(height: 40),

                  // Version info
                  Center(
                    child: Text(
                      'Atlas Version ${UpdateService.currentVersion} • Local First',
                      style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
    );
  }

  Widget _buildAccountCard(BuildContext context, AuthState authState) {
    final bool isOffline = !_externalSyncEnabled || authState.userEmail == 'No Google Account linked';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.05),
              backgroundImage: (authState.userPhotoUrl != null && !isOffline)
                  ? NetworkImage(authState.userPhotoUrl!)
                  : null,
              child: (authState.userPhotoUrl == null || isOffline)
                  ? Icon(isOffline ? Icons.cloud_off : Icons.person, color: Theme.of(context).primaryColor)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOffline ? 'Local Offline User' : (authState.userName ?? 'Offline User'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    isOffline ? 'Google Sync is disabled' : (authState.userEmail ?? 'No Google Account linked'),
                    style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (authState.isAuthenticated)
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                onPressed: () {
                  ref.read(authProvider.notifier).signOut();
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExternalSyncCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.cloud_sync, size: 16, color: Colors.blueAccent),
                    SizedBox(width: 8),
                    Text('Google Integration & Sync', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                Switch(
                  value: _externalSyncEnabled,
                  onChanged: _toggleExternalSync,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Sync calendars, back up academic notes to Google Drive, and access Google integration features.',
              style: TextStyle(fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeminiConfigCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 16, color: Colors.indigoAccent),
                    SizedBox(width: 8),
                    Text('Generative AI Features', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                Switch(
                  value: _generativeAiEnabled,
                  onChanged: _toggleGenerativeAi,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Enable document indexing, smart scheduling classifications, automatic notes summaries, and conversational chat helper functions powered by Gemini AI.',
              style: TextStyle(fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleClientIdConfigCard(BuildContext context) {
    final bool isSyncEnabled = _externalSyncEnabled;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.login, size: 16, color: isSyncEnabled ? Colors.blueAccent : Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Google Sign-In Client ID (Web)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSyncEnabled ? null : Theme.of(context).disabledColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Input your Google OAuth Client ID to configure the authentication flow for Google Calendar, Drive, and Sign-in.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: isSyncEnabled ? null : Theme.of(context).disabledColor,
              ),
            ),
            const SizedBox(height: 14),
            if (_loadingGoogleClientId)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _googleClientIdController,
                      enabled: isSyncEnabled,
                      decoration: InputDecoration(
                        hintText: 'Enter Google Client ID',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: isSyncEnabled ? _saveGoogleClientId : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSyncEnabled ? Theme.of(context).primaryColor : Theme.of(context).disabledColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('Save', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
                  ),
                ],
              ),
            if (!isSyncEnabled) ...[
              const SizedBox(height: 8),
              const Text(
                'Enable Google Integration & Sync above to configure this.',
                style: TextStyle(fontSize: 11, color: Colors.orangeAccent),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDiscordConfigCard(BuildContext context) {
    final bool isDiscordEnabled = _discordSyncEnabled;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.forum_outlined,
                      size: 16,
                      color: isDiscordEnabled ? Colors.indigoAccent : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Discord Integration',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDiscordEnabled ? null : Theme.of(context).disabledColor,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: _discordSyncEnabled,
                  onChanged: _toggleDiscordSync,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Import and schedule tasks, events, and notes sent to your Discord bot from a specific channel.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: isDiscordEnabled ? null : Theme.of(context).disabledColor,
              ),
            ),
            if (isDiscordEnabled) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _discordBotTokenController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Discord Bot Token',
                  hintText: 'Enter Bot Token',
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _discordChannelIdController,
                decoration: const InputDecoration(
                  labelText: 'Discord Channel ID',
                  hintText: 'Enter Channel ID',
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveDiscordSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        'Save Credentials',
                        style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _syncingDiscord ? null : _testAndSyncDiscord,
                    icon: _syncingDiscord
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.sync, size: 16, color: Colors.white),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigoAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    label: Text(
                      _syncingDiscord ? 'Syncing...' : 'Sync Now',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildThemeConfigCard(BuildContext context, ThemeMode mode) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Dark Mode Toggle', style: TextStyle(fontWeight: FontWeight.bold)),
            Switch(
              value: mode == ThemeMode.dark,
              onChanged: (_) {
                ref.read(themeProvider.notifier).toggleTheme();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationConfigCard(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Assignment Deadlines', style: TextStyle(fontSize: 14)),
                Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
              ],
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Class Agendas (15m before)', style: TextStyle(fontSize: 14)),
                Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
              ],
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('AI Generated Summaries Alerts', style: TextStyle(fontSize: 14)),
                Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkManualUpdates() async {
    setState(() {
      _checkingUpdates = true;
    });

    final updateService = UpdateService();
    final updateInfo = await updateService.checkForUpdates();

    setState(() {
      _checkingUpdates = false;
    });

    if (updateInfo != null) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => _buildUpdateDialog(context, updateInfo),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your application is up to date!')),
        );
      }
    }
  }

  Widget _buildUpdateConfigCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.system_update_alt, size: 16, color: Colors.blueAccent),
                SizedBox(width: 8),
                Text('App Updates', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Check for the latest features, bug fixes, and improvements for Atlas.',
              style: TextStyle(fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _checkingUpdates ? null : _checkManualUpdates,
                icon: _checkingUpdates
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.refresh, size: 18),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                label: Text(
                  _checkingUpdates ? 'Checking...' : 'Check for Updates',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateDialog(BuildContext context, UpdateInfo info) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.system_update, color: Theme.of(context).primaryColor),
          const SizedBox(width: 10),
          const Text('Update Available!'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Yes, latest update is available!',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '"${info.releaseNotes}"',
            style: const TextStyle(
              fontStyle: FontStyle.italic,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'are included in this update version ${info.version}.',
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Later'),
        ),
        ElevatedButton.icon(
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
          icon: const Icon(Icons.download, size: 16),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          label: Text(
            'Download Latest Update',
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
          ),
        ),
      ],
    );
  }
}
