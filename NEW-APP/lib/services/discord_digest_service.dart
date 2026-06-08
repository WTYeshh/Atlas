import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../core/config.dart';
import '../repositories/settings_repository.dart';
import '../providers/calendar_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/repository_providers.dart';
import '../models/event_model.dart';

final discordDigestServiceProvider = Provider<DiscordDigestService>((ref) {
  return DiscordDigestService(ref);
});

class DiscordDigestService {
  final Ref _ref;
  final SettingsRepository _settingsRepo = SettingsRepository();

  DiscordDigestService(this._ref);

  Future<void> checkAndTriggerDigests() async {}
  Future<bool> sendDailyDigest({bool force = false}) async => false;
  Future<bool> sendWeeklyDigest({bool force = false}) async => false;
  Future<bool> sendLevelUpPost(int newLevel, String newTitle) async => false;
  Future<bool> sendGachaDropPost(String themeName, String rarity) async => false;
  Future<bool> sendMilestoneCelebrationPost(int taskCount) async => false;
}
