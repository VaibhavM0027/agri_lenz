import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/analysis_models.dart';
import '../services/crop_analysis_service.dart';
import 'results_screen.dart';

class _MoistureInputResult {
  const _MoistureInputResult({
    required this.fieldObservation,
    required this.sensor,
  });

  final SoilMoistureLevel? fieldObservation;
  final OptionalSensorSnapshot sensor;
}

class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({
    super.key,
    required this.imageBytes,
    this.soilImageBytes,
  });

  final Uint8List imageBytes;
  final Uint8List? soilImageBytes;

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  String? _error;
  var _awaitingMoisture = true;

  _MoistureInputResult? _inputForRun;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showMoistureSheet());
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _showMoistureSheet() async {
    if (!mounted) return;
    final soilAttached = widget.soilImageBytes != null && widget.soilImageBytes!.isNotEmpty;
    final result = await showModalBottomSheet<_MoistureInputResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _MoistureSheetBody(soilImageAttached: soilAttached),
    );
    if (!mounted) return;
    _inputForRun = result ??
        const _MoistureInputResult(
          fieldObservation: null,
          sensor: OptionalSensorSnapshot(),
        );
    setState(() => _awaitingMoisture = false);
    await _analyze();
  }

  Future<void> _analyze() async {
    setState(() => _error = null);
    final input = _inputForRun ??
        const _MoistureInputResult(fieldObservation: null, sensor: OptionalSensorSnapshot());
    
    try {
      // Ensure we're not blocking UI
      await Future.delayed(Duration(milliseconds: 50));
      
      // Validate image bytes before processing
      if (widget.imageBytes.isEmpty) {
        throw Exception('Image data is empty. Please capture a new photo.');
      }
      
      print('Starting analysis with image size: ${widget.imageBytes.lengthInBytes} bytes');
      
      // Add timeout to prevent infinite hanging
      final report = await CropAnalysisService.analyze(
        widget.imageBytes,
        soilImageBytes: widget.soilImageBytes,
        soilMoisture: input.fieldObservation,
        sensor: input.sensor,
      ).timeout(
        Duration(seconds: 45), // Increased to 45 seconds for large images
        onTimeout: () {
          throw TimeoutException('Analysis took too long. Please try with a smaller image or retake the photo.');
        },
      );
      
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => ResultsScreen(report: report)),
      );
    } catch (e, stackTrace) {
      debugPrint('Analysis error: $e\n$stackTrace');
      if (!mounted) return;
      setState(() => _error = 'Analysis failed: ${e.toString()}');
      
      // Show user-friendly error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString().substring(0, e.toString().length > 100 ? 100 : e.toString().length)}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _analyze(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Analyzing')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_awaitingMoisture)
                Text(
                  'Tell us about soil moisture (optional)…',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                )
              else if (_error == null) ...[
                ScaleTransition(
                  scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                    CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                  ),
                  child: SizedBox(
                    width: 88,
                    height: 88,
                    child: CircularProgressIndicator(
                      strokeWidth: 6,
                      color: cs.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Analyzing with AI…',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Leaf CNN + vision fusion'
                  '${widget.soilImageBytes != null ? ' + soil appearance' : ''}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                ),
              ],
              if (_error != null) ...[
                Icon(Icons.error_outline, size: 48, color: cs.error),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.error),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _analyze,
                  child: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MoistureSheetBody extends StatefulWidget {
  const _MoistureSheetBody({required this.soilImageAttached});

  final bool soilImageAttached;

  @override
  State<_MoistureSheetBody> createState() => _MoistureSheetBodyState();
}

class _MoistureSheetBodyState extends State<_MoistureSheetBody> {
  SoilMoistureLevel? _selected;
  final _probe = TextEditingController();
  final _temp = TextEditingController();
  final _rh = TextEditingController();
  var _sensorOpen = false;

  @override
  void dispose() {
    _probe.dispose();
    _temp.dispose();
    _rh.dispose();
    super.dispose();
  }

  Widget _pickTile({
    required bool selected,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(selected ? Icons.check_circle : Icons.circle_outlined),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle, style: Theme.of(context).textTheme.bodySmall) : null,
      onTap: onTap,
    );
  }

  void _run() {
    final sensor = OptionalSensorSnapshot(
      soilMoisturePercent: int.tryParse(_probe.text.trim()),
      temperatureC: int.tryParse(_temp.text.trim()),
      humidityPercent: int.tryParse(_rh.text.trim()),
    );
    Navigator.pop(
      context,
      _MoistureInputResult(fieldObservation: _selected, sensor: sensor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Field observation (optional)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              widget.soilImageAttached
                  ? 'You added a soil photo — the app fuses it with leaf cues. Add a finger/probe reading if you have one.'
                  : 'Finger or probe at root depth refines the estimate. Skip to use leaf + vision only.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 8),
            _pickTile(
              selected: _selected == null,
              title: 'Skip — estimate from images only',
              onTap: () => setState(() => _selected = null),
            ),
            for (final level in SoilMoistureLevel.values)
              _pickTile(
                selected: _selected == level,
                title: level.displayTitle,
                subtitle: level.shortHint,
                onTap: () => setState(() => _selected = level),
              ),
            ExpansionTile(
              title: const Text('Optional sensor / demo values'),
              subtitle: const Text('Probe %, °C, humidity — for testing or IoT'),
              initiallyExpanded: _sensorOpen,
              onExpansionChanged: (o) => setState(() => _sensorOpen = o),
              children: [
                TextField(
                  controller: _probe,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Soil moisture % (0–100)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _temp,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Air temperature °C',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _rh,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Relative humidity %',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _run,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Run analysis'),
            ),
          ],
        ),
      ),
    );
  }
}
