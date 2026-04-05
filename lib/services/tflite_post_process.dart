import '../models/analysis_models.dart';

/// Post-processing on top of CNN logits/probabilities: **confidence gating** and **health tier** mapping.
abstract final class TflitePostProcess {
  /// Require ≥70% on the winning class to accept the CNN diagnosis; otherwise reduce false positives.
  static const double tfliteConfidenceThreshold = 0.70;

  static const String uncertainLabel = 'Uncertain / Likely Healthy';

  /// If argmax probability < [tfliteConfidenceThreshold], collapse to [uncertainLabel].
  /// Raw class probabilities in [allScores] are **preserved** for the chart UI.
  static DiseasePrediction applyConfidenceGate(DiseasePrediction raw) {
    if (raw.confidence >= tfliteConfidenceThreshold) return raw;
    return DiseasePrediction(
      label: uncertainLabel,
      confidence: raw.confidence,
      allScores: Map<String, double>.from(raw.allScores),
    );
  }

  /// Maps gated disease output + context into **Healthy / Moderate / Critical** (risk ladder).
  static CropHealthLevel mapToRiskTier({
    required DiseasePrediction disease,
    required PestRiskLevel pest,
    required LeafVisualFeatures visual,
  }) {
    if (disease.label == uncertainLabel) {
      return CropHealthLevel.moderate;
    }

    final healthy = disease.label == 'Healthy';
    final conf = disease.confidence;

    if (healthy &&
        conf >= tfliteConfidenceThreshold &&
        visual.pestInjuryScore < 0.07 &&
        visual.textureDamageScore < 0.16) {
      return CropHealthLevel.healthy;
    }

    if (disease.label == 'Pest Damage' && conf >= tfliteConfidenceThreshold) {
      return visual.pestInjuryScore > 0.12 || conf > 0.82
          ? CropHealthLevel.critical
          : CropHealthLevel.moderate;
    }

    final severe = disease.label == 'Leaf Blight' || disease.label == 'Rust';
    if (severe && conf >= tfliteConfidenceThreshold) {
      return CropHealthLevel.critical;
    }

    if (disease.label == 'Leaf Spot' && conf >= 0.55) {
      return conf >= tfliteConfidenceThreshold ? CropHealthLevel.critical : CropHealthLevel.moderate;
    }

    if (disease.label == 'Powdery Mildew' && conf >= 0.55) {
      return conf >= tfliteConfidenceThreshold ? CropHealthLevel.critical : CropHealthLevel.moderate;
    }

    if (!healthy && conf >= tfliteConfidenceThreshold) {
      return CropHealthLevel.critical;
    }

    if (!healthy && conf >= 0.35) {
      return CropHealthLevel.moderate;
    }

    if (pest == PestRiskLevel.high && visual.pestInjuryScore > 0.09) {
      return CropHealthLevel.moderate;
    }

    if (healthy) return CropHealthLevel.moderate;

    return CropHealthLevel.moderate;
  }
}
