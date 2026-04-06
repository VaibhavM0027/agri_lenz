import '../models/soil_moisture.dart';

/// Irrigation and drainage guidance from **observed or probed** soil moisture.
abstract final class SoilMoistureAdvisor {
  const SoilMoistureAdvisor._();

  static String summary(SoilMoistureLevel level) {
    return 'Soil moisture (your input): ${level.displayTitle} — ${level.shortHint}.';
  }

  static List<String> recommendations(SoilMoistureLevel level) {
    return switch (level) {
      SoilMoistureLevel.veryDry => [
          'Irrigate deeply and less often to rebuild root zone moisture; mulch to cut evaporation.',
          'Check emitter/drip uniformity if using drip; avoid midday sprinkling.',
        ],
      SoilMoistureLevel.dry => [
          'Water within 24–48 h if forecast is hot; prefer morning irrigation.',
          'Probe 10–15 cm depth — if still dry, increase duration not just frequency.',
        ],
      SoilMoistureLevel.adequate => [
          'Maintain schedule; scout leaves daily during heat waves for early wilt.',
        ],
      SoilMoistureLevel.moist => [
          'Delay next irrigation until topsoil dries slightly — reduces fungal leaf wetness issues.',
          'Ensure drainage paths stay clear if heavy rain is expected.',
        ],
      SoilMoistureLevel.waterlogged => [
          'Stop irrigation; consider raised beds, subsurface drains, or shallow tillage to break crust.',
          'Watch for root-rot pathogens; improve organic matter long-term for structure.',
        ],
    };
  }

  /// Optional tie-in with leaf stress (yellowing can worsen under both drought and overwater).
  static String crossCheckWithLeaf(String soilInsight, SoilMoistureLevel level) {
    final w = level == SoilMoistureLevel.waterlogged || level == SoilMoistureLevel.moist;
    final d = level == SoilMoistureLevel.veryDry || level == SoilMoistureLevel.dry;
    if (d && soilInsight.contains('yellow')) {
      return 'Moisture is low while leaves show yellowing — rule out N deficiency vs drought stress with a soil probe.';
    }
    if (w && soilInsight.contains('yellow')) {
      return 'Wet soil plus yellowing may indicate poor aeration or root issues, not always N lack.';
    }
    return '';
  }
}
