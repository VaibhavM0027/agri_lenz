import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class SmartCaptureScreen extends StatefulWidget {
  const SmartCaptureScreen({
    super.key,
    this.onImageCaptured,
  });

  final void Function(Uint8List imageBytes, Uint8List? soilImageBytes)? onImageCaptured;

  @override
  State<SmartCaptureScreen> createState() => _SmartCaptureScreenState();
}

class _SmartCaptureScreenState extends State<SmartCaptureScreen> {
  Uint8List? _previewBytes;
  Uint8List? _soilPreviewBytes;
  final List<String> _tips = [
    '📸 Capture in natural daylight for best results',
    '🎯 Focus on a single leaf showing symptoms',
    '📏 Fill 70-80% of frame with the leaf',
    '✨ Avoid harsh shadows or overexposure',
    '🔍 Include both healthy and affected areas',
    '💧 For soil moisture, photograph soil at root level',
  ];

  int _currentTipIndex = 0;

  Future<void> _captureLeafPhoto() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 90,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _previewBytes = bytes;
        });
        
        // Show success feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 12),
                  Text('Leaf photo captured successfully!'),
                ],
              ),
              backgroundColor: Colors.green.shade50,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error capturing photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _captureSoilPhoto() async {
    try {
      final picker = ImagePicker();
      // Show dialog to choose camera or gallery
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Soil Photo Source'),
          content: const Text('Would you like to take a new photo or choose from gallery?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
              child: const Text('Gallery'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Camera'),
            ),
          ],
        ),
      );
      
      if (source == null) return; // User cancelled
      
      final image = await picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _soilPreviewBytes = bytes;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 12),
                  Text('Soil photo captured!'),
                ],
              ),
              backgroundColor: Colors.green.shade50,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error capturing soil photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _previewBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _proceedToAnalysis() {
    if (_previewBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture a leaf photo first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    widget.onImageCaptured?.call(_previewBytes!, _soilPreviewBytes);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Photo Capture'),
        actions: [
          IconButton(
            tooltip: 'Next tip',
            onPressed: () {
              setState(() {
                _currentTipIndex = (_currentTipIndex + 1) % _tips.length;
              });
            },
            icon: const Icon(Icons.lightbulb_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Tips Card
          Card(
            color: cs.primaryContainer.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tips_and_updates_outlined, color: cs.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Pro Tip ${_currentTipIndex + 1}/${_tips.length}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _tips[_currentTipIndex],
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.4,
                        ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Leaf Photo Section
          Text(
            'Step 1: Capture Leaf Photo',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          if (_previewBytes != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.memory(
                      _previewBytes!,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filledTonal(
                    onPressed: () {
                      setState(() {
                        _previewBytes = null;
                      });
                    },
                    icon: const Icon(Icons.close),
                    tooltip: 'Remove photo',
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check, size: 18, color: Colors.white),
                        const SizedBox(width: 4),
                        const Text(
                          'Ready!',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          else
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(
                  color: cs.outline,
                  width: 2,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(16),
                color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.camera_alt_outlined,
                    size: 64,
                    color: cs.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No leaf photo captured yet',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _captureLeafPhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take Photo'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Soil Photo Section (Optional)
          Text(
            'Step 2: Soil Photo (Optional)',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Helps estimate soil moisture for better recommendations',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 12),

          if (_soilPreviewBytes != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.memory(
                      _soilPreviewBytes!,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filledTonal(
                    onPressed: () {
                      setState(() {
                        _soilPreviewBytes = null;
                      });
                    },
                    icon: const Icon(Icons.close),
                    tooltip: 'Remove photo',
                  ),
                ),
              ],
            )
          else
            Container(
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(
                  color: cs.outline.withValues(alpha: 0.5),
                  width: 2,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(12),
                color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.landscape_outlined,
                    size: 48,
                    color: cs.primary.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Optional: Capture soil at root level',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          OutlinedButton.icon(
            onPressed: _captureSoilPhoto,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Capture Soil Photo'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),

          const SizedBox(height: 32),

          // Quality Checklist
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✅ Quality Checklist',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _ChecklistItem(
                    checked: _previewBytes != null,
                    text: 'Leaf photo captured',
                  ),
                  _ChecklistItem(
                    checked: true,
                    text: 'Good lighting conditions',
                  ),
                  _ChecklistItem(
                    checked: true,
                    text: 'Leaf fills most of frame',
                  ),
                  _ChecklistItem(
                    checked: _soilPreviewBytes != null,
                    text: 'Soil photo (optional)',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Proceed Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _previewBytes != null ? _proceedToAnalysis : null,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Analyze Crop Health'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({
    required this.checked,
    required this.text,
  });

  final bool checked;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            checked ? Icons.check_circle : Icons.radio_button_unchecked,
            color: checked ? Colors.green : cs.outline,
            size: 22,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: checked ? null : cs.onSurface.withValues(alpha: 0.5),
                ),
          ),
        ],
      ),
    );
  }
}
