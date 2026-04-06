/// User-facing **three-band** estimate (leaf + optional soil photo + field feel + optional sensor).
enum SoilMoistureBand {
  /// Dry / wilt risk — irrigate soon.
  low,

  /// Typical range for many crops after irrigation cycle.
  moderate,

  /// Wet profile — ease irrigation, watch drainage.
  high,
}

extension SoilMoistureBandX on SoilMoistureBand {
  String get emoji => switch (this) {
        SoilMoistureBand.low => '🔴',
        SoilMoistureBand.moderate => '🟡',
        SoilMoistureBand.high => '🟢',
      };

  String get shortLabel => switch (this) {
        SoilMoistureBand.low => 'Low',
        SoilMoistureBand.moderate => 'Moderate',
        SoilMoistureBand.high => 'High',
      };
}

/// Optional in-field probe / IoT-style readings (simulated or real). All fields optional.
class OptionalSensorSnapshot {
  const OptionalSensorSnapshot({
    this.soilMoisturePercent,
    this.temperatureC,
    this.humidityPercent,
  });

  /// Volumetric or relative probe 0–100 if available.
  final int? soilMoisturePercent;
  final int? temperatureC;
  final int? humidityPercent;

  bool get isEmpty =>
      soilMoisturePercent == null && temperatureC == null && humidityPercent == null;
}

/// Fine-grained field observation from the farmer (finger/probe). Used to **calibrate** vision estimates.
enum SoilMoistureLevel {
  veryDry,
  dry,
  adequate,
  moist,
  waterlogged,
}

extension SoilMoistureLevelX on SoilMoistureLevel {
  String get displayTitle => switch (this) {
        SoilMoistureLevel.veryDry => 'Very dry',
        SoilMoistureLevel.dry => 'Dry',
        SoilMoistureLevel.adequate => 'Adequate',
        SoilMoistureLevel.moist => 'Moist',
        SoilMoistureLevel.waterlogged => 'Waterlogged',
      };

  String get shortHint => switch (this) {
        SoilMoistureLevel.veryDry => 'Crumbly; no cool feel deep down',
        SoilMoistureLevel.dry => 'Slightly cool; water soon in heat',
        SoilMoistureLevel.adequate => 'Balanced for many crops',
        SoilMoistureLevel.moist => 'Holds shape; high water retention',
        SoilMoistureLevel.waterlogged => 'Mud, pooling, or sour smell',
      };

  /// Maps to 0–1 internal moisture scale for fusion.
  double get calibrationScore => switch (this) {
        SoilMoistureLevel.veryDry => 0.12,
        SoilMoistureLevel.dry => 0.28,
        SoilMoistureLevel.adequate => 0.52,
        SoilMoistureLevel.moist => 0.78,
        SoilMoistureLevel.waterlogged => 0.95,
      };
}
