import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/past_semester_provider.dart';
import '../models/past_semester_model.dart';
import '../repositories/settings_repository.dart';
import '../repositories/auth_repository.dart';
import '../services/update_service.dart';
import '../services/sync_service.dart';
import '../services/discord_service.dart';
import '../services/discord_digest_service.dart';
import '../services/notification_service.dart';
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
  bool _discordSyncEnabled = false;
  bool _discordDailyDigestEnabled = false;
  bool _discordWeeklyDigestEnabled = false;
  bool _sendingTestDigest = false;
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
    final discordEnabled = await _settingsRepo.getDiscordSyncEnabled();
    
    final clientId = await _settingsRepo.getGoogleClientId();
    if (clientId != null && clientId.trim().isNotEmpty) {
      _googleClientIdController.text = clientId;
    } else {
      _googleClientIdController.text = '';
    }

    final discordToken = await _settingsRepo.getDiscordBotToken();
    if (discordToken != null) {
      _discordBotTokenController.text = discordToken;
    }

    final discordChannel = await _settingsRepo.getDiscordChannelId();
    if (discordChannel != null) {
      _discordChannelIdController.text = discordChannel;
    }

    final dailyDigest = await _settingsRepo.getSetting('discord_daily_digest_enabled') == 'true';
    final weeklyDigest = await _settingsRepo.getSetting('discord_weekly_digest_enabled') == 'true';

    setState(() {
      _externalSyncEnabled = syncEnabled;
      _discordSyncEnabled = discordEnabled;
      _discordDailyDigestEnabled = dailyDigest;
      _discordWeeklyDigestEnabled = weeklyDigest;
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
      // Auto-trigger sync
      final syncService = ref.read(syncServiceProvider);
      await syncService.syncAll();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync disabled. Operating in local mode.')),
        );
      }
    }
  }

  Future<void> _toggleDailyDigest(bool value) async {
    await _settingsRepo.saveSetting('discord_daily_digest_enabled', value.toString());
    setState(() {
      _discordDailyDigestEnabled = value;
    });
  }

  Future<void> _toggleWeeklyDigest(bool value) async {
    await _settingsRepo.saveSetting('discord_weekly_digest_enabled', value.toString());
    setState(() {
      _discordWeeklyDigestEnabled = value;
    });
  }

  Future<void> _sendTestDiscordDigest() async {
    setState(() {
      _sendingTestDigest = true;
    });
    try {
      final success = await ref.read(discordDigestServiceProvider).sendDailyDigest(force: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: success ? Colors.green : Colors.redAccent,
            content: Text(success 
                ? 'Test daily digest broadcasted successfully!' 
                : 'Failed to send test broadcast. Check channel configuration.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sendingTestDigest = false;
        });
      }
    }
  }



  Future<void> _saveGoogleClientId() async {
    final clientId = _googleClientIdController.text.trim();
    if (clientId.isEmpty) {
      await _settingsRepo.deleteGoogleClientId();
      _googleClientIdController.text = '';
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

                  // Previous Semesters Configurations
                  _buildSectionHeader('PREVIOUS SEM DATA'),
                  const SizedBox(height: 8),
                  _buildPastSemestersCard(context),
                  const SizedBox(height: 24),

                  // App Updates Configurations
                  _buildSectionHeader('App Updates'),
                  const SizedBox(height: 8),
                  _buildUpdateConfigCard(context),
                  const SizedBox(height: 40),

                  // Version info
                  Center(
                    child: Text(
                      'Nova Study Version ${UpdateService.currentVersion} • Local First',
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
              'Sync calendars with Google Calendar and access Google integration features.',
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
              'Import and process timetable screenshots sent to your Discord bot from a specific channel.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: isDiscordEnabled ? null : Theme.of(context).disabledColor,
              ),
            ),
            if (isDiscordEnabled) ...[
              const SizedBox(height: 16),
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
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                label: Center(
                  child: Text(
                    _syncingDiscord ? 'Syncing...' : 'Sync Now',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Assignment Deadlines', style: TextStyle(fontSize: 14)),
                Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Class Agendas (15m before)', style: TextStyle(fontSize: 14)),
                Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
              ],
            ),
            const Divider(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final notificationService = NotificationService();
                await notificationService.requestPermissions();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sending test notification...')),
                  );
                }
                await notificationService.showNotification(
                  id: 99999,
                  title: 'Test Notification 📱',
                  body: 'This is a test notification from ATLAS. Your notifications are working perfectly!',
                );
              },
              icon: const Icon(Icons.notifications_active_outlined, size: 16),
              label: const Text('Send Test Notification'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                foregroundColor: Theme.of(context).primaryColor,
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscordDigestsCard(BuildContext context) {
    final bool isDiscordEnabled = _discordSyncEnabled;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.mail_outline,
                  size: 16,
                  color: isDiscordEnabled ? Colors.indigoAccent : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Automated Discord Broadcasts',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDiscordEnabled ? null : Theme.of(context).disabledColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Receive scheduled updates of your schedule and tasks automatically in your Discord channel.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: isDiscordEnabled ? null : Theme.of(context).disabledColor,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Daily Agenda Digest', style: TextStyle(fontSize: 13)),
              subtitle: const Text('Sends today\'s schedule at 8:00 AM', style: TextStyle(fontSize: 11)),
              value: _discordDailyDigestEnabled,
              onChanged: isDiscordEnabled ? _toggleDailyDigest : null,
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('Weekly Schedule Digest', style: TextStyle(fontSize: 13)),
              subtitle: const Text('Sends a weekly overview on Sundays', style: TextStyle(fontSize: 11)),
              value: _discordWeeklyDigestEnabled,
              onChanged: isDiscordEnabled ? _toggleWeeklyDigest : null,
              contentPadding: EdgeInsets.zero,
            ),
            if (isDiscordEnabled) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _sendingTestDigest ? null : _sendTestDiscordDigest,
                      icon: _sendingTestDigest
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.indigoAccent),
                            )
                          : const Icon(Icons.send_outlined, size: 16),
                      label: const Text('Send Test Broadcast'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigoAccent.withOpacity(0.1),
                        foregroundColor: Colors.indigoAccent,
                        elevation: 0,
                      ),
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

  String _formatDisplayDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return 'Not configured';
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return '${parts[2]}-${parts[1]}-${parts[0].substring(2)}';
      }
    } catch (_) {}
    return dateStr;
  }

  void _showPastSemesterPreviewDialog(BuildContext context, PastSemesterModel sem) {
    final List<dynamic> subjectsData = jsonDecode(sem.compiledJson);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sem.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              '${_formatDisplayDate(sem.startDate)} to ${_formatDisplayDate(sem.endDate)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: subjectsData.length,
            itemBuilder: (context, index) {
              final item = subjectsData[index];
              final name = item['subjectName'] ?? 'Unknown';
              final code = item['subjectCode'];
              final attPercent = (item['attendancePercentage'] as num?)?.toDouble() ?? 0.0;
              final held = (item['heldClasses'] as num?)?.toInt() ?? 0;
              final attended = (item['attendedClasses'] as num?)?.toInt() ?? 0;
              final ia1 = item['ia1'];
              final ia2 = item['ia2'];
              final ia3 = item['ia3'];
              final bestOfTwo = (item['bestOfTwo'] as num?)?.toDouble() ?? 0.0;
              
              final isLow = attPercent < (item['minPercentage'] as num? ?? 75.0);
              final attColor = isLow ? Colors.redAccent : Colors.green;
              final iaColor = bestOfTwo > 36 ? Colors.green : Colors.redAccent;
              
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        code != null ? '[$code] $name' : name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Attendance:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                            '${attPercent.toStringAsFixed(1)}% ($attended/$held)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: attColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text('IA Marks:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('IA1: ${ia1 ?? "N/A"}', style: const TextStyle(fontSize: 11)),
                            Text('IA2: ${ia2 ?? "N/A"}', style: const TextStyle(fontSize: 11)),
                            Text('IA3: ${ia3 ?? "N/A"}', style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Best of 2:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                            '${bestOfTwo.toStringAsFixed(0)} / 100',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: iaColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                final path = await ref.read(pastSemesterProvider.notifier).downloadSemesterReport(sem);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Report downloaded to: $path'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to download report: $e'),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.download, size: 16),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
            ),
            label: Text('Download Report', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildPastSemestersCard(BuildContext context) {
    final pastSemesters = ref.watch(pastSemesterProvider);
    
    if (pastSemesters.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'No archived semesters found.',
              style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 13),
            ),
          ),
        ),
      );
    }
    
    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: pastSemesters.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final sem = pastSemesters[index];
          return ListTile(
            leading: Icon(Icons.archive_outlined, color: Theme.of(context).primaryColor),
            title: Text(sem.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${_formatDisplayDate(sem.startDate)} to ${_formatDisplayDate(sem.endDate)}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.preview_outlined, color: Colors.blueAccent),
                  tooltip: 'Preview',
                  onPressed: () => _showPastSemesterPreviewDialog(context, sem),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  tooltip: 'Delete Archive',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Semester Archive?'),
                        content: Text('Are you sure you want to permanently delete the archive for "${sem.name}"? This cannot be undone.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref.read(pastSemesterProvider.notifier).deleteSemester(sem.id);
                    }
                  },
                ),
              ],
            ),
            onTap: () => _showPastSemesterPreviewDialog(context, sem),
          );
        },
      ),
    );
  }
}
