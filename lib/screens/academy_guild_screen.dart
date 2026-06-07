import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/scholar_provider.dart';

class AcademyGuildScreen extends ConsumerStatefulWidget {
  const AcademyGuildScreen({super.key});

  @override
  ConsumerState<AcademyGuildScreen> createState() => _AcademyGuildScreenState();
}

class _AcademyGuildScreenState extends ConsumerState<AcademyGuildScreen>
    with SingleTickerProviderStateMixin {
  bool _isSpinning = false;
  String _spinnerText = 'TAP CHEST TO SPIN';
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _triggerGachaSpin() async {
    final notifier = ref.read(scholarProvider.notifier);
    final state = ref.read(scholarProvider);

    if (state.coins < 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not enough Atlas Coins! Complete tasks to earn more. 🪙'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isSpinning = true;
    });

    final pool = [
      'Forest Green 🌲',
      'Warm Sepia ☕',
      'Neon Cyberpunk 👾',
      'AMOLED Gold 🏆',
      'Searching Chest...',
    ];

    // Fun spinning text ticker loop
    int counter = 0;
    Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (counter >= 10) {
        timer.cancel();
        return;
      }
      setState(() {
        _spinnerText = pool[counter % pool.length];
      });
      counter++;
    });

    // Wait 1.8 seconds, then roll Gacha
    await Future.delayed(const Duration(milliseconds: 1800));

    final result = await notifier.rollGacha();

    setState(() {
      _isSpinning = false;
      _spinnerText = 'TAP CHEST TO SPIN';
    });

    if (result != null && mounted) {
      final themeName = result['themeName'] as String;
      final rarity = result['rarity'] as String;
      final isDuplicate = result['isDuplicate'] as bool;
      final refund = result['refund'] as int;

      // Show beautiful rewards dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildRewardsDialog(context, themeName, rarity, isDuplicate, refund),
      );
    }
  }

  Widget _buildRewardsDialog(
    BuildContext context,
    String themeName,
    String rarity,
    bool isDuplicate,
    int refund,
  ) {
    Color rarityColor = Colors.green;
    if (rarity == 'Rare') rarityColor = Colors.blueAccent;
    if (rarity == 'Epic') rarityColor = Colors.purpleAccent;
    if (rarity == 'Legendary') rarityColor = Colors.amber;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: rarityColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: rarityColor.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 2,
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isDuplicate ? 'DUPLICATE ROLL' : 'GACHA UNLOCK!',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isDuplicate ? Colors.grey : rarityColor,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            Icon(
              isDuplicate ? Icons.copy_outlined : Icons.card_giftcard_outlined,
              size: 60,
              color: rarityColor,
            ),
            const SizedBox(height: 16),
            Text(
              themeName,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: rarityColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                rarity.toUpperCase(),
                style: TextStyle(
                  color: rarityColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (isDuplicate)
              Text(
                'You already owned this theme!\nRefunded 🪙 $refund Coins.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, height: 1.4),
              )
            else
              const Text(
                'This theme is now available in your customizer inventory!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: rarityColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
              child: Text(
                'AWESOME',
                style: TextStyle(
                  color: rarity == 'Legendary' ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scholarState = ref.watch(scholarProvider);
    final scholarNotifier = ref.read(scholarProvider.notifier);

    final title = scholarNotifier.getScholarTitle(scholarState.level);
    final xpNeeded = scholarNotifier.xpNeededForNextLevel;
    final xpPercent = (scholarState.xp / xpNeeded).clamp(0.0, 1.0);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. SCHOLAR PROFILE STATUS CARD
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Level Circular Indicator
                        GestureDetector(
                          onTap: () {
                            // Secret debug grant (adds 100 coins, 150 XP) on tapping level badge
                            scholarNotifier.debugGrant(100, 150);
                          },
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).primaryColor,
                                width: 2,
                              ),
                              color: Theme.of(context).primaryColor.withOpacity(0.05),
                            ),
                            child: Center(
                              child: Text(
                                'Lvl\n${scholarState.level}',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Title and XP Text
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Progress to Next Level: ${scholarState.xp} / $xpNeeded XP',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // XP Linear Progress Bar
                    Container(
                      height: 10,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: xpPercent,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Coins counter row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Available Balance:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Row(
                          children: [
                            const Text(
                              '🪙 ',
                              style: TextStyle(fontSize: 18),
                            ),
                            Text(
                              '${scholarState.coins} Coins',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 2. GACHA SPINNING CHEST CARD
            Text(
              'SCHOLAR GUILD SHOP',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: Theme.of(context).primaryColor.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Center(
                  child: Column(
                    children: [
                      Text(
                        'ATLAS MYSTERY CHEST',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Unlock custom themes to style your application!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Animated Gacha Chest
                      GestureDetector(
                        onTap: _isSpinning ? null : _triggerGachaSpin,
                        child: ScaleTransition(
                          scale: _isSpinning ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                          child: Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).primaryColor.withOpacity(0.2),
                                width: 2,
                              ),
                              color: Theme.of(context).primaryColor.withOpacity(0.02),
                            ),
                            child: Center(
                              child: Icon(
                                _isSpinning ? Icons.explore : Icons.inventory_2_outlined,
                                size: 54,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _spinnerText,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isSpinning ? null : _triggerGachaSpin,
                        icon: const Icon(Icons.circle_outlined, size: 16),
                        label: const Text('ROLL GACHA (50 COINS)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Theme.of(context).colorScheme.brightness == Brightness.dark
                              ? Colors.black
                              : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 3. THEMES INVENTORY CUSTOMIZER
            Text(
              'UNLOCKED CUSTOMIZATIONS',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: Theme.of(context).primaryColor.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 10),
            ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildThemeInventoryItem(
                  context: context,
                  themeKey: 'classic_dark',
                  displayName: 'Classic Dark 🎨',
                  rarity: 'Common',
                  isUnlocked: scholarState.unlockedThemes.contains('classic_dark'),
                  isActive: scholarState.selectedTheme == 'classic_dark',
                  onUse: () => scholarNotifier.selectTheme('classic_dark'),
                ),
                _buildThemeInventoryItem(
                  context: context,
                  themeKey: 'classic_light',
                  displayName: 'Classic Light ☀️',
                  rarity: 'Common',
                  isUnlocked: scholarState.unlockedThemes.contains('classic_light'),
                  isActive: scholarState.selectedTheme == 'classic_light',
                  onUse: () => scholarNotifier.selectTheme('classic_light'),
                ),
                _buildThemeInventoryItem(
                  context: context,
                  themeKey: 'forest_green',
                  displayName: 'Forest Green 🌲',
                  rarity: 'Common',
                  isUnlocked: scholarState.unlockedThemes.contains('forest_green'),
                  isActive: scholarState.selectedTheme == 'forest_green',
                  onUse: () => scholarNotifier.selectTheme('forest_green'),
                ),
                _buildThemeInventoryItem(
                  context: context,
                  themeKey: 'warm_sepia',
                  displayName: 'Warm Sepia ☕',
                  rarity: 'Rare',
                  isUnlocked: scholarState.unlockedThemes.contains('warm_sepia'),
                  isActive: scholarState.selectedTheme == 'warm_sepia',
                  onUse: () => scholarNotifier.selectTheme('warm_sepia'),
                ),
                _buildThemeInventoryItem(
                  context: context,
                  themeKey: 'neon_cyberpunk',
                  displayName: 'Neon Cyberpunk 👾',
                  rarity: 'Epic',
                  isUnlocked: scholarState.unlockedThemes.contains('neon_cyberpunk'),
                  isActive: scholarState.selectedTheme == 'neon_cyberpunk',
                  onUse: () => scholarNotifier.selectTheme('neon_cyberpunk'),
                ),
                _buildThemeInventoryItem(
                  context: context,
                  themeKey: 'amoled_gold',
                  displayName: 'AMOLED Gold 🏆',
                  rarity: 'Legendary',
                  isUnlocked: scholarState.unlockedThemes.contains('amoled_gold'),
                  isActive: scholarState.selectedTheme == 'amoled_gold',
                  onUse: () => scholarNotifier.selectTheme('amoled_gold'),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeInventoryItem({
    required BuildContext context,
    required String themeKey,
    required String displayName,
    required String rarity,
    required bool isUnlocked,
    required bool isActive,
    required VoidCallback onUse,
  }) {
    Color rarityColor = Colors.grey;
    if (rarity == 'Common') rarityColor = Colors.green;
    if (rarity == 'Rare') rarityColor = Colors.blue;
    if (rarity == 'Epic') rarityColor = Colors.purple;
    if (rarity == 'Legendary') rarityColor = Colors.amber;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Text(
          displayName,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            color: isUnlocked ? null : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
          ),
        ),
        subtitle: Row(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: rarityColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                rarity.toUpperCase(),
                style: TextStyle(
                  color: rarityColor,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: isUnlocked
            ? (isActive
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).primaryColor, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'ACTIVE',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )
                : OutlinedButton(
                    onPressed: onUse,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('USE'),
                  ))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 16, color: Theme.of(context).dividerColor),
                  const SizedBox(width: 4),
                  Text(
                    'LOCKED',
                    style: TextStyle(color: Theme.of(context).dividerColor, fontSize: 12),
                  ),
                ],
              ),
      ),
    );
  }
}
