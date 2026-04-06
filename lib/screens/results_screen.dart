import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus;

import '../data/history_repository.dart';
import '../data/moisture_trend_store.dart';
import '../models/analysis_models.dart';
import '../services/agri_context_service.dart';
import '../services/crop_health_policy.dart';
import '../services/farmer_gamification.dart';
import '../services/report_tts_service.dart';
import '../services/voice_assistant.dart';
import '../services/weather_service.dart';
import '../theme/agri_theme.dart';
import 'achievements_screen.dart';
import 'analysis_dashboard_screen.dart';
import 'treatment_plan_screen.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({
    super.key,
    required this.report,
    this.persistToHistory = true,
  });

  final CropAnalysisReport report;
  final bool persistToHistory;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  var _savedHistory = false;
  var _loadingContext = true;
  WeatherSnapshot? _weather;
  double? _latitude;
  List<MoistureTrendPoint> _trend = [];

  @override
  void initState() {
    super.initState();
    if (widget.persistToHistory) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _saveHistory());
    }
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadContext());
    } else {
      _loadingContext = false;
    }
    // Record gamification progress
    WidgetsBinding.instance.addPostFrameCallback((_) => _recordGamification());
  }

  Future<void> _recordGamification() async {
    try {
      final update = await FarmerGamification.recordScan();
      if (!mounted) return;

      // Show level up or achievement notifications
      if (update.leveledUp) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.star, color: Colors.yellow),
                const SizedBox(width: 12),
                Text('🎉 Level Up! You are now Level ${update.newLevel}!'),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      if (update.unlockedAchievements.isNotEmpty) {
        for (final achievement in update.unlockedAchievements) {
          if (!mounted) break;
          await Future.delayed(const Duration(milliseconds: 500));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Text(achievement.icon, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🏆 Achievement Unlocked!',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          achievement.title,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      // Silently fail - gamification shouldn't block the app
      debugPrint('Gamification error: $e');
    }
  }

  Future<void> _saveHistory() async {
    if (_savedHistory || !widget.persistToHistory) return;
    _savedHistory = true;
    await HistoryRepository.saveReport(widget.report);
  }

  Future<void> _loadContext() async {
    final trend = await MoistureTrendStore.load();
    WeatherSnapshot? w;
    double? lat;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _trend = trend;
            _loadingContext = false;
          });
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      lat = pos.latitude;
      w = await WeatherService.fetchCurrent(latitude: pos.latitude, longitude: pos.longitude);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _trend = trend;
      _weather = w;
      _latitude = lat;
      _loadingContext = false;
    });
  }

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(
        text: widget.report.formattedReport,
        subject: 'Agri Lenz crop report',
      ),
    );
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.report.formattedReport));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report copied')));
  }

  Future<void> _speak() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice report is not available on web in this build.')),
      );
      return;
    }
    // Use enhanced voice assistant instead of basic TTS
    await VoiceAssistantService.speakAnalysis(widget.report);
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final cs = Theme.of(context).colorScheme;
    final hc = AgriTheme.healthColor(report.cropHealth);
    final pc = AgriTheme.pestColor(report.pestRisk);

    final sortedScores = report.disease.allScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topConf = sortedScores.isEmpty ? 0.0 : sortedScores.first.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI report'),
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
          IconButton(
            tooltip: 'View treatment plan',
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => TreatmentPlanScreen(report: report),
                ),
              );
            },
            icon: const Icon(Icons.assignment_turned_in_outlined),
          ),
          IconButton(
            tooltip: 'Interactive dashboard',
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => AnalysisDashboardScreen(report: report),
                ),
              );
            },
            icon: const Icon(Icons.dashboard_customize_outlined),
          ),
          if (!kIsWeb)
            IconButton(
              tooltip: 'Read report aloud',
              onPressed: _speak,
              icon: const Icon(Icons.record_voice_over_outlined),
            ),
          IconButton(
            tooltip: 'Share',
            onPressed: _share,
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            tooltip: 'Copy text',
            onPressed: _copy,
            icon: const Icon(Icons.copy_outlined),
          ),
          IconButton(
            tooltip: 'Full text',
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                builder: (ctx) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: SelectableText(report.formattedReport),
                ),
              );
            },
            icon: const Icon(Icons.description_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.memory(
                report.previewBytes,
                fit: BoxFit.cover,
              ),
            ),
          ),
          if (report.soilImagePreviewBytes != null && report.soilImagePreviewBytes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Soil photo used for moisture cues', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.memory(report.soilImagePreviewBytes!, fit: BoxFit.cover),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: Icon(
                  report.photoQuality.score >= 65 ? Icons.hd_outlined : Icons.warning_amber_outlined,
                  size: 18,
                  color: report.photoQuality.score >= 65 ? cs.primary : cs.tertiary,
                ),
                label: Text('Photo Q ${report.photoQuality.score}/100'),
              ),
              if (report.usedMultiScaleVision)
                Chip(
                  avatar: Icon(Icons.layers_outlined, size: 18, color: cs.secondary),
                  label: const Text('Multi-scale fusion'),
                ),
              if (report.uncertainty.isAmbiguous)
                Chip(
                  avatar: Icon(Icons.help_outline, size: 18, color: cs.error),
                  label: const Text('Uncertain — rescan'),
                ),
              if (report.soilMoisture != null)
                Chip(
                  avatar: Icon(Icons.agriculture_outlined, size: 18, color: cs.tertiary),
                  label: Text('Field: ${report.soilMoisture!.displayTitle}'),
                ),
            ],
          ),
          if (report.photoQuality.score < 65)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                report.photoQuality.hint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.tertiary),
              ),
            ),
          if (report.uncertainty.message.isNotEmpty && report.uncertainty.isAmbiguous)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Material(
                color: cs.errorContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: cs.error, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          report.uncertainty.message,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          _ConfidenceMeterCard(confidence: topConf, topLabel: sortedScores.isEmpty ? '' : sortedScores.first.key),
          if (!kIsWeb && _trend.length >= 2) ...[
            const SizedBox(height: 8),
            _MoistureTrendStrip(points: _trend),
          ],
          if (!kIsWeb) ...[
            const SizedBox(height: 8),
            _WeatherContextCard(
              loading: _loadingContext,
              weather: _weather,
              regionalLine: AgriContextService.regionalHint(latitude: _latitude),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              report.visionCorrectedTflite
                  ? 'Model + vision: injury cues adjusted the result'
                  : report.usedTfliteModel
                      ? 'TensorFlow Lite'
                      : 'Visual analysis (add matching .tflite for trained classes)',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Class scores',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...sortedScores.map((e) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(e.key, style: Theme.of(context).textTheme.labelLarge)),
                      Text('${(e.value * 100).toStringAsFixed(1)}%'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: e.value.clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: cs.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          _StatusCard(
            title: 'Crop health',
            value: report.healthLabel,
            subtitle: CropHealthPolicy.explain(report.visualFeatures, report.cropHealth),
            color: hc,
            icon: Icons.spa_rounded,
          ),
          _StatusCard(
            title: 'Disease signal',
            value: report.disease.label,
            subtitle:
                'Top probability ${(report.disease.confidence * 100).clamp(0, 100).toStringAsFixed(0)}% '
                '(below 70% is shown as uncertain in the model pipeline)',
            color: cs.primary,
            icon: Icons.bug_report_outlined,
          ),
          _StatusCard(
            title: 'Pest risk',
            value: report.pestRiskLabel,
            subtitle: 'Injury pixels + disease context — healthy-looking leaves stay low unless damage is visible',
            color: pc,
            icon: Icons.pest_control_rounded,
          ),
          _InfoCard(
            title: 'Soil / nutrient cues (from leaf view)',
            body: report.soilInsight,
            icon: Icons.landscape_outlined,
          ),
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              leading: Icon(Icons.water_drop_outlined, color: cs.primary, size: 28),
              title: Text(
                report.soilMoistureSummary,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${report.soilMoistureBand.emoji} Fused estimate — tap for details',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    report.soilMoistureDetail,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Recommendations',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...report.recommendations.map(
            (r) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(Icons.check_circle_outline_rounded, color: cs.primary),
                title: Text(r),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceMeterCard extends StatelessWidget {
  const _ConfidenceMeterCard({required this.confidence, required this.topLabel});

  final double confidence;
  final String topLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = confidence.clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed_outlined, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  'Confidence meter',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              topLabel.isEmpty
                  ? 'No class scores.'
                  : 'Strongest class: $topLabel — values under 70% are treated cautiously by the app.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.35),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: c,
                minHeight: 14,
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(c * 100).toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoistureTrendStrip extends StatelessWidget {
  const _MoistureTrendStrip({required this.points});

  final List<MoistureTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final recent = points.length > 10 ? points.sublist(points.length - 10) : points;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart, color: cs.secondary),
                const SizedBox(width: 8),
                Text(
                  'Moisture band trend (recent scans)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final p in recent)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _TrendBar(
                        bandIndex: p.bandIndex.clamp(0, 2),
                        colorScheme: cs,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '🔴 low · 🟡 moderate · 🟢 high — local estimate only',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({required this.bandIndex, required this.colorScheme});

  final int bandIndex;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final h = 0.35 + bandIndex * 0.22;
    final color = switch (bandIndex) {
      0 => colorScheme.error,
      1 => colorScheme.tertiary,
      _ => colorScheme.primary,
    };
    return SizedBox(
      height: 72,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 72 * h,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}

class _WeatherContextCard extends StatelessWidget {
  const _WeatherContextCard({
    required this.loading,
    required this.weather,
    required this.regionalLine,
  });

  final bool loading;
  final WeatherSnapshot? weather;
  final String regionalLine;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wb_cloudy_outlined, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  'Weather & region',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (loading)
              const LinearProgressIndicator(minHeight: 3)
            else if (weather != null)
              Text(
                '${weather!.summaryLabel} · ${weather!.temperatureC.toStringAsFixed(0)}°C · '
                '${weather!.humidityPercent}% RH',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.35),
              )
            else
              Text(
                'Weather unavailable — enable location or check network.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.tertiary),
              ),
            const SizedBox(height: 8),
            Text(
              regionalLine,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: cs.primary, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(body, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
