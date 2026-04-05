import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import '../models/analysis_models.dart';
import 'analysis_quality.dart';
import 'crop_intel_engine.dart';
import 'heuristic_classifier.dart';
import 'leaf_visual_analyzer.dart';
import 'prediction_merge.dart';
import 'tflite_crop_classifier.dart';
import 'tflite_post_process.dart';

class CropAnalysisService {
  static TfliteCropClassifier? _tflite;
  static List<String>? _labels;

  static Future<List<String>> _loadLabels() async {
    final raw = await rootBundle.loadString('assets/models/labels.txt');
    return raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  }

  static Future<void> _ensureTflite(List<String> labels) async {
    if (_tflite != null) return;
    _tflite = await TfliteCropClassifier.tryLoad(labels);
  }

  /// Full pipeline: CNN (MobileNetV2/EfficientNet-style TFLite) + 70% confidence gate + vision merge +
  /// post-process risk tier when CNN ran.
  static Future<CropAnalysisReport> analyze(Uint8List imageBytes) async {
    _labels ??= await _loadLabels();
    final labels = _labels!;

    await _ensureTflite(labels);

    final photoQuality = PhotoQualityAnalyzer.assess(imageBytes);
    final visual = LeafVisualAnalyzer.analyzeEnhanced(imageBytes);
    final heuristic = HeuristicClassifier.predict(labels, visual);

    var disease = heuristic;
    var usedTflite = false;
    var visionCorrectedTflite = false;
    var cnnRanSuccessfully = false;

    final tflite = _tflite;
    if (tflite != null) {
      final rawCnn = tflite.classify(imageBytes);
      if (rawCnn != null) {
        cnnRanSuccessfully = true;
        final gated = TflitePostProcess.applyConfidenceGate(rawCnn);
        final merged = PredictionMerge.mergeTfliteWithVision(
          tflite: gated,
          heuristic: heuristic,
          visual: visual,
          labels: labels,
        );
        disease = merged.prediction;
        usedTflite = merged.usedRawTflite;
        visionCorrectedTflite = !merged.usedRawTflite;
      }
    }

    final uncertainty = ClassUncertaintyAnalyzer.fromScores(disease.allScores);
    final soil = SoilInsightEngine.describe(visual);
    final pest = PestRiskEngine.evaluate(disease, visual);
    final health = cnnRanSuccessfully
        ? TflitePostProcess.mapToRiskTier(disease: disease, pest: pest, visual: visual)
        : CropHealthEngine.evaluate(disease, visual, pest);
    final recs = RecommendationEngine.build(
      disease,
      soil,
      health,
      pest,
      visual,
      photoQuality,
      uncertainty,
    );

    return CropAnalysisReport(
      previewBytes: imageBytes,
      cropHealth: health,
      disease: disease,
      pestRisk: pest,
      soilInsight: soil,
      recommendations: recs,
      usedTfliteModel: usedTflite,
      visionCorrectedTflite: visionCorrectedTflite,
      visualFeatures: visual,
      photoQuality: photoQuality,
      uncertainty: uncertainty,
      usedMultiScaleVision: true,
    );
  }
}
