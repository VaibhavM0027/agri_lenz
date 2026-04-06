import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/leaf_visual_analyzer.dart';
import '../models/analysis_models.dart';

/// Simulated AR scanner with live health feedback overlay
class QuickARScanner extends StatefulWidget {
  const QuickARScanner({
    super.key,
    required this.onCaptureComplete,
  });

  final void Function(Uint8List imageBytes) onCaptureComplete;

  @override
  State<QuickARScanner> createState() => _QuickARScannerState();
}

class _QuickARScannerState extends State<QuickARScanner> {
  Uint8List? _previewImage;
  LeafVisualFeatures? _features;
  bool _isAnalyzing = false;

  Future<void> _capturePhoto() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 90,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();
      
      setState(() {
        _previewImage = bytes;
        _isAnalyzing = true;
      });

      // Quick analysis for AR feedback
      final features = LeafVisualAnalyzer.analyzeEnhanced(bytes);
      
      setState(() {
        _features = features;
        _isAnalyzing = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isAnalyzing = false);
      }
    }
  }

  Color _getHealthColor() {
    if (_features == null) return Colors.grey;
    
    final f = _features!;
    
    if (f.greenRatio > 0.35 && f.brownRatio < 0.08 && f.yellowRatio < 0.10) {
      return Colors.green;
    }
    
    if (f.brownRatio < 0.20 && f.yellowRatio < 0.22) {
      return Colors.orange;
    }
    
    return Colors.red;
  }

  String _getHealthStatus() {
    if (_features == null) return 'Tap to scan';
    
    final f = _features!;
    
    if (f.greenRatio > 0.35 && f.brownRatio < 0.08 && f.yellowRatio < 0.10) {
      return '✅ Healthy';
    }
    
    if (f.brownRatio < 0.20 && f.yellowRatio < 0.22) {
      return '⚠️ Monitor';
    }
    
    return '❌ Check Now';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick AR Scan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showHelp(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Preview area
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: cs.outline, width: 2),
                borderRadius: BorderRadius.circular(16),
                color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              ),
              child: _previewImage != null
                  ? Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.memory(
                              _previewImage!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        
                        // Health overlay badge
                        Positioned(
                          top: 16,
                          left: 16,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: _getHealthColor().withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isAnalyzing)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                else
                                  Icon(
                                    Icons.health_and_safety,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                const SizedBox(width: 8),
                                Text(
                                  _getHealthStatus(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Visual metrics overlay
                        if (_features != null && !_isAnalyzing)
                          Positioned(
                            bottom: 16,
                            left: 16,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    '📊 Quick Metrics',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _MetricRow(
                                    label: 'Green',
                                    value: _features!.greenRatio,
                                    color: Colors.green,
                                  ),
                                  _MetricRow(
                                    label: 'Yellow',
                                    value: _features!.yellowRatio,
                                    color: Colors.yellow,
                                  ),
                                  _MetricRow(
                                    label: 'Brown',
                                    value: _features!.brownRatio,
                                    color: Colors.brown,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            size: 80,
                            color: cs.primary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Tap button below to scan',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          
          // Capture button
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _previewImage != null
                        ? () {
                            setState(() {
                              _previewImage = null;
                              _features = null;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retake'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _previewImage != null
                        ? () => widget.onCaptureComplete(_previewImage!)
                        : _capturePhoto,
                    icon: Icon(
                      _previewImage != null ? Icons.check : Icons.camera_alt,
                    ),
                    label: Text(
                      _previewImage != null ? 'Full Analysis' : 'Capture',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quick AR Scanner'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📸 Take a photo of the leaf'),
            SizedBox(height: 8),
            Text('👁️ See instant health feedback'),
            SizedBox(height: 8),
            Text('🟢 Green = Healthy | 🟡 Orange = Monitor | 🔴 Red = Action needed'),
            SizedBox(height: 8),
            Text('✅ Tap "Full Analysis" for detailed diagnosis'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$label:',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(value * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
