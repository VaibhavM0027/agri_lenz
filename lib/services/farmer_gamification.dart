import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Gamification system to encourage regular crop monitoring
class FarmerGamification {
  static const String _streakKey = 'farmer_streak';
  static const String _lastScanDateKey = 'last_scan_date';
  static const String _totalScansKey = 'total_scans';
  static const String _achievementsKey = 'unlocked_achievements';
  static const String _xpKey = 'farmer_xp';

  /// Current streak (consecutive days of scanning)
  static Future<int> getStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_streakKey) ?? 0;
  }

  /// Total number of scans performed
  static Future<int> getTotalScans() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_totalScansKey) ?? 0;
  }

  /// Experience points
  static Future<int> getXP() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_xpKey) ?? 0;
  }

  /// Calculate level from XP (each level requires 100 more XP than previous)
  static int calculateLevel(int xp) {
    if (xp < 100) return 1;
    var level = 1;
    var xpNeeded = 100;
    var totalXp = 0;

    while (totalXp + xpNeeded <= xp) {
      totalXp += xpNeeded;
      level++;
      xpNeeded += 100;
    }

    return level;
  }

  /// Progress to next level (0.0 - 1.0)
  static double getLevelProgress(int xp) {
    final level = calculateLevel(xp);
    if (level == 1) return xp / 100;

    var xpForCurrentLevel = 0;
    for (var i = 1; i < level; i++) {
      xpForCurrentLevel += i * 100;
    }

    final xpInCurrentLevel = xp - xpForCurrentLevel;
    final xpNeededForNext = level * 100;

    return xpInCurrentLevel / xpNeededForNext;
  }

  /// Record a scan and update streak/achievements
  static Future<GamificationUpdate> recordScan() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Get last scan date
    final lastScanMillis = prefs.getInt(_lastScanDateKey);
    final lastScanDate = lastScanMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(lastScanMillis)
        : null;

    var streak = prefs.getInt(_streakKey) ?? 0;
    final totalScans = (prefs.getInt(_totalScansKey) ?? 0) + 1;
    final currentXP = prefs.getInt(_xpKey) ?? 0;

    // Update streak
    if (lastScanDate != null) {
      final lastDate = DateTime(
        lastScanDate.year,
        lastScanDate.month,
        lastScanDate.day,
      );
      final daysDiff = today.difference(lastDate).inDays;

      if (daysDiff == 1) {
        // Consecutive day
        streak++;
      } else if (daysDiff > 1) {
        // Streak broken
        streak = 1;
      }
      // If same day, streak stays the same
    } else {
      // First scan
      streak = 1;
    }

    // Calculate XP gain
    var xpGained = 10; // Base XP
    if (streak >= 7) xpGained += 20; // Weekly streak bonus
    if (streak >= 30) xpGained += 30; // Monthly streak bonus
    if (totalScans % 10 == 0) xpGained += 15; // Milestone bonus

    final newXP = currentXP + xpGained;
    final oldLevel = calculateLevel(currentXP);
    final newLevel = calculateLevel(newXP);
    final leveledUp = newLevel > oldLevel;

    // Save data
    await prefs.setInt(_streakKey, streak);
    await prefs.setInt(_lastScanDateKey, now.millisecondsSinceEpoch);
    await prefs.setInt(_totalScansKey, totalScans);
    await prefs.setInt(_xpKey, newXP);

    // Check achievements
    final unlockedAchievements = await _checkAndUnlockAchievements(
      streak,
      totalScans,
      newLevel,
    );

    return GamificationUpdate(
      newStreak: streak,
      totalScans: totalScans,
      xpGained: xpGained,
      newXP: newXP,
      newLevel: newLevel,
      leveledUp: leveledUp,
      unlockedAchievements: unlockedAchievements,
    );
  }

  static Future<List<Achievement>> _checkAndUnlockAchievements(
    int streak,
    int totalScans,
    int level,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final unlockedIds = prefs.getStringList(_achievementsKey) ?? [];
    final newlyUnlocked = <Achievement>[];

    final allAchievements = [
      Achievement(
        id: 'first_scan',
        title: 'First Steps',
        description: 'Complete your first crop scan',
        icon: '🌱',
        condition: () => totalScans >= 1,
      ),
      Achievement(
        id: 'week_warrior',
        title: 'Week Warrior',
        description: 'Maintain a 7-day scanning streak',
        icon: '🔥',
        condition: () => streak >= 7,
      ),
      Achievement(
        id: 'monthly_master',
        title: 'Monthly Master',
        description: 'Maintain a 30-day scanning streak',
        icon: '👑',
        condition: () => streak >= 30,
      ),
      Achievement(
        id: 'scan_century',
        title: 'Century Scanner',
        description: 'Complete 100 crop scans',
        icon: '💯',
        condition: () => totalScans >= 100,
      ),
      Achievement(
        id: 'level_5',
        title: 'Rising Farmer',
        description: 'Reach Level 5',
        icon: '⭐',
        condition: () => level >= 5,
      ),
      Achievement(
        id: 'level_10',
        title: 'Expert Agronomist',
        description: 'Reach Level 10',
        icon: '🏆',
        condition: () => level >= 10,
      ),
      Achievement(
        id: 'dedicated_farmer',
        title: 'Dedicated Farmer',
        description: 'Complete 50 crop scans',
        icon: '🚜',
        condition: () => totalScans >= 50,
      ),
    ];

    for (final achievement in allAchievements) {
      if (!unlockedIds.contains(achievement.id) && achievement.condition()) {
        unlockedIds.add(achievement.id);
        newlyUnlocked.add(achievement);
      }
    }

    if (newlyUnlocked.isNotEmpty) {
      await prefs.setStringList(_achievementsKey, unlockedIds);
    }

    return newlyUnlocked;
  }

  /// Get all unlocked achievements
  static Future<List<Achievement>> getUnlockedAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    final unlockedIds = prefs.getStringList(_achievementsKey) ?? [];

    return [
      Achievement(
        id: 'first_scan',
        title: 'First Steps',
        description: 'Complete your first crop scan',
        icon: '🌱',
        condition: () => true,
      ),
      Achievement(
        id: 'week_warrior',
        title: 'Week Warrior',
        description: 'Maintain a 7-day scanning streak',
        icon: '🔥',
        condition: () => true,
      ),
      Achievement(
        id: 'monthly_master',
        title: 'Monthly Master',
        description: 'Maintain a 30-day scanning streak',
        icon: '👑',
        condition: () => true,
      ),
      Achievement(
        id: 'scan_century',
        title: 'Century Scanner',
        description: 'Complete 100 crop scans',
        icon: '💯',
        condition: () => true,
      ),
      Achievement(
        id: 'level_5',
        title: 'Rising Farmer',
        description: 'Reach Level 5',
        icon: '⭐',
        condition: () => true,
      ),
      Achievement(
        id: 'level_10',
        title: 'Expert Agronomist',
        description: 'Reach Level 10',
        icon: '🏆',
        condition: () => true,
      ),
      Achievement(
        id: 'dedicated_farmer',
        title: 'Dedicated Farmer',
        description: 'Complete 50 crop scans',
        icon: '🚜',
        condition: () => true,
      ),
    ].where((a) => unlockedIds.contains(a.id)).toList();
  }
}

class GamificationUpdate {
  const GamificationUpdate({
    required this.newStreak,
    required this.totalScans,
    required this.xpGained,
    required this.newXP,
    required this.newLevel,
    required this.leveledUp,
    required this.unlockedAchievements,
  });

  final int newStreak;
  final int totalScans;
  final int xpGained;
  final int newXP;
  final int newLevel;
  final bool leveledUp;
  final List<Achievement> unlockedAchievements;
}

class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.condition,
  });

  final String id;
  final String title;
  final String description;
  final String icon;
  final bool Function() condition;
}
