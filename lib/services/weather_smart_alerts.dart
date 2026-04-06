import 'package:flutter/material.dart';

import '../models/analysis_models.dart';
import 'weather_service.dart';

/// Smart alerts based on weather conditions and crop health
class WeatherSmartAlerts {
  
  /// Generate smart alerts based on weather and crop condition
  static List<WeatherAlert> generateAlerts({
    required CropAnalysisReport report,
    WeatherSnapshot? weather,
  }) {
    final alerts = <WeatherAlert>[];
    
    if (weather == null) return alerts;
    
    // High temperature alerts
    if (weather.temperatureC > 35) {
      alerts.add(WeatherAlert(
        type: AlertType.warning,
        icon: Icons.thermostat,
        title: 'High Temperature Alert',
        message: 'Temperature is ${weather.temperatureC}°C. Increase irrigation frequency to prevent heat stress.',
        priority: AlertPriority.high,
      ));
    }
    
    // Low humidity alerts
    if (weather.humidityPercent < 30) {
      alerts.add(WeatherAlert(
        type: AlertType.warning,
        icon: Icons.water_drop,
        title: 'Low Humidity Warning',
        message: 'Humidity is only ${weather.humidityPercent}%. Consider mulching to retain soil moisture.',
        priority: AlertPriority.medium,
      ));
    }
    
    // Rain forecast alerts (based on weather code)
    final isRaining = weather.weatherCode >= 51 && weather.weatherCode <= 67 ||
                     weather.weatherCode >= 80;
    
    if (isRaining) {
      if (report.cropHealth == CropHealthLevel.critical) {
        alerts.add(WeatherAlert(
          type: AlertType.info,
          icon: Icons.cloud_off,
          title: 'Rain Expected - Delay Treatment',
          message: 'Rain forecasted. Postpone foliar spray applications until dry conditions.',
          priority: AlertPriority.high,
        ));
      } else {
        alerts.add(WeatherAlert(
          type: AlertType.success,
          icon: Icons.cloud_done,
          title: 'Good Rain Expected',
          message: 'Rain forecasted. This will help with soil moisture naturally.',
          priority: AlertPriority.low,
        ));
      }
    }
    
    // Disease-favorable conditions
    if (weather.humidityPercent > 80 && weather.temperatureC > 25) {
      if (report.disease.label.contains('Blight') || 
          report.disease.label.contains('Mildew') ||
          report.disease.label.contains('Rust')) {
        alerts.add(WeatherAlert(
          type: AlertType.danger,
          icon: Icons.bug_report,
          title: 'Disease Spread Risk HIGH',
          message: 'Warm, humid conditions favor disease spread. Apply fungicide preventively.',
          priority: AlertPriority.critical,
        ));
      }
    }
    
    // Frost warning
    if (weather.temperatureC < 5) {
      alerts.add(WeatherAlert(
        type: AlertType.danger,
        icon: Icons.ac_unit,
        title: 'Frost Warning!',
        message: 'Temperature dropping to ${weather.temperatureC}°C. Cover sensitive crops immediately.',
        priority: AlertPriority.critical,
      ));
    }
    
    // Optimal conditions
    if (alerts.isEmpty) {
      alerts.add(WeatherAlert(
        type: AlertType.success,
        icon: Icons.check_circle,
        title: 'Optimal Conditions',
        message: 'Weather conditions are favorable for crop growth and treatment application.',
        priority: AlertPriority.low,
      ));
    }
    
    // Sort by priority
    alerts.sort((a, b) => b.priority.index.compareTo(a.priority.index));
    
    return alerts;
  }
}

enum AlertType { info, success, warning, danger }

enum AlertPriority { low, medium, high, critical }

class WeatherAlert {
  const WeatherAlert({
    required this.type,
    required this.icon,
    required this.title,
    required this.message,
    required this.priority,
  });

  final AlertType type;
  final IconData icon;
  final String title;
  final String message;
  final AlertPriority priority;
  
  Color get color {
    switch (type) {
      case AlertType.info:
        return Colors.blue;
      case AlertType.success:
        return Colors.green;
      case AlertType.warning:
        return Colors.orange;
      case AlertType.danger:
        return Colors.red;
    }
  }
}

/// Widget to display weather alerts
class WeatherAlertCard extends StatelessWidget {
  const WeatherAlertCard({
    super.key,
    required this.alert,
  });

  final WeatherAlert alert;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: alert.color,
              width: 4,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                alert.icon,
                color: alert.color,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          alert.title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: alert.color,
                          ),
                        ),
                        const Spacer(),
                        _PriorityBadge(priority: alert.priority),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final AlertPriority priority;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    
    switch (priority) {
      case AlertPriority.low:
        color = Colors.grey;
        label = 'LOW';
        break;
      case AlertPriority.medium:
        color = Colors.blue;
        label = 'MED';
        break;
      case AlertPriority.high:
        color = Colors.orange;
        label = 'HIGH';
        break;
      case AlertPriority.critical:
        color = Colors.red;
        label = 'CRIT';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
