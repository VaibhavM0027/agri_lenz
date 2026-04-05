import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/crop_analysis_service.dart';
import 'comparison_screen.dart';

class CompareFlowScreen extends StatefulWidget {
  const CompareFlowScreen({super.key});

  @override
  State<CompareFlowScreen> createState() => _CompareFlowScreenState();
}

class _CompareFlowScreenState extends State<CompareFlowScreen> {
  Uint8List? _a;
  Uint8List? _b;
  var _busy = false;
  String? _error;

  Future<void> _pick(bool first) async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 88);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    setState(() {
      if (first) {
        _a = Uint8List.fromList(bytes);
      } else {
        _b = Uint8List.fromList(bytes);
      }
      _error = null;
    });
  }

  Future<void> _runCompare() async {
    if (_a == null || _b == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r1 = await CropAnalysisService.analyze(_a!);
      final r2 = await CropAnalysisService.analyze(_b!);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => ComparisonScreen(left: r1, right: r2)),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compare two leaves')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pick two photos — before/after treatment, different plants, or healthy vs damaged.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _Slot(
                    label: 'Leaf A',
                    bytes: _a,
                    onPick: () => _pick(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Slot(
                    label: 'Leaf B',
                    bytes: _b,
                    onPick: () => _pick(false),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const Spacer(),
            FilledButton.icon(
              onPressed: (_a != null && _b != null && !_busy) ? _runCompare : null,
              icon: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.compare_arrows),
              label: Text(_busy ? 'Analyzing both…' : 'Run comparison'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.label, required this.bytes, required this.onPick});

  final String label;
  final Uint8List? bytes;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPick,
          child: bytes == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 40, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 8),
                      Text(label),
                    ],
                  ),
                )
              : Image.memory(bytes!, fit: BoxFit.cover),
        ),
      ),
    );
  }
}
