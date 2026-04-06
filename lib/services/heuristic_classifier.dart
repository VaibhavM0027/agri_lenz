import 'dart:math' as math;

import '../models/analysis_models.dart';
import 'vision_robust.dart';

class HeuristicClassifier {
  static DiseasePrediction predict(List<String> labels, LeafVisualFeatures f) {
    final raw = <String, double>{for (final l in labels) l: 0.01};

    final lush = VisionRobustness.isHealthyLookingCanopy(f);
    
    // HEALTHY LEAF DETECTION - Very strict thresholds
    // If leaf looks predominantly green with minimal damage signals, mark as healthy
    final isClearlyHealthy = f.greenRatio > 0.35 && 
                             f.pestInjuryScore < 0.08 &&
                             f.textureDamageScore < 0.15 &&
                             f.darkSpotRatio < 0.06 &&
                             f.yellowRatio < 0.10 &&
                             f.brownRatio < 0.08 &&
                             f.rustLikeRatio < 0.04;
    
    if (isClearlyHealthy) {
      // Strong healthy signal - minimal disease probability
      if (labels.isNotEmpty) {
        final healthy = labels[0];
        raw[healthy] = 0.92; // 92% confidence in healthy
        // Distribute remaining 8% equally among diseases
        final remaining = 0.08 / (labels.length - 1 > 0 ? labels.length - 1 : 1);
        for (var i = 1; i < labels.length; i++) {
          raw[labels[i]] = remaining;
        }
      }
      
      final probs = _softmaxMap(raw);
      final top = probs.entries.reduce((a, b) => a.value >= b.value ? a : b);
      return DiseasePrediction(label: top.key, confidence: top.value, allScores: probs);
    }

    // Only assign disease scores if there are CLEAR visual indicators
    final pestWeight = lush ? 1.15 : 1.75; // Reduced weights
    final texturePen = lush ? 0.65 : 1.05; // Reduced penalty

    if (labels.isNotEmpty) {
      final healthy = labels[0];
      var hScore = f.greenRatio * 1.15 +
          (1 - f.brownRatio) * 0.15 -
          f.pestInjuryScore * pestWeight -
          f.textureDamageScore * texturePen -
          f.darkSpotRatio * (lush ? 0.45 : 0.68) -
          f.yellowRatio * 0.32;
      if (lush) hScore += 0.55;
      raw[healthy] = math.max(0.15, hScore); // Higher minimum for healthy
    }

    void bump(String name, double w) {
      if (raw.containsKey(name)) raw[name] = raw[name]! + w;
    }

    final pestBumpScale = lush ? 0.32 : 0.75; // Much lower scale

    // VERY CONSERVATIVE disease scoring - only bump if strong evidence
    bump(
      'Leaf Blight',
      f.brownRatio > 0.12 ? (f.brownRatio * 0.65 + f.yellowRatio * 0.38 + f.borderBrownBias * 0.45) : 0.02,
    );
    bump(
      'Powdery Mildew',
      f.paleRatio > 0.18 ? (f.paleRatio * 0.7 + (1 - f.greenRatio) * 0.18) : 0.02,
    );
    bump('Rust', f.rustLikeRatio > 0.06 ? (f.rustLikeRatio * 0.95) : 0.02);
    bump(
      'Leaf Spot',
      f.darkSpotRatio > 0.08 ? (f.darkSpotRatio * 0.75 + f.textureDamageScore * 0.35) : 0.02,
    );

    bump(
      'Pest Damage',
      f.pestInjuryScore > 0.12 ? ((f.pestInjuryScore * 1.45 + f.textureDamageScore * 0.35) * pestBumpScale) : 0.02,
    );

    final probs = _softmaxMap(raw);
    final top = probs.entries.reduce((a, b) => a.value >= b.value ? a : b);

    // STRONG healthy bias - if canopy looks healthy and top prediction is weak, default to healthy
    if (labels.isNotEmpty && lush && top.value < 0.45 && f.pestInjuryScore < 0.12 && probs.containsKey(labels[0])) {
      final h = labels[0];
      final adj = Map<String, double>.from(probs);
      adj[h] = (adj[h]! + 0.35).clamp(0.0, 1.0);
      // Reduce all disease scores proportionally
      for (final key in adj.keys.where((k) => k != h)) {
        adj[key] = (adj[key]! * 0.45).clamp(0.0, 1.0);
      }
      final renorm = _softmaxMap({for (final e in adj.entries) e.key: e.value});
      final t2 = renorm.entries.reduce((a, b) => a.value >= b.value ? a : b);
      return DiseasePrediction(label: t2.key, confidence: t2.value, allScores: renorm);
    }

    return DiseasePrediction(label: top.key, confidence: top.value, allScores: probs);
  }

  static double dChewLike(LeafVisualFeatures f) =>
      (f.pestInjuryScore * 0.35 + f.textureDamageScore * 0.25).clamp(0.0, 1.0);

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
