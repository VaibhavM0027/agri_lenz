import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'processing_screen.dart';

/// After a **leaf** image is chosen, optionally attach a **soil surface** photo before analysis.
class LeafSoilPrepareScreen extends StatefulWidget {
  const LeafSoilPrepareScreen({super.key, required this.leafBytes});

  final Uint8List leafBytes;

  @override
  State<LeafSoilPrepareScreen> createState() => _LeafSoilPrepareScreenState();
}

class _LeafSoilPrepareScreenState extends State<LeafSoilPrepareScreen> {
  Uint8List? _soilBytes;

  Future<void> _pickSoil(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (file == null || !mounted) return;
    final b = await file.readAsBytes();
    setState(() => _soilBytes = Uint8List.fromList(b));
  }

  void _continue() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ProcessingScreen(
          imageBytes: widget.leafBytes,
          soilImageBytes: _soilBytes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Leaf + optional soil')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Add a soil surface photo to improve moisture estimation (dark/wet vs light/cracked). '
            'You can skip — the app still estimates moisture from leaf cues.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 20),
          Text('Leaf (required)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.memory(widget.leafBytes, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 24),
          Text('Soil photo (optional)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Material(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: _soilBytes == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.landscape_outlined, size: 48, color: cs.primary),
                          const SizedBox(height: 8),
                          Text('No soil image yet', style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    )
                  : Image.memory(_soilBytes!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickSoil(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Soil camera'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickSoil(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Soil gallery'),
                ),
              ),
            ],
          ),
          if (_soilBytes != null)
            TextButton.icon(
              onPressed: () => setState(() => _soilBytes = null),
              icon: const Icon(Icons.clear),
              label: const Text('Remove soil photo'),
            ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _continue,
            icon: const Icon(Icons.analytics_outlined),
            label: const Text('Continue to AI analysis'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
        ],
      ),
    );
  }
}
