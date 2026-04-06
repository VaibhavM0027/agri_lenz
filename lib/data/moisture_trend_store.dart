import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/soil_moisture.dart';

class MoistureTrendPoint {
  const MoistureTrendPoint({required this.at, required this.bandIndex});

  final DateTime at;
  final int bandIndex;

  Map<String, dynamic> toJson() => {'at': at.toIso8601String(), 'b': bandIndex};

  static MoistureTrendPoint? fromJson(Map<String, dynamic> j) {
    try {
      return MoistureTrendPoint(
        at: DateTime.parse(j['at'] as String),
        bandIndex: j['b'] as int,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Persists recent **fused** moisture bands for a simple in-app trend strip.
abstract final class MoistureTrendStore {
  const MoistureTrendStore._();

  static const _key = 'agri_lenz_moisture_trend_v1';
  static const _max = 14;

  static Future<List<MoistureTrendPoint>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final out = <MoistureTrendPoint>[];
      for (final e in list) {
        if (e is Map<String, dynamic>) {
          final p = MoistureTrendPoint.fromJson(e);
          if (p != null) out.add(p);
        }
      }
      out.sort((a, b) => a.at.compareTo(b.at));
      return out;
    } catch (_) {
      return [];
    }
  }

  static Future<void> record(SoilMoistureBand band) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await load();
    final next = [
      ...existing,
      MoistureTrendPoint(at: DateTime.now().toUtc(), bandIndex: band.index),
    ];
    if (next.length > _max) {
      next.removeRange(0, next.length - _max);
    }
    await prefs.setString(
      _key,
      jsonEncode(next.map((e) => e.toJson()).toList()),
    );
  }
}
