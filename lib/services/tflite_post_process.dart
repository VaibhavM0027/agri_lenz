import '../models/analysis_models.dart';
import 'crop_health_policy.dart';

/// Post-processing on top of CNN logits/probabilities: **confidence gating** and **health tier** mapping.
abstract final class TflitePostProcess {
  // Higher threshold to reduce false disease detection
  static const double tfliteConfidenceThreshold = 0.78; // Was 0.70

  static const String uncertainLabel = 'Uncertain / Likely Healthy';

  static DiseasePrediction applyConfidenceGate(DiseasePrediction raw) {
    if (raw.confidence >= tfliteConfidenceThreshold) return raw;
    return DiseasePrediction(
      label: uncertainLabel,
      confidence: raw.confidence,
      allScores: Map<String, double>.from(raw.allScores),
    );
  }

  static CropHealthLevel mapToRiskTier(LeafVisualFeatures visual) {
    return CropHealthPolicy.resolve(visual);
  }
}
