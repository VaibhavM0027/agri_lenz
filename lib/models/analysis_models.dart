import 'dart:typed_data';

enum CropHealthLevel { healthy, moderate, critical }

enum PestRiskLevel { low, medium, high }

class AnalysisQuality {
  const AnalysisQuality({required this.score, required this.hint});

  final int score;
  final String hint;
}

class UncertaintyHint {
  const UncertaintyHint({
    required this.isAmbiguous,
    required this.message,
    this.runnerUpLabel,
    this.runnerUpScore,
  });

  final bool isAmbiguous;
  final String message;
  final String? runnerUpLabel;
  final double? runnerUpScore;
}

class LeafVisualFeatures {
  const LeafVisualFeatures({
    required this.greenRatio,
    required this.yellowRatio,
    required this.brownRatio,
    required this.paleRatio,
    required this.darkSpotRatio,
    required this.rustLikeRatio,
    required this.borderBrownBias,
    required this.textureDamageScore,
    required this.pestInjuryScore,
  });

  final double greenRatio;
  final double yellowRatio;
  final double brownRatio;
  final double paleRatio;
  final double darkSpotRatio;
  final double rustLikeRatio;
  final double borderBrownBias;
  final double textureDamageScore;

  /// Composite 0–1: holes, speckles, chew-like edges on green tissue (not disease color alone).
  final double pestInjuryScore;
}

class DiseasePrediction {
  const DiseasePrediction({
    required this.label,
    required this.confidence,
    required this.allScores,
  });

  final String label;
  final double confidence;
  final Map<String, double> allScores;
}

class CropAnalysisReport {
  const CropAnalysisReport({
    required this.previewBytes,
    required this.cropHealth,
    required this.disease,
    required this.pestRisk,
    required this.soilInsight,
    required this.recommendations,
    required this.usedTfliteModel,
    required this.visionCorrectedTflite,
    required this.visualFeatures,
    required this.photoQuality,
    required this.uncertainty,
    required this.usedMultiScaleVision,
  });

  final Uint8List previewBytes;
  final CropHealthLevel cropHealth;
  final DiseasePrediction disease;
  final PestRiskLevel pestRisk;
  final String soilInsight;
  final List<String> recommendations;
  final bool usedTfliteModel;

  /// True when a bundled TFLite model ran but leaf-level vision overrode its label.
  final bool visionCorrectedTflite;
  final LeafVisualFeatures visualFeatures;
  final AnalysisQuality photoQuality;
  final UncertaintyHint uncertainty;

  /// Multi-scale + lighting-normalized fusion for more stable vision scores.
  final bool usedMultiScaleVision;

  String get healthLabel {
    switch (cropHealth) {
      case CropHealthLevel.healthy:
        return 'Healthy';
      case CropHealthLevel.moderate:
        return 'Moderate Risk';
      case CropHealthLevel.critical:
        return 'Critical';
    }
  }

  String get pestRiskLabel {
    switch (pestRisk) {
      case PestRiskLevel.low:
        return 'Low';
      case PestRiskLevel.medium:
        return 'Medium';
      case PestRiskLevel.high:
        return 'High';
    }
  }

  String get formattedReport {
    final pct = (disease.confidence * 100).clamp(0, 100).toStringAsFixed(0);
    final mode = visionCorrectedTflite
        ? 'TensorFlow Lite + visual injury check'
        : (usedTfliteModel ? 'TensorFlow Lite' : 'Visual intelligence');
    final buf = StringBuffer()
      ..writeln('Crop Health: $healthLabel')
      ..writeln('Detected: ${disease.label} (Confidence: $pct%)')
      ..writeln('Pest Risk: $pestRiskLabel')
      ..writeln('Soil Insight: $soilInsight')
      ..writeln('Analysis mode: $mode');
    if (visionCorrectedTflite) {
      buf.writeln('Note: vision layer adjusted the model output (holes / chew / speckle cues).');
    }
    buf.writeln('Photo quality score: ${photoQuality.score}/100 — ${photoQuality.hint}');
    if (uncertainty.message.isNotEmpty) {
      buf.writeln('Confidence note: ${uncertainty.message}');
    }
    buf.writeln();
    buf.writeln('Recommendations:');
    for (final r in recommendations) {
      buf.writeln('- $r');
    }
    return buf.toString();
  }
}
