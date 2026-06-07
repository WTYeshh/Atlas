import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/settings_repository.dart';
import '../services/discord_digest_service.dart';

class ScholarState {
  final int xp;
  final int level;
  final int coins;
  final List<String> unlockedThemes;
  final String selectedTheme;

  ScholarState({
    required this.xp,
    required this.level,
    required this.coins,
    required this.unlockedThemes,
    required this.selectedTheme,
  });

  ScholarState.initial()
      : xp = 0,
        level = 1,
        coins = 0,
        unlockedThemes = const ['classic_light', 'classic_dark'],
        selectedTheme = 'classic_dark';

  ScholarState copyWith({
    int? xp,
    int? level,
    int? coins,
    List<String>? unlockedThemes,
    String? selectedTheme,
  }) {
    return ScholarState(
      xp: xp ?? this.xp,
      level: level ?? this.level,
      coins: coins ?? this.coins,
      unlockedThemes: unlockedThemes ?? this.unlockedThemes,
      selectedTheme: selectedTheme ?? this.selectedTheme,
    );
  }
}

final scholarProvider = StateNotifierProvider<ScholarNotifier, ScholarState>((ref) {
  final discordDigest = ref.watch(discordDigestServiceProvider);
  return ScholarNotifier(SettingsRepository(), discordDigest);
});

class ScholarNotifier extends StateNotifier<ScholarState> {
  final SettingsRepository _settingsRepo;
  final DiscordDigestService _discordDigest;

  ScholarNotifier(this._settingsRepo, this._discordDigest) : super(ScholarState.initial()) {
    loadScholarData();
  }

  int get xpNeededForNextLevel => state.level * 150;

  String getScholarTitle(int level) {
    if (level == 1) return 'Novice Scribe 📜';
    if (level == 2) return 'Apprentice Scholar 📚';
    if (level == 3) return 'Journeyman Sage 🔮';
    if (level == 4) return 'Master of Archives 🏛️';
    if (level == 5) return 'Academic Archmage 💫';
    return 'Grand Atlas Titan 👑';
  }

  Future<void> loadScholarData() async {
    try {
      final xpStr = await _settingsRepo.getSetting('academic_xp');
      final levelStr = await _settingsRepo.getSetting('academic_level');
      final coinsStr = await _settingsRepo.getSetting('academic_coins');
      final themesStr = await _settingsRepo.getSetting('academic_unlocked_themes');
      final selectedThemeStr = await _settingsRepo.getSetting('academic_selected_theme');

      final xp = int.tryParse(xpStr ?? '0') ?? 0;
      final level = int.tryParse(levelStr ?? '1') ?? 1;
      final coins = int.tryParse(coinsStr ?? '0') ?? 0;
      final selectedTheme = selectedThemeStr ?? 'classic_dark';

      List<String> unlockedThemes = ['classic_light', 'classic_dark'];
      if (themesStr != null && themesStr.isNotEmpty) {
        unlockedThemes = themesStr.split(',');
      }

      state = ScholarState(
        xp: xp,
        level: level,
        coins: coins,
        unlockedThemes: unlockedThemes,
        selectedTheme: selectedTheme,
      );
    } catch (e) {
      print('ScholarNotifier: Load error: $e');
    }
  }

  Future<Map<String, dynamic>> completeTask(String priority) async {
    int xpReward = 15;
    int coinReward = 5;
    if (priority == 'high') {
      xpReward = 50;
      coinReward = 15;
    } else if (priority == 'medium') {
      xpReward = 30;
      coinReward = 10;
    }

    int newXp = state.xp + xpReward;
    int newLevel = state.level;
    int newCoins = state.coins + coinReward;
    bool leveledUp = false;

    while (newXp >= (newLevel * 150)) {
      newXp -= (newLevel * 150);
      newLevel += 1;
      leveledUp = true;
      newCoins += newLevel * 10; // Level Up bonus (10 * level)
    }

    state = state.copyWith(
      xp: newXp,
      level: newLevel,
      coins: newCoins,
    );

    await _settingsRepo.saveSetting('academic_xp', newXp.toString());
    await _settingsRepo.saveSetting('academic_level', newLevel.toString());
    await _settingsRepo.saveSetting('academic_coins', newCoins.toString());

    if (leveledUp) {
      final titleName = getScholarTitle(newLevel);
      _discordDigest.sendLevelUpPost(newLevel, titleName);
    }

    return {
      'xpGained': xpReward,
      'coinsGained': coinReward,
      'leveledUp': leveledUp,
      'newLevel': newLevel,
    };
  }

  Future<void> selectTheme(String themeKey) async {
    if (!state.unlockedThemes.contains(themeKey)) return;
    state = state.copyWith(selectedTheme: themeKey);
    await _settingsRepo.saveSetting('academic_selected_theme', themeKey);
  }

  Future<Map<String, dynamic>?> rollGacha() async {
    if (state.coins < 100) return null;

    final newCoins = state.coins - 100;
    state = state.copyWith(coins: newCoins);
    await _settingsRepo.saveSetting('academic_coins', newCoins.toString());

    final rand = Random().nextDouble();
    String themeKey;
    String themeName;
    String rarity;

    if (rand < 0.07) {
      themeKey = 'amoled_gold';
      themeName = 'AMOLED Gold 🏆';
      rarity = 'Legendary';
    } else if (rand < 0.25) {
      themeKey = 'neon_cyberpunk';
      themeName = 'Neon Cyberpunk 👾';
      rarity = 'Epic';
    } else if (rand < 0.55) {
      themeKey = 'warm_sepia';
      themeName = 'Warm Sepia ☕';
      rarity = 'Rare';
    } else {
      themeKey = 'forest_green';
      themeName = 'Forest Green 🌲';
      rarity = 'Common';
    }

    final isDuplicate = state.unlockedThemes.contains(themeKey);

    if (isDuplicate) {
      final refundCoins = state.coins + 40;
      state = state.copyWith(coins: refundCoins);
      await _settingsRepo.saveSetting('academic_coins', refundCoins.toString());
    } else {
      final updatedThemes = [...state.unlockedThemes, themeKey];
      state = state.copyWith(unlockedThemes: updatedThemes);
      await _settingsRepo.saveSetting(
        'academic_unlocked_themes',
        updatedThemes.join(','),
      );

      if (rarity == 'Epic' || rarity == 'Legendary') {
        _discordDigest.sendGachaDropPost(themeName, rarity);
      }
    }

    return {
      'themeKey': themeKey,
      'themeName': themeName,
      'rarity': rarity,
      'isDuplicate': isDuplicate,
      'refund': isDuplicate ? 40 : 0,
    };
  }
}
