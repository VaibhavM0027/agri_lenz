import 'package:flutter/material.dart';

import '../services/farmer_gamification.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  Future<Map<String, dynamic>>? _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadStats();
  }

  Future<Map<String, dynamic>> _loadStats() async {
    final streak = await FarmerGamification.getStreak();
    final totalScans = await FarmerGamification.getTotalScans();
    final xp = await FarmerGamification.getXP();
    final level = FarmerGamification.calculateLevel(xp);
    final progress = FarmerGamification.getLevelProgress(xp);
    final achievements = await FarmerGamification.getUnlockedAchievements();

    return {
      'streak': streak,
      'totalScans': totalScans,
      'xp': xp,
      'level': level,
      'progress': progress,
      'achievements': achievements,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Farmer Progress'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final stats = snapshot.data!;
          final level = stats['level'] as int;
          final xp = stats['xp'] as int;
          final progress = stats['progress'] as double;
          final streak = stats['streak'] as int;
          final totalScans = stats['totalScans'] as int;
          final achievements = stats['achievements'] as List<Achievement>;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Level Card
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: cs.primaryContainer,
                            child: Text(
                              '$level',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: cs.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Level $level Farmer',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$xp XP Total',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.7),
                            ),
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 12,
                          backgroundColor: cs.surfaceContainerHighest,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(progress * 100).toInt()}% to Level ${level + 1}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Stats Grid
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.local_fire_department,
                      value: '$streak',
                      label: 'Day Streak',
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.camera_alt,
                      value: '$totalScans',
                      label: 'Total Scans',
                      color: cs.primary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Achievements Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Achievements',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Chip(
                    label: Text('${achievements.length}/7'),
                    backgroundColor: cs.primaryContainer,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              ...achievements.map((achievement) {
                return _AchievementCard(achievement: achievement);
              }),

              if (achievements.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.emoji_events_outlined,
                          size: 64,
                          color: cs.outline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No achievements yet',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start scanning crops to unlock achievements!',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.6),
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  achievement.icon,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    achievement.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.7),
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}
