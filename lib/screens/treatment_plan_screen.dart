import 'package:flutter/material.dart';

import '../models/analysis_models.dart';
import '../services/treatment_plan_generator.dart';
import '../theme/agri_theme.dart';

class TreatmentPlanScreen extends StatelessWidget {
  const TreatmentPlanScreen({
    super.key,
    required this.report,
  });

  final CropAnalysisReport report;

  @override
  Widget build(BuildContext context) {
    final plan = TreatmentPlanGenerator.generate(
      disease: report.disease,
      health: report.cropHealth,
      pest: report.pestRisk,
      visual: report.visualFeatures,
    );

    final cs = Theme.of(context).colorScheme;
    final severityColor = AgriTheme.healthColor(report.cropHealth);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Treatment Plan'),
        actions: [
          IconButton(
            tooltip: 'Share plan',
            onPressed: () {
              // TODO: Implement share functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share feature coming soon!')),
              );
            },
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Card
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: severityColor.withValues(alpha: 0.15),
                        child: Icon(
                          Icons.medical_services_rounded,
                          color: severityColor,
                          size: 36,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan.disease,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              plan.severityLabel,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: severityColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      _StatCard(
                        icon: Icons.calendar_today,
                        label: 'Recovery',
                        value: '${plan.estimatedRecoveryDays}d',
                        color: cs.primary,
                      ),
                      _StatCard(
                        icon: Icons.trending_up,
                        label: 'Success',
                        value: '${plan.successRate.toStringAsFixed(0)}%',
                        color: Colors.green,
                      ),
                      _StatCard(
                        icon: Icons.task_alt,
                        label: 'Tasks',
                        value: plan.phases.fold<int>(
                          0,
                          (sum, phase) => sum + phase.tasks.length,
                        ).toString(),
                        color: cs.secondary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Timeline
          Text(
            'Action Timeline',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          ...plan.phases.asMap().entries.map((entry) {
            final index = entry.key;
            final phase = entry.value;
            final isLast = index == plan.phases.length - 1;

            return _TimelinePhase(
              phase: phase,
              isFirst: index == 0,
              isLast: isLast,
            );
          }),

          const SizedBox(height: 24),

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
                      Icon(Icons.lightbulb_outline, color: cs.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Pro Tips for Best Results',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _TipItem(text: 'Always follow product label instructions and safety guidelines'),
                  const _TipItem(text: 'Keep records of all treatments applied and dates'),
                  const _TipItem(text: 'Monitor weather — avoid spraying before heavy rain'),
                  const _TipItem(text: 'Rotate chemical classes to prevent resistance'),
                  const _TipItem(text: 'Consult local extension officer for region-specific advice'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Emergency Contact
          Card(
            color: cs.errorContainer.withValues(alpha: 0.2),
            child: ListTile(
              leading: Icon(Icons.emergency, color: cs.error),
              title: Text(
                'Need Help?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.error,
                    ),
              ),
              subtitle: Text(
                'Contact your local agricultural extension office if symptoms worsen or spread rapidly',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _TimelinePhase extends StatefulWidget {
  const _TimelinePhase({
    required this.phase,
    required this.isFirst,
    required this.isLast,
  });

  final TreatmentPhase phase;
  final bool isFirst;
  final bool isLast;

  @override
  State<_TimelinePhase> createState() => _TimelinePhaseState();
}

class _TimelinePhaseState extends State<_TimelinePhase> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line
          Column(
            children: [
              if (!widget.isFirst)
                Container(
                  width: 2,
                  height: 20,
                  color: cs.outline.withValues(alpha: 0.3),
                ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.primary, width: 2),
                ),
                child: Center(
                  child: Text(
                    widget.phase.icon,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  color: widget.isLast
                      ? Colors.transparent
                      : cs.outline.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                initiallyExpanded: _expanded,
                onExpansionChanged: (expanded) {
                  setState(() => _expanded = expanded);
                },
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.phase.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.phase.timeframe,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                subtitle: Text(
                  '${widget.phase.tasks.length} task${widget.phase.tasks.length != 1 ? 's' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      children: widget.phase.tasks.map((task) {
                        return _TaskTile(task: task);
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task});

  final TreatmentTask task;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.priorityEmoji,
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  task.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.7),
                        height: 1.4,
                      ),
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
                const SizedBox(height: 4),
                Text(
                  'Day ${task.dayOffset}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TipItem extends StatelessWidget {
  const _TipItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
