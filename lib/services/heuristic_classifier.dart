import 'dart:math' as math;

import '../models/analysis_models.dart';

class HeuristicClassifier {
  static DiseasePrediction predict(List<String> labels, LeafVisualFeatures f) {
    final raw = <String, double>{for (final l in labels) l: 0.02};

    if (labels.isNotEmpty) {
      final healthy = labels[0];
      // Healthy needs calm texture + low injury — green alone is not enough.
      raw[healthy] = math.max(
        0.03,
        f.greenRatio * 0.72 +
            (1 - f.brownRatio) * 0.08 -
            f.pestInjuryScore * 2.85 -
            f.textureDamageScore * 1.45 -
            f.darkSpotRatio * 0.95 -
            f.yellowRatio * 0.42,
      );
    }

    void bump(String name, double w) {
      if (raw.containsKey(name)) raw[name] = raw[name]! + w;
    }

    bump(
      'Leaf Blight',
      f.brownRatio * 0.82 + f.yellowRatio * 0.48 + f.borderBrownBias * 0.58 + f.darkSpotRatio * 0.28,
    );
    bump(
      'Powdery Mildew',
      f.paleRatio * 0.9 + (1 - f.greenRatio) * 0.22 + f.textureDamageScore * 0.18,
    );
    bump('Rust', f.rustLikeRatio * 1.1 + f.darkSpotRatio * 0.2);
    bump(
      'Leaf Spot',
      f.darkSpotRatio * 0.95 +
          f.textureDamageScore * 0.55 +
          (1 - f.greenRatio) * 0.12 +
          f.pestInjuryScore * 0.65,
    );

    bump(
      'Pest Damage',
      f.pestInjuryScore * 2.65 + f.textureDamageScore * 0.95 + f.darkSpotRatio * 0.45 + dChewLike(f) * 0.4,
    );

    final probs = _softmaxMap(raw);
    final top = probs.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return DiseasePrediction(label: top.key, confidence: top.value, allScores: probs);
  }

  /// Extra chew / perforation emphasis when "Pest Damage" label missing (older label files).
  static double dChewLike(LeafVisualFeatures f) => (f.pestInjuryScore * 0.35 + f.textureDamageScore * 0.25).clamp(0.0, 1.0);

  static Map<String, double> _softmaxMap(Map<String, double> raw) {
    final vals = raw.values.toList();
    final m = vals.reduce(math.max);
    var sum = 0.0;
    final exps = <double>[];
    for (final v in vals) {
      final e = math.exp((v - m).clamp(-20.0, 20.0));
      exps.add(e);
      sum += e;
    }
    final keys = raw.keys.toList();
    final out = <String, double>{};
    for (var i = 0; i < keys.length; i++) {
      out[keys[i]] = (exps[i] / sum).clamp(0.0, 1.0);
    }
    return out;
  }
}
