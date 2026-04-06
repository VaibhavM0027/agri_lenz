/// Location-aware (coarse) agronomic hints — offline rules, not a full crop model.
abstract final class AgriContextService {
  const AgriContextService._();

  static String regionalHint({double? latitude, double? longitude}) {
    if (latitude == null) {
      return 'Enable location (optional) for regional weather and latitude-based tips.';
    }
    final lat = latitude.abs();
    if (lat < 15) {
      return 'Equatorial / wet tropics — prioritize fungal scouting after heavy rain; ensure drainage.';
    }
    if (lat < 23.5) {
      return 'Low-latitude / subtropical — balance irrigation with leaf wetness duration.';
    }
    if (lat < 35) {
      return 'Mid-latitude — watch rapid temperature swings; morning irrigation reduces scorch.';
    }
    if (lat < 50) {
      return 'Temperate belt — scout early-season rusts and late blights per local calendar.';
    }
    return 'Higher latitude / cooler season — shorter growing windows; protect tender starts from frost.';
  }
}
