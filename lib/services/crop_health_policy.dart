import '../models/analysis_models.dart';

/// **Vision-first crop health:** the UI tier is driven mainly by leaf color and hole/chew cues.
///
/// - **Healthy** — no meaningful non-green lesion/stress palette and no hole-in-green signal.
/// - **Moderate** — some yellow/brown/rust, speckle, or chew/hole evidence below critical thresholds.
/// - **Critical** — strong chlorosis/necrosis/rust **or** clear holes/chew injury on green tissue.
///
/// The CNN label still appears separately for disease naming; it does **not** force critical
/// when the leaf still looks uniformly green and intact.
abstract final class CropHealthPolicy {
  const CropHealthPolicy._();

  /// Weighted “not healthy green” signal (0+).
  static double chromaticStress(LeafVisualFeatures v) =>
      v.yellowRatio * 1.08 +
      v.brownRatio * 1.15 +
      v.rustLikeRatio * 1.25 +
      v.paleRatio * 0.42 +
      v.borderBrownBias * 0.55;

  /// True if we see lesion / stress colors beyond plain green canopy.
  /// EXTREMELY STRICT - Only flag SEVERELY diseased leaves
  static bool hasNonGreenOrSpotStress(LeafVisualFeatures v) {
    // VERY high thresholds - healthy green leaves should NEVER trigger this
    if (v.rustLikeRatio >= 0.125) return true;  // Was 0.085 - need CLEAR rust
    if (v.brownRatio >= 0.225) return true;      // Was 0.165 - need significant browning
    if (v.yellowRatio >= 0.245) return true;     // Was 0.185 - need severe yellowing
    if (v.borderBrownBias >= 0.35) return true;  // Was 0.28 - need strong edge damage
    if (chromaticStress(v) >= 0.425) return true; // Was 0.295 - need major stress
    // Dark speckles on an otherwise green blade - only if BOTH conditions met
    if (v.greenRatio >= 0.24 && v.darkSpotRatio >= 0.165) return true; // Was 0.115
    return false;
  }

  /// Chew, hole rims, strong speckle — especially meaningful when green tissue dominates.
  /// EXTREMELY STRICT - healthy leaves should NEVER show pest signals
  static bool hasHoleOrChewSignal(LeafVisualFeatures v) {
    final p = v.pestInjuryScore;
    // VERY high thresholds - only clear physical damage
    if (p >= 0.285) return true;   // Was 0.215 - need severe injury
    if (v.greenRatio >= 0.22 && p >= 0.195) return true;  // Was 0.145
    return false;
  }

  static bool _criticalChromatic(LeafVisualFeatures v) {
    // EXTREME thresholds - only SEVERELY diseased leaves are critical
    if (v.brownRatio >= 0.305) return true;   // Was 0.225 - need massive browning
    if (v.yellowRatio >= 0.328) return true;  // Was 0.248 - need extreme yellowing
    if (v.rustLikeRatio >= 0.175) return true; // Was 0.115 - need heavy rust
    if (chromaticStress(v) >= 0.625) return true; // Was 0.485 - need critical stress
    if (v.greenRatio >= 0.26 && v.darkSpotRatio >= 0.205) return true; // Was 0.145
    return false;
  }

  static bool _criticalHoles(LeafVisualFeatures v) {
    final p = v.pestInjuryScore;
    // ULTRA strict - only extreme physical damage is critical
    if (p >= 0.345) return true;   // Was 0.265 - need massive injury
    if (v.greenRatio >= 0.24 && p >= 0.255) return true;  // Was 0.185
    return false;
  }

  /// Single tier used by both TFLite and heuristic-only pipelines.
  /// CNN disease label is shown separately; it does not override this tier.
  static CropHealthLevel resolve(LeafVisualFeatures visual) {
    final chroma = hasNonGreenOrSpotStress(visual);
    final holes = hasHoleOrChewSignal(visual);

    // User rule: uniform green + no holes → **healthy** (CNN cannot force critical alone).
    if (!chroma && !holes) {
      return CropHealthLevel.healthy;
    }

    if (_criticalChromatic(visual) || _criticalHoles(visual)) {
      return CropHealthLevel.critical;
    }

    return CropHealthLevel.moderate;
  }

  /// Short copy for cards / dashboard.
  static String explain(LeafVisualFeatures v, CropHealthLevel tier) {
    switch (tier) {
      case CropHealthLevel.healthy:
        return 'Green-dominant view with no strong yellow/brown/rust lesion signal and no hole/chew pattern — '
            'treated as healthy (check disease label separately if the model disagrees).';
      case CropHealthLevel.moderate:
        final bits = <String>[];
        if (hasNonGreenOrSpotStress(v)) bits.add('non-green or spot stress');
        if (hasHoleOrChewSignal(v)) bits.add('possible holes/chew');
        return 'Some ${bits.join(' + ')} — monitor and rescan if symptoms spread.';
      case CropHealthLevel.critical:
        final c = <String>[];
        if (_criticalChromatic(v)) c.add('strong lesion / stress colors');
        if (_criticalHoles(v)) c.add('clear hole or chew injury on green tissue');
        return 'Critical visual pattern: ${c.join(' and ')}.';
    }
  }
}
