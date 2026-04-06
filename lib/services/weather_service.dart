import 'dart:convert';

import 'package:http/http.dart' as http;

/// Open-Meteo current weather (no API key). Returns null on failure / timeout.
abstract final class WeatherService {
  const WeatherService._();

  static const _timeout = Duration(seconds: 8);

  static Future<WeatherSnapshot?> fetchCurrent({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$latitude&longitude=$longitude'
      '&current=temperature_2m,relative_humidity_2m,weather_code',
    );
    try {
      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final cur = j['current'] as Map<String, dynamic>?;
      if (cur == null) return null;
      return WeatherSnapshot(
        temperatureC: (cur['temperature_2m'] as num).toDouble(),
        humidityPercent: (cur['relative_humidity_2m'] as num).round(),
        weatherCode: cur['weather_code'] as int? ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.temperatureC,
    required this.humidityPercent,
    required this.weatherCode,
  });

  final double temperatureC;
  final int humidityPercent;
  final int weatherCode;

  String get summaryLabel {
    // WMO weather interpretation codes (simplified).
    if (weatherCode == 0) return 'Clear';
    if (weatherCode <= 3) return 'Partly cloudy';
    if (weatherCode >= 51 && weatherCode <= 67) return 'Rain / drizzle';
    if (weatherCode >= 71 && weatherCode <= 77) return 'Snow';
    if (weatherCode >= 80) return 'Rain showers';
    if (weatherCode >= 95) return 'Thunderstorm';
    return 'Mixed conditions';
  }
}
