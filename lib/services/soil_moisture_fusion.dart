import '../models/analysis_models.dart';
import 'vision_robust.dart';

/// Fuses **leaf stress**, optional **soil photo heuristics**, **field observation**, and **sensor** hints.
abstract final class SoilMoistureFusion {
  const SoilMoistureFusion._();

  static SoilMoistureResult fuse({
    required LeafVisualFeatures visual,
    double? soilImageMoistureScore,
    SoilMoistureLevel? fieldObservation,
    OptionalSensorSnapshot sensor = const OptionalSensorSnapshot(),
  }) {
    final leafScore = _leafMoistureProxy(visual);
    final soil = soilImageMoistureScore;

    var fused = leafScore;
    if (soil != null) {
      fused = 0.45 * leafScore + 0.55 * soil;
    }

    if (fieldObservation != null) {
      final cal = fieldObservation.calibrationScore;
      // Trust farmer observation: stronger weight when soil image absent.
      final wField = soil != null ? 0.38 : 0.55;
      fused = (1 - wField) * fused + wField * cal;
    }

    if (sensor.soilMoisturePercent != null) {
      final p = (sensor.soilMoisturePercent!.clamp(0, 100)) / 100.0;
      fused = 0.5 * fused + 0.5 * p;
    } else if (sensor.humidityPercent != null && sensor.temperatureC != null) {
      // Hot + dry air → slight downward nudge; humid → slight upward (very soft).
      final h = sensor.humidityPercent!.clamp(0, 100) / 100.0;
      final hot = sensor.temperatureC! >= 32;
      fused += (h - 0.5) * 0.04;
      if (hot) fused -= 0.03;
      fused = fused.clamp(0.0, 1.0);
    }

    final band = _bandFromScore(fused);
    final advisory = _advisoryLevel(band, fieldObservation);

    final headline =
        'Soil moisture (estimated): ${band.emoji} ${band.shortLabel} — ${_bandVerb(band)}.';

    final detail = _buildDetail(
      visual: visual,
      soilImageMoistureScore: soilImageMoistureScore,
      fieldObservation: fieldObservation,
      sensor: sensor,
      fusedScore: fused,
      band: band,
    );

    return SoilMoistureResult(
      band: band,
      fusedScore: fused,
      headline: headline,
      detail: detail,
      advisoryLevel: advisory,
    );
  }

  /// **0 = stressed / likely dry profile**, **1 = ample water signal** from leaf appearance only.
  static double _leafMoistureProxy(LeafVisualFeatures v) {
    final lush = VisionRobustness.isHealthyLookingCanopy(v);
    var score = 0.52;
    score += (v.greenRatio - 0.30) * 0.55;
    score -= v.yellowRatio * 0.62;
    score -= v.brownRatio * 0.48;
    score -= v.paleRatio * 0.18;
    // Rolled / crisp margins sometimes track with drought stress.
    score -= v.borderBrownBias * 0.22;

    if (lush) {
      score += 0.06;
      score = score.clamp(0.38, 0.92);
    } else {
      score = score.clamp(0.12, 0.88);
    }
    return score;
  }

  static SoilMoistureBand _bandFromScore(double s) {
    if (s < 0.38) return SoilMoistureBand.low;
    if (s < 0.62) return SoilMoistureBand.moderate;
    return SoilMoistureBand.high;
  }

  static String _bandVerb(SoilMoistureBand b) => switch (b) {
        SoilMoistureBand.low => 'irrigate or confirm with a probe',
        SoilMoistureBand.moderate => 'generally in a workable range',
        SoilMoistureBand.high => 'ease irrigation and check drainage',
      };

  /// Level used for irrigation copy in [SoilMoistureAdvisor] — prefers farmer pick when present.
  static SoilMoistureLevel _advisoryLevel(SoilMoistureBand band, SoilMoistureLevel? field) {
    if (field != null) return field;
    return switch (band) {
      SoilMoistureBand.low => SoilMoistureLevel.dry,
      SoilMoistureBand.moderate => SoilMoistureLevel.adequate,
      SoilMoistureBand.high => SoilMoistureLevel.moist,
    };
  }

  static String _buildDetail({
    required LeafVisualFeatures visual,
    required double? soilImageMoistureScore,
    required SoilMoistureLevel? fieldObservation,
    required OptionalSensorSnapshot sensor,
    required double fusedScore,
    required SoilMoistureBand band,
  }) {
    final parts = <String>[];

    parts.add(
      'Combined estimate (${(fusedScore * 100).round()}% internal wetness index): '
      '${band.emoji} ${band.shortLabel} moisture. This is a smartphone heuristic — confirm with a field probe when possible.',
    );

    final lush = VisionRobustness.isHealthyLookingCanopy(visual);
    if (lush) {
      parts.add('Leaf canopy looks turgid and green — leaf cues lean toward adequate water unless hidden drought (deep soil dry).');
    } else if (visual.yellowRatio > 0.14 || visual.brownRatio > 0.12) {
      parts.add('Leaf yellowing or necrosis can track with drought **or** nutrition — paired soil/root checks help separate causes.');
    } else {
      parts.add('Leaf color is mixed — soil photo or probe improves confidence.');
    }

    final sImg = soilImageMoistureScore;
    if (sImg != null) {
      parts.add(
        'Soil photo appearance score ${(sImg * 100).round()}/100 '
        '(darker, cohesive soil often reads wetter; bright dusty soil reads drier).',
      );
    } else {
      parts.add('No soil photo — estimate leans on leaf stress cues and any field reading you provided.');
    }

    if (fieldObservation != null) {
      parts.add('Your field observation (“${fieldObservation.displayTitle}”) was blended into this estimate.');
    }

    if (!sensor.isEmpty) {
      final bits = <String>[];
      if (sensor.soilMoisturePercent != null) bits.add('probe ${sensor.soilMoisturePercent}%');
      if (sensor.temperatureC != null) bits.add('${sensor.temperatureC}°C');
      if (sensor.humidityPercent != null) bits.add('RH ${sensor.humidityPercent}%');
      parts.add('Sensor / demo inputs: ${bits.join(', ')}.');
    }

    return parts.join(' ');
  }
}

class SoilMoistureResult {
  const SoilMoistureResult({
    required this.band,
    required this.fusedScore,
    required this.headline,
    required this.detail,
    required this.advisoryLevel,
  });

  final SoilMoistureBand band;
  final double fusedScore;
  final String headline;
  final String detail;

  /// For [SoilMoistureAdvisor] lines and cross-checks.
  final SoilMoistureLevel advisoryLevel;
}
