import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'achievements_screen.dart';
import 'leaf_soil_prepare_screen.dart';
import 'processing_screen.dart';
import 'quick_ar_scanner.dart';
import 'smart_capture_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenCompare});

  final VoidCallback onOpenCompare;

  Future<void> _openPicker(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 88,
    );
    if (file == null || !context.mounted) return;
    final bytes = await file.readAsBytes();
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LeafSoilPrepareScreen(leafBytes: Uint8List.fromList(bytes)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agri Lenz'),
        actions: [
          IconButton(
            tooltip: 'View achievements',
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const AchievementsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.emoji_events_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Icon(Icons.eco_rounded, size: 72, color: cs.primary),
              const SizedBox(height: 16),
              Text(
                'AI-Powered Crop Health Analysis',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Advanced disease detection with treatment plans, progress tracking, and smart recommendations — built for real farmers.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.75),
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onOpenCompare,
                icon: const Icon(Icons.compare_arrows),
                label: const Text('Compare two leaves'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => QuickARScanner(
                        onCaptureComplete: (leafBytes) {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ProcessingScreen(
                                imageBytes: leafBytes,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Quick AR Scanner'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => SmartCaptureScreen(
                        onImageCaptured: (leafBytes, soilBytes) {
                          Navigator.of(context).pop();
                          // Navigate to processing with both images
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ProcessingScreen(
                                imageBytes: leafBytes,
                                soilImageBytes: soilBytes,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Smart Capture Guide'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '💡 Smart Capture helps you take the perfect photo for accurate diagnosis',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.6),
                      fontStyle: FontStyle.italic,
                    ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
