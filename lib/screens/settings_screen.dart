import 'package:flutter/material.dart';

import '../data/history_repository.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Appearance', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: cs.primary)),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
            ],
            selected: {isDark ? ThemeMode.dark : ThemeMode.light},
            onSelectionChanged: (s) => onThemeModeChanged(s.first),
          ),
          const SizedBox(height: 24),
          Text('Data', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: cs.primary)),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Clear scan history'),
            subtitle: const Text('Removes saved photos and metadata on this device'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear all history?'),
                  content: const Text('This cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await HistoryRepository.clearAll();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('History cleared')));
                }
              }
            },
          ),
          const SizedBox(height: 24),
          Text('About', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: cs.primary)),
          const SizedBox(height: 8),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Agri Lenz'),
            subtitle: Text(
              'On-device leaf analysis with TensorFlow Lite (optional) and fused multi-scale vision. '
              'Train or replace crop_model.tflite so class outputs match labels.txt for maximum accuracy.',
            ),
          ),
        ],
      ),
    );
  }
}
