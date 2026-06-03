import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../repositories/settings_repository.dart';
import '../repositories/auth_repository.dart';
import '../services/update_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final SettingsRepository _settingsRepo = SettingsRepository();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _googleClientIdController = TextEditingController();
  final TextEditingController _updateUrlController = TextEditingController();
  bool _loadingKey = true;
  bool _loadingGoogleClientId = true;
  bool _checkingUpdates = false;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    _loadGoogleClientId();
    _loadUpdateUrl();
  }

  Future<void> _loadApiKey() async {
    final key = await _settingsRepo.getGeminiApiKey();
    if (key != null) {
      _apiKeyController.text = key;
    }
    setState(() {
      _loadingKey = false;
    });
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    await _settingsRepo.saveGeminiApiKey(key);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gemini API Key saved successfully.')),
    );
  }

  Future<void> _loadGoogleClientId() async {
    final clientId = await _settingsRepo.getGoogleClientId();
    if (clientId != null && clientId.trim().isNotEmpty) {
      _googleClientIdController.text = clientId;
    } else {
      _googleClientIdController.text = AuthRepository.defaultWebClientId;
    }
    setState(() {
      _loadingGoogleClientId = false;
    });
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account Card
            _buildSectionHeader('Account Connection'),
            const SizedBox(height: 8),
            _buildAccountCard(context, authState),
            const SizedBox(height: 24),

            // Integration Keys configuration
            _buildSectionHeader('Credentials & API Keys'),
            const SizedBox(height: 8),
            _buildGeminiConfigCard(context),
            const SizedBox(height: 12),
            _buildGoogleClientIdConfigCard(context),
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
                'Atlas v${UpdateService.currentVersion} • Local First',
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.05),
              backgroundImage: authState.userPhotoUrl != null ? NetworkImage(authState.userPhotoUrl!) : null,
              child: authState.userPhotoUrl == null
                  ? Icon(Icons.person, color: Theme.of(context).primaryColor)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authState.userName ?? 'Offline User',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    authState.userEmail ?? 'No Google Account linked',
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

  Widget _buildGeminiConfigCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome, size: 16, color: Colors.indigoAccent),
                SizedBox(width: 8),
                Text('Gemini Generative AI Key', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Input your Gemini API key to enable document indexing, smart scheduling classifications, summaries, and conversational chat helper functions.',
              style: TextStyle(fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 14),
            if (_loadingKey)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _apiKeyController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        hintText: 'Enter API Key',
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _saveApiKey,
                    child: Text('Save', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleClientIdConfigCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.login, size: 16, color: Colors.blueAccent),
                SizedBox(width: 8),
                Text('Google Sign-In Client ID (Web)', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Input your Google OAuth Client ID to configure the authentication flow for Google Calendar, Drive, and Sign-in.',
              style: TextStyle(fontSize: 12, height: 1.4),
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
                      obscureText: false,
                      decoration: const InputDecoration(
                        hintText: 'Enter Google Client ID',
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _saveGoogleClientId,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('Save', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
                  ),
                ],
              ),
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

  Future<void> _loadUpdateUrl() async {
    final url = await _settingsRepo.getUpdateCheckUrl();
    if (url != null) {
      _updateUrlController.text = url;
    } else {
      _updateUrlController.text = UpdateService.defaultUpdateCheckUrl;
    }
  }

  Future<void> _saveUpdateUrl() async {
    final url = _updateUrlController.text.trim();
    await _settingsRepo.saveUpdateCheckUrl(url);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Update URL saved successfully.')),
      );
    }
  }

  Future<void> _checkManualUpdates() async {
    final url = _updateUrlController.text.trim();
    await _settingsRepo.saveUpdateCheckUrl(url);
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
                Text('Update Preferences', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter the version metadata URL containing the update info JSON to check for the latest releases.',
              style: TextStyle(fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _updateUrlController,
                    decoration: const InputDecoration(
                      hintText: 'Enter Update Metadata URL',
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _checkingUpdates ? null : _checkManualUpdates,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _checkingUpdates
                      ? SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            color: Theme.of(context).colorScheme.onPrimary,
                            strokeWidth: 2,
                          ),
                        )
                      : Text('Check for Updates', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
                ),
                OutlinedButton(
                  onPressed: _saveUpdateUrl,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Save URL'),
                ),
              ],
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
}
