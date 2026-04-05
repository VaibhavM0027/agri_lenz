import '../models/analysis_models.dart';
import 'tflite_post_process.dart';

/// When a TFLite model labels a leaf [Healthy] (or uncertain / likely healthy) but low-level vision
/// shows holes, speckles, or chew margins, prefer heuristics or a synthetic pest-injury class.
class PredictionMerge {
  const PredictionMerge._();

  static bool _actsLikeHealthy(String label) =>
      label == 'Healthy' || label == TflitePostProcess.uncertainLabel;

  static MergeResult mergeTfliteWithVision({
    required DiseasePrediction tflite,
    required DiseasePrediction heuristic,
    required LeafVisualFeatures visual,
    required List<String> labels,
  }) {
    final pest = visual.pestInjuryScore;
    final tex = visual.textureDamageScore;

    if (!_actsLikeHealthy(tflite.label)) {
      final trustHeuristicForPest = pest >= 0.15 &&
          heuristic.label == 'Pest Damage' &&
          heuristic.confidence >= tflite.confidence * 0.5;
      if (trustHeuristicForPest) {
        return MergeResult(prediction: heuristic, usedRawTflite: false);
      }
      return MergeResult(prediction: tflite, usedRawTflite: true);
    }

    // TFLite says healthy or uncertain — gate on injury cues.
    final visuallyStressed = pest >= 0.055 || tex >= 0.165 || visual.darkSpotRatio >= 0.06;

    if (!visuallyStressed) {
      return MergeResult(prediction: tflite, usedRawTflite: true);
    }

    if (heuristic.label != 'Healthy' && (pest >= 0.045 || tex >= 0.14)) {
      return MergeResult(prediction: heuristic, usedRawTflite: false);
    }

    if (pest >= 0.09 || (pest >= 0.065 && tex >= 0.175)) {
      return MergeResult(
        prediction: _syntheticInjury(labels, visual),
        usedRawTflite: false,
      );
    }

    // Heuristic can miss rare cases; still force injury when cues are clear.
    if (pest >= 0.068 &&
        (tex >= 0.152 || visual.darkSpotRatio >= 0.05) &&
        heuristic.label == 'Healthy') {
      return MergeResult(
        prediction: _syntheticInjury(labels, visual),
        usedRawTflite: false,
      );
    }

    return MergeResult(prediction: tflite, usedRawTflite: true);
  }

  static DiseasePrediction _syntheticInjury(List<String> labels, LeafVisualFeatures v) {
    final label = labels.contains('Pest Damage') ? 'Pest Damage' : 'Leaf Spot';
    final conf = (0.52 + v.pestInjuryScore * 0.38 + v.textureDamageScore * 0.14).clamp(0.5, 0.94);
    final rest = labels.where((l) => l != label).toList();
    final per = rest.isEmpty ? 0.0 : (1.0 - conf) / rest.length;
    final map = <String, double>{for (final l in labels) l: per};
    map[label] = conf;
    return DiseasePrediction(label: label, confidence: conf, allScores: map);
  }
}

class MergeResult {
  MergeResult({required this.prediction, required this.usedRawTflite});

  final DiseasePrediction prediction;
  final bool usedRawTflite;
}
