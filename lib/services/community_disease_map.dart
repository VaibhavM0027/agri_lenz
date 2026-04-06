import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Community-driven disease outbreak tracking
class CommunityDiseaseMap {
  static const String _keyReports = 'community_disease_reports';
  
  /// Submit a disease report to community
  static Future<void> submitReport({
    required String disease,
    required double latitude,
    required double longitude,
    required String cropType,
    required String severity, // 'low', 'medium', 'high'
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final reports = await loadReports();
    
    final newReport = CommunityReport(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      disease: disease,
      latitude: latitude,
      longitude: longitude,
      cropType: cropType,
      severity: severity,
      timestamp: DateTime.now(),
      userId: 'anonymous', // Privacy-first approach
    );
    
    reports.add(newReport);
    
    // Keep only last 100 reports to save space
    if (reports.length > 100) {
      reports.removeRange(0, reports.length - 100);
    }
    
    await prefs.setString(_keyReports, jsonEncode(reports.map((r) => r.toJson()).toList()));
  }
  
  /// Load all community reports
  static Future<List<CommunityReport>> loadReports() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyReports);
    
    if (data == null) return [];
    
    try {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList.map((json) => CommunityReport.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }
  
  /// Get disease hotspots (areas with multiple reports)
  static Future<List<DiseaseHotspot>> getHotspots() async {
    final reports = await loadReports();
    final hotspots = <String, DiseaseHotspot>{};
    
    for (final report in reports) {
      // Group by disease type
      if (!hotspots.containsKey(report.disease)) {
        hotspots[report.disease] = DiseaseHotspot(
          disease: report.disease,
          reportCount: 0,
          affectedArea: '',
          severity: report.severity,
          lastReported: report.timestamp,
        );
      }
      
      final hotspot = hotspots[report.disease]!;
      hotspot.reportCount++;
      if (report.timestamp.isAfter(hotspot.lastReported)) {
        hotspot.lastReported = report.timestamp;
      }
    }
    
    return hotspots.values.toList()
      ..sort((a, b) => b.reportCount.compareTo(a.reportCount));
  }
  
  /// Get nearby outbreaks (within ~50km)
  static Future<List<CommunityReport>> getNearbyOutbreaks({
    required double userLatitude,
    required double userLongitude,
  }) async {
    final reports = await loadReports();
    final nearby = <CommunityReport>[];
    
    for (final report in reports) {
      final distance = _calculateDistance(
        userLatitude, userLongitude,
        report.latitude, report.longitude,
      );
      
      // Within 50km
      if (distance <= 50) {
        nearby.add(report);
      }
    }
    
    // Sort by most recent
    nearby.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return nearby;
  }
  
  /// Calculate distance between two points (Haversine formula)
  static double _calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    const double earthRadius = 6371; // km
    
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = 
      _sin2(dLat / 2) +
      _cos(lat1) * _cos(lat2) * _sin2(dLon / 2);
    
    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  static double _toRadians(double degrees) => degrees * 3.141592653589793 / 180;
  static double _sin2(double x) {
    final s = _sin(x);
    return s * s;
  }
  static double _sin(double x) => x - (x*x*x)/6 + (x*x*x*x*x)/120; // Approximation
  static double _cos(double x) => 1 - (x*x)/2 + (x*x*x*x)/24; // Approximation
  static double _sqrt(double x) {
    if (x == 0) return 0;
    var result = x;
    for (int i = 0; i < 10; i++) {
      result = (result + x / result) / 2;
    }
    return result;
  }
  static double _atan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.141592653589793;
    if (x < 0 && y < 0) return _atan(y / x) - 3.141592653589793;
    if (x == 0 && y > 0) return 3.141592653589793 / 2;
    if (x == 0 && y < 0) return -3.141592653589793 / 2;
    return 0;
  }
  static double _atan(double x) {
    if (x < 0) return -_atan(-x);
    if (x > 1) return 3.141592653589793 / 2 - _atan(1 / x);
    return x - (x*x*x)/3 + (x*x*x*x*x)/5 - (x*x*x*x*x*x*x)/7;
  }
}

class CommunityReport {
  const CommunityReport({
    required this.id,
    required this.disease,
    required this.latitude,
    required this.longitude,
    required this.cropType,
    required this.severity,
    required this.timestamp,
    required this.userId,
  });

  final String id;
  final String disease;
  final double latitude;
  final double longitude;
  final String cropType;
  final String severity;
  final DateTime timestamp;
  final String userId;
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'disease': disease,
    'latitude': latitude,
    'longitude': longitude,
    'cropType': cropType,
    'severity': severity,
    'timestamp': timestamp.toIso8601String(),
    'userId': userId,
  };
  
  factory CommunityReport.fromJson(Map<String, dynamic> json) {
    return CommunityReport(
      id: json['id'] as String,
      disease: json['disease'] as String,
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      cropType: json['cropType'] as String,
      severity: json['severity'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      userId: json['userId'] as String,
    );
  }
}

class DiseaseHotspot {
  DiseaseHotspot({
    required this.disease,
    required this.reportCount,
    required this.affectedArea,
    required this.severity,
    required this.lastReported,
  });

  final String disease;
  int reportCount;
  final String affectedArea;
  final String severity;
  DateTime lastReported;
}

/// Widget to display community disease alerts
class CommunityAlertBanner extends StatelessWidget {
  const CommunityAlertBanner({
    super.key,
    required this.nearbyCount,
    required this.onTap,
  });

  final int nearbyCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (nearbyCount == 0) return const SizedBox.shrink();
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.orange.shade400,
              Colors.red.shade400,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '⚠️ Nearby Disease Outbreaks',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$nearbyCount reported case${nearbyCount > 1 ? 's' : ''} within 50km',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
