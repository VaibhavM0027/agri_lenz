import 'dart:math' show max;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../data/history_repository.dart';
import '../data/history_entry.dart';
import '../models/analysis_models.dart';
import '../services/crop_health_policy.dart';
import '../theme/agri_theme.dart';

/// Interactive drill-down: health policy, vision bars (touchable), model scores, history mix.
class AnalysisDashboardScreen extends StatefulWidget {
  const AnalysisDashboardScreen({super.key, required this.report});

  final CropAnalysisReport report;

  @override
  State<AnalysisDashboardScreen> createState() => _AnalysisDashboardScreenState();
}

class _AnalysisDashboardScreenState extends State<AnalysisDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  int? _touchedVisionIndex;
  int? _selectedScoreIndex;
  Future<_HistoryMix>? _historyMix;

  static const _visionKeys = [
    'Green',
    'Yellow',
    'Brown',
    'Rust-like',
    'Pale',
    'Dark spots',
    'Pest injury',
    'Texture dmg',
  ];

  @override
  void initState() {
    super.initState();
    _historyMix = _loadHistoryMix();
  }

  Future<_HistoryMix> _loadHistoryMix() async {
    final list = await HistoryRepository.loadEntries();
    return _HistoryMix.fromEntries(list);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final v = report.visualFeatures;
    final hc = AgriTheme.healthColor(report.cropHealth);
    final visionValues = [
      v.greenRatio,
      v.yellowRatio,
      v.brownRatio,
      v.rustLikeRatio,
      v.paleRatio,
      v.darkSpotRatio,
      v.pestInjuryScore,
      v.textureDamageScore,
    ];

    final sortedScores = report.disease.allScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis dashboard'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.health_and_safety_outlined)),
            Tab(text: 'Leaf vision', icon: Icon(Icons.blur_on_outlined)),
            Tab(text: 'Model & history', icon: Icon(Icons.stacked_bar_chart)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: hc.withValues(alpha: 0.2),
                            child: Icon(Icons.eco_rounded, color: hc, size: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Crop health: ${report.healthLabel}',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: hc,
                                      ),
                                ),
                                Text(
                                  'Disease label: ${report.disease.label}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 28),
                      Text(
                        'How this tier is chosen',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        CropHealthPolicy.explain(v, report.cropHealth),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            avatar: Icon(
                              CropHealthPolicy.hasNonGreenOrSpotStress(v) ? Icons.warning_amber : Icons.check,
                              size: 18,
                            ),
                            label: Text(
                              CropHealthPolicy.hasNonGreenOrSpotStress(v)
                                  ? 'Non-green / spot stress'
                                  : 'No strong lesion colors',
                            ),
                          ),
                          Chip(
                            avatar: Icon(
                              CropHealthPolicy.hasHoleOrChewSignal(v) ? Icons.pest_control : Icons.check,
                              size: 18,
                            ),
                            label: Text(
                              CropHealthPolicy.hasHoleOrChewSignal(v)
                                  ? 'Hole / chew signal'
                                  : 'No strong hole pattern',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.water_drop_outlined),
                  title: Text(report.soilMoistureSummary),
                  subtitle: Text('${report.soilMoistureBand.emoji} ${report.pestRiskLabel} pest risk'),
                  isThreeLine: true,
                ),
              ),
            ],
          ),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text(
                'Tap a bar for the metric. Values are 0–1 from multi-scale leaf vision.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: max(300.0, _visionKeys.length * 28.0),
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 1.0,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchCallback: (event, response) {
                        if (!event.isInterestedForInteractions) return;
                        setState(() {
                          _touchedVisionIndex = response?.spot?.touchedBarGroupIndex;
                        });
                      },
                    ),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= _visionKeys.length) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _visionKeys[i],
                                style: const TextStyle(fontSize: 9),
                                textAlign: TextAlign.center,
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          getTitlesWidget: (value, _) => Text('${(value * 100).round()}'),
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 0.25,
                    ),
                    barGroups: [
                      for (var i = 0; i < visionValues.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: visionValues[i].clamp(0.0, 1.0),
                              width: 14,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              color: _visionBarColor(i, Theme.of(context).colorScheme),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              if (_touchedVisionIndex != null &&
                  _touchedVisionIndex! >= 0 &&
                  _touchedVisionIndex! < _visionKeys.length)
                Card(
                  margin: const EdgeInsets.only(top: 12),
                  child: ListTile(
                    title: Text(_visionKeys[_touchedVisionIndex!]),
                    subtitle: Text(
                      '${(visionValues[_touchedVisionIndex!] * 100).toStringAsFixed(1)}% of sampled pixels / composite',
                    ),
                  ),
                ),
            ],
          ),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text(
                'Model class probabilities — tap a row to highlight',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...List.generate(sortedScores.length, (i) {
                final e = sortedScores[i];
                final sel = _selectedScoreIndex == i;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: sel
                        ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.55)
                        : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _selectedScoreIndex = i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(e.key, style: Theme.of(context).textTheme.titleSmall)),
                                Text(
                                  '${(e.value * 100).toStringAsFixed(1)}%',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: e.value.clamp(0.0, 1.0),
                                minHeight: 10,
                                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),
              Text(
                'Recent scans (history)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              FutureBuilder<_HistoryMix>(
                future: _historyMix,
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final m = snap.data!;
                  if (m.total == 0) {
                    return const Text('No saved history yet — complete a scan to build trends.');
                  }
                  return Column(
                    children: [
                      _mixRow(context, 'Healthy tier', m.healthy, m.total, Colors.green),
                      _mixRow(context, 'Moderate', m.moderate, m.total, Colors.orange),
                      _mixRow(context, 'Critical', m.critical, m.total, Colors.red),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _visionBarColor(int i, ColorScheme cs) {
    return switch (i) {
      0 => Colors.green.shade600,
      1 => Colors.amber.shade700,
      2 => Colors.brown.shade600,
      3 => Colors.deepOrange.shade600,
      4 => Colors.blueGrey.shade400,
      5 => Colors.grey.shade800,
      6 => Colors.purple.shade600,
      _ => cs.primary,
    };
  }

  Widget _mixRow(BuildContext context, String label, int count, int total, Color c) {
    final pct = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text('${(pct * 100).round()}% ($count)'),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
            color: c,
            backgroundColor: c.withValues(alpha: 0.15),
          ),
        ],
      ),
    );
  }
}

class _HistoryMix {
  _HistoryMix({required this.healthy, required this.moderate, required this.critical, required this.total});

  final int healthy;
  final int moderate;
  final int critical;
  final int total;

  static _HistoryMix fromEntries(List<HistoryEntry> entries) {
    var h = 0, m = 0, c = 0;
    for (final e in entries) {
      switch (e.cropHealthIndex) {
        case 0:
          h++;
          break;
        case 1:
          m++;
          break;
        case 2:
          c++;
          break;
        default:
          m++;
      }
    }
    final t = entries.length;
    return _HistoryMix(healthy: h, moderate: m, critical: c, total: t);
  }
}
