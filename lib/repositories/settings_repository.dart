import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import '../core/database_helper.dart';
import '../core/secure_storage.dart';

bool get _isWebOrTest => kIsWeb || (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'));

class SettingsRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SecureStorage _secureStorage = SecureStorage();

  // Basic SQL operations
  Future<String?> getSetting(String key) async {
    if (_isWebOrTest) {
      return null;
    }
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) {
      return maps.first['value'] as String?;
    }
    return null;
  }

  Future<void> saveSetting(String key, String value) async {
    if (_isWebOrTest) return;
    final db = await _dbHelper.database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSetting(String key) async {
    if (_isWebOrTest) return;
    final db = await _dbHelper.database;
    await db.delete(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  // --- Specific settings helpers ---

  // Gemini API Key
  Future<void> saveGeminiApiKey(String key) async {
    await saveSetting('gemini_api_key', key);
  }

  Future<String?> getGeminiApiKey() async {
    return await getSetting('gemini_api_key');
  }

  Future<void> deleteGeminiApiKey() async {
    await deleteSetting('gemini_api_key');
  }

  // External Sync (Google Integration & Sync)
  Future<void> saveExternalSyncEnabled(bool enabled) async {
    await saveSetting('external_sync_enabled', enabled.toString());
  }

  Future<bool> getExternalSyncEnabled() async {
    final val = await getSetting('external_sync_enabled');
    return val == null ? true : val == 'true';
  }

  // Generative AI Enabled
  Future<void> saveGenerativeAiEnabled(bool enabled) async {
    await saveSetting('generative_ai_enabled', enabled.toString());
  }

  Future<bool> getGenerativeAiEnabled() async {
    final val = await getSetting('generative_ai_enabled');
    return val == null ? true : val == 'true';
  }

  // Google Client ID
  Future<void> saveGoogleClientId(String clientId) async {
    await saveSetting('google_client_id', clientId);
  }

  Future<String?> getGoogleClientId() async {
    return await getSetting('google_client_id');
  }

  Future<void> deleteGoogleClientId() async {
    await deleteSetting('google_client_id');
  }

  // Update check URL
  Future<void> saveUpdateCheckUrl(String url) async {
    await saveSetting('update_check_url', url);
  }

  Future<String?> getUpdateCheckUrl() async {
    return await getSetting('update_check_url');
  }

  Future<void> deleteUpdateCheckUrl() async {
    await deleteSetting('update_check_url');
  }

  // Theme Mode
  Future<void> saveThemeMode(String mode) async {
    await saveSetting('theme_mode', mode);
  }

  Future<String> getThemeMode() async {
    return await getSetting('theme_mode') ?? 'light';
  }

  // User Profile
  Future<void> saveUserProfile({required String email, required String name, String? photoUrl}) async {
    await saveSetting('user_email', email);
    await saveSetting('user_name', name);
    if (photoUrl != null) {
      await saveSetting('user_photo_url', photoUrl);
    } else {
      await deleteSetting('user_photo_url');
    }
  }

  Future<Map<String, String?>> getUserProfile() async {
    final email = await getSetting('user_email');
    final name = await getSetting('user_name');
    final photoUrl = await getSetting('user_photo_url');
    return {
      'email': email,
      'name': name,
      'photoUrl': photoUrl,
    };
  }

  Future<void> clearUserSession() async {
    await deleteSetting('user_email');
    await deleteSetting('user_name');
    await deleteSetting('user_photo_url');
    await _secureStorage.deleteGoogleAuthToken();
  }

  // Sync status
  Future<void> saveSyncStatus({required String status, required String lastSyncedTime}) async {
    await saveSetting('sync_status', status);
    await saveSetting('sync_last_time', lastSyncedTime);
  }

  Future<Map<String, String>> getSyncStatus() async {
    final status = await getSetting('sync_status') ?? 'success';
    final lastTime = await getSetting('sync_last_time') ?? 'Never';
    return {
      'status': status,
      'lastSyncedTime': lastTime,
    };
  }

  // --- Sync Queue Helpers ---
  Future<List<Map<String, dynamic>>> getSyncQueue() async {
    if (_isWebOrTest) return [];
    final db = await _dbHelper.database;
    return await db.query('sync_queue', orderBy: 'id ASC');
  }

  Future<void> addToSyncQueue({
    required String entityType,
    required String entityId,
    required String action,
    String? payload,
  }) async {
    if (_isWebOrTest) return;
    final db = await _dbHelper.database;
    await db.insert('sync_queue', {
      'entity_type': entityType,
      'entity_id': entityId,
      'action': action,
      'payload': payload,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> removeFromSyncQueue(int id) async {
    if (_isWebOrTest) return;
    final db = await _dbHelper.database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  // --- Discord Integration Helpers ---
  Future<void> saveDiscordSyncEnabled(bool enabled) async {
    await saveSetting('discord_sync_enabled', enabled.toString());
  }

  Future<bool> getDiscordSyncEnabled() async {
    final val = await getSetting('discord_sync_enabled');
    return val == 'true'; // Default is false
  }

  Future<void> saveDiscordBotToken(String token) async {
    await saveSetting('discord_bot_token', token);
  }

  Future<String?> getDiscordBotToken() async {
    return await getSetting('discord_bot_token');
  }

  Future<void> saveDiscordChannelId(String channelId) async {
    await saveSetting('discord_channel_id', channelId);
  }

  Future<String?> getDiscordChannelId() async {
    return await getSetting('discord_channel_id');
  }

  Future<void> saveDiscordLastMsgId(String msgId) async {
    await saveSetting('discord_last_msg_id', msgId);
  }

  Future<String?> getDiscordLastMsgId() async {
    return await getSetting('discord_last_msg_id');
  }
}
