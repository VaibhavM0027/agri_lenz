import '../models/analysis_models.dart';
import 'tflite_post_process.dart';
import 'vision_robust.dart';

/// Vision merge with **healthy-canopy guard** to avoid false pest/critical on lush leaves.
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
    final lush = VisionRobustness.isHealthyLookingCanopy(visual);

    if (!_actsLikeHealthy(tflite.label)) {
      // EXTREMELY conservative: only override TFLite with very strong visual evidence
      final trustHeuristicForPest = pest >= 0.265 &&  // Was 0.215
          heuristic.label == 'Pest Damage' &&
          heuristic.confidence >= tflite.confidence * 0.78 &&  // Was 0.68
          (!lush || pest >= 0.23);  // Was 0.18
      if (trustHeuristicForPest) {
        return MergeResult(prediction: heuristic, usedRawTflite: false);
      }
      return MergeResult(prediction: tflite, usedRawTflite: true);
    }
    
    // TFLite: healthy / uncertain — EXTREMELY strict "stress" bar on lush canopies (veins ≠ pests).
    final visuallyStressed = lush
        ? (pest >= 0.225 && (tex >= 0.42 || visual.darkSpotRatio >= 0.138))  // Was 0.175, 0.36, 0.108
        : (pest >= 0.152 || tex >= 0.305 || visual.darkSpotRatio >= 0.112);  // Was 0.112, 0.245, 0.082

    if (!visuallyStressed) {
      return MergeResult(prediction: tflite, usedRawTflite: true);
    }

    if (lush) {
      // EXTREMELY strict for lush canopies - avoid false disease detection
      if (heuristic.label != 'Healthy' &&
          heuristic.label != 'Pest Damage' &&
          pest >= 0.198 &&  // Was 0.148
          (tex >= 0.36 || visual.darkSpotRatio >= 0.118)) {  // Was 0.30, 0.088
        return MergeResult(prediction: heuristic, usedRawTflite: false);
      }
      if (heuristic.label == 'Pest Damage' && pest >= 0.238 && tex >= 0.36) {  // Was 0.188, 0.30
        return MergeResult(prediction: heuristic, usedRawTflite: false);
      }
      if (pest >= 0.275 && (tex >= 0.40 || visual.darkSpotRatio >= 0.132)) {  // Was 0.225, 0.34, 0.102
        return MergeResult(
          prediction: _syntheticInjury(labels, visual),
          usedRawTflite: false,
        );
      }
      return MergeResult(prediction: tflite, usedRawTflite: true);
    }

    if (heuristic.label != 'Healthy' && (pest >= 0.132 || tex >= 0.285)) {  // Was 0.092, 0.225
      return MergeResult(prediction: heuristic, usedRawTflite: false);
    }

    if (pest >= 0.195 || (pest >= 0.168 && tex >= 0.325)) {  // Was 0.155, 0.128, 0.265
      return MergeResult(
        prediction: _syntheticInjury(labels, visual),
        usedRawTflite: false,
      );
    }

    if (pest >= 0.165 &&  // Was 0.125
        (tex >= 0.295 || visual.darkSpotRatio >= 0.112) &&  // Was 0.235, 0.082
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
    final conf = (0.42 + v.pestInjuryScore * 0.32 + v.textureDamageScore * 0.12).clamp(0.42, 0.88);
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
