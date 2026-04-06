import '../models/analysis_models.dart';

/// Reduces false “pest / critical” reads on **healthy, lush green** leaves where veins,
/// shadows, and natural texture mimic damage in naive pixel heuristics.
abstract final class VisionRobustness {
  /// Strong green tissue, little chlorosis/necrosis — typical of a healthy leaf photo.
  static bool isHealthyLookingCanopy(LeafVisualFeatures f) {
    return f.greenRatio >= 0.30 &&
        f.yellowRatio < 0.13 &&
        f.brownRatio < 0.10 &&
        f.paleRatio < 0.22;
  }

  /// Require stronger injury evidence before treating heuristics as pest-like.
  static bool allowAggressivePestHeuristics(LeafVisualFeatures f) {
    if (!isHealthyLookingCanopy(f)) return true;
    return f.pestInjuryScore > 0.13;
  }
}
