import 'package:flutter/material.dart';

/// Curated, offline-first tips that differentiate the app from a bare classifier.
class FieldGuideScreen extends StatelessWidget {
  const FieldGuideScreen({super.key});

  static final _sections = <_GuideSection>[
    _GuideSection(
      title: 'Photo checklist (boosts accuracy)',
      icon: Icons.photo_camera_outlined,
      bullets: [
        'Fill most of the frame with a single leaf — avoid tiny leaves in the distance.',
        'Use soft daylight or shade; harsh noon sun burns out spots and chew marks.',
        'Tap to focus; hold steady — blur is the #1 cause of “healthy” false reads.',
        'Capture both sides if you see damage on the underside (mites, aphids).',
        'Lush green leaves use stricter rules: veins and shadows are no longer treated as pest injury by default.',
      ],
    ),
    _GuideSection(
      title: 'How Agri Lenz decides',
      icon: Icons.psychology_outlined,
      bullets: [
        'TensorFlow Lite (MobileNetV2 / EfficientNet-style) expects RGB input, letterboxed to the model’s H×W (typically 224×224), pixels normalized to [0, 1] for float32 graphs.',
        'Output index i must match line i in labels.txt — see CnnLabelMap in source when training.',
        'If the top CNN probability is under 70%, the app shows “Uncertain / Likely Healthy” to limit false positives.',
        'Crop health tier is **vision-first**: mostly green + no hole/chew pattern → Healthy; strong yellow/brown/rust or holes → Critical/Moderate — the CNN label is still shown for disease naming.',
        'Multi-scale vision fuses four passes (multiple zooms + lighting-normalized image) and dampens pest/texture scores when scales disagree.',
        'Soil moisture is a **fused estimate**: leaf stress cues + optional soil surface photo + optional field reading + optional sensor/demo fields — not a lab test.',
        'Open-Meteo weather and coarse latitude hints are optional (location permission); core diagnosis still works offline.',
        'Pest injury uses holes, speckles, and chew-like edges — not leaf color alone.',
        'If the model says “Healthy” (or uncertain) but vision sees injury, the app can override the label.',
      ],
    ),
    _GuideSection(
      title: 'IPM workflow',
      icon: Icons.agriculture_outlined,
      bullets: [
        'Identify → confirm with a second leaf → treat labeled products only for your crop.',
        'Rotate insecticide / fungicide modes of action to delay resistance.',
        'Record dates in History — compare scans after treatment to see if damage stops spreading.',
      ],
    ),
    _GuideSection(
      title: 'When to escalate',
      icon: Icons.support_agent_outlined,
      bullets: [
        'If photo quality score stays low, fix lighting before trusting any diagnosis.',
        'If uncertainty says “close call,” scan more leaves or send samples to a local lab.',
        'Quarantine new nursery stock if rust or blight-like patterns appear cluster-wide.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Field guide')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sections.length,
        itemBuilder: (context, i) {
          final s = _sections[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(s.icon, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...s.bullets.map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• ', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                          Expanded(child: Text(b, style: Theme.of(context).textTheme.bodyMedium)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GuideSection {
  const _GuideSection({
    required this.title,
    required this.icon,
    required this.bullets,
  });

  final String title;
  final IconData icon;
  final List<String> bullets;
}
