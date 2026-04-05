import 'package:flutter/material.dart';

import '../models/analysis_models.dart';
import '../theme/agri_theme.dart';

class ComparisonScreen extends StatelessWidget {
  const ComparisonScreen({super.key, required this.left, required this.right});

  final CropAnalysisReport left;
  final CropAnalysisReport right;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Side-by-side')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _ThumbCard(title: 'A', report: left)),
              const SizedBox(width: 8),
              Expanded(child: _ThumbCard(title: 'B', report: right)),
            ],
          ),
          const SizedBox(height: 16),
          _DiffRow(
            label: 'Health',
            a: left.healthLabel,
            b: right.healthLabel,
            colorA: AgriTheme.healthColor(left.cropHealth),
            colorB: AgriTheme.healthColor(right.cropHealth),
          ),
          _DiffRow(
            label: 'Diagnosis',
            a: left.disease.label,
            b: right.disease.label,
          ),
          _DiffRow(
            label: 'Confidence',
            a: '${(left.disease.confidence * 100).toStringAsFixed(0)}%',
            b: '${(right.disease.confidence * 100).toStringAsFixed(0)}%',
          ),
          _DiffRow(
            label: 'Pest risk',
            a: left.pestRiskLabel,
            b: right.pestRiskLabel,
            colorA: AgriTheme.pestColor(left.pestRisk),
            colorB: AgriTheme.pestColor(right.pestRisk),
          ),
          _DiffRow(
            label: 'Photo Q',
            a: '${left.photoQuality.score}',
            b: '${right.photoQuality.score}',
          ),
          const SizedBox(height: 12),
          Text('Interpretation', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            _interpretation(left, right),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }

  static String _interpretation(CropAnalysisReport a, CropAnalysisReport b) {
    if (a.disease.label == b.disease.label && a.cropHealth == b.cropHealth) {
      return 'Both scans agree on health tier and primary label — pattern is consistent across samples.';
    }
    if (a.photoQuality.score < 55 || b.photoQuality.score < 55) {
      return 'At least one photo has low quality score — prefer retakes before drawing strong conclusions.';
    }
    if (a.cropHealth.index > b.cropHealth.index) {
      return 'Leaf A looks worse than B in this analysis — prioritize scouting where symptoms match A.';
    }
    if (b.cropHealth.index > a.cropHealth.index) {
      return 'Leaf B shows stronger stress signals — use it to target treatment and monitoring.';
    }
    return 'Mixed signals — scan additional leaves and use History to track whether damage spreads.';
  }
}

class _ThumbCard extends StatelessWidget {
  const _ThumbCard({required this.title, required this.report});

  final String title;
  final CropAnalysisReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Leaf $title', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 1,
            child: Image.memory(report.previewBytes, fit: BoxFit.cover),
          ),
        ),
      ],
    );
  }
}

class _DiffRow extends StatelessWidget {
  const _DiffRow({
    required this.label,
    required this.a,
    required this.b,
    this.colorA,
    this.colorB,
  });

  final String label;
  final String a;
  final String b;
  final Color? colorA;
  final Color? colorB;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(
            child: Text(
              a,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colorA ?? Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Expanded(
            child: Text(
              b,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colorB ?? Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
