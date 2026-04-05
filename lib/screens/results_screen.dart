import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus;

import '../data/history_repository.dart';
import '../models/analysis_models.dart';
import '../theme/agri_theme.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.persistToHistory) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _saveHistory());
    }
  }

  Future<void> _saveHistory() async {
    if (_savedHistory || !widget.persistToHistory) return;
    _savedHistory = true;
    await HistoryRepository.saveReport(widget.report);
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

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final cs = Theme.of(context).colorScheme;
    final hc = AgriTheme.healthColor(report.cropHealth);
    final pc = AgriTheme.pestColor(report.pestRisk);

    final sortedScores = report.disease.allScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI report'),
        actions: [
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
            subtitle: switch (report.cropHealth) {
              CropHealthLevel.healthy => 'High confidence healthy canopy pattern',
              CropHealthLevel.moderate => 'Mild stress or early disease pattern',
              CropHealthLevel.critical => 'Severe stress or strong disease signal',
            },
            color: hc,
            icon: Icons.spa_rounded,
          ),
          _StatusCard(
            title: 'Disease signal',
            value: report.disease.label,
            subtitle:
                'Confidence ${(report.disease.confidence * 100).clamp(0, 100).toStringAsFixed(0)}%',
            color: cs.primary,
            icon: Icons.bug_report_outlined,
          ),
          _StatusCard(
            title: 'Pest risk',
            value: report.pestRiskLabel,
            subtitle: 'Hybrid rules: disease load + visible leaf damage',
            color: pc,
            icon: Icons.pest_control_rounded,
          ),
          _InfoCard(
            title: 'Soil-related insight',
            body: report.soilInsight,
            icon: Icons.landscape_outlined,
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
