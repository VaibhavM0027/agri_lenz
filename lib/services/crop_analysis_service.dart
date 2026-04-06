import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import '../models/analysis_models.dart';
import 'analysis_quality.dart';
import 'crop_intel_engine.dart';
import 'heuristic_classifier.dart';
import 'leaf_visual_analyzer.dart';
import 'prediction_merge.dart';
import 'soil_image_analyzer.dart';
import 'soil_moisture_fusion.dart';
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

  /// [soilMoisture]: optional farmer field observation (sheet).
  /// [soilImageBytes]: optional soil surface photo for appearance heuristics.
  /// [sensor]: optional probe / demo readings.
  static Future<CropAnalysisReport> analyze(
    Uint8List imageBytes, {
    Uint8List? soilImageBytes,
    SoilMoistureLevel? soilMoisture,
    OptionalSensorSnapshot sensor = const OptionalSensorSnapshot(),
  }) async {
    try {
      // Safety check: validate image data
      if (imageBytes.isEmpty) {
        throw Exception('Image data is empty');
      }
      
      print('[CropAnalysis] Starting analysis, image size: ${imageBytes.lengthInBytes} bytes');
      
      _labels ??= await _loadLabels();
      final labels = _labels!;

      // Load TFLite model if available (non-blocking)
      await _ensureTflite(labels);

      // Step 1: Photo quality assessment
      print('[CropAnalysis] Step 1: Assessing photo quality...');
      final photoQuality = PhotoQualityAnalyzer.assess(imageBytes);
      
      // Step 2: Visual feature extraction (this is the heavy part)
      print('[CropAnalysis] Step 2: Extracting visual features...');
      final visual = LeafVisualAnalyzer.analyzeEnhanced(imageBytes);
      
      // Step 3: Heuristic classification
      final heuristic = HeuristicClassifier.predict(labels, visual);

      var disease = heuristic;
      var usedTflite = false;
      var visionCorrectedTflite = false;

      // Step 4: TFLite classification (if model loaded)
      final tflite = _tflite;
      if (tflite != null) {
        try {
          final rawCnn = tflite.classify(imageBytes);
          if (rawCnn != null) {
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
        } catch (e) {
          // If TFLite fails, fall back to heuristic
          print('TFLite classification failed, using heuristic: $e');
        }
      }

      final uncertainty = ClassUncertaintyAnalyzer.fromScores(disease.allScores);

      // Step 5: Soil moisture analysis
      final soilImageScore = SoilImageAnalyzer.moistureAppearanceScore(soilImageBytes);
      final fusion = SoilMoistureFusion.fuse(
        visual: visual,
        soilImageMoistureScore: soilImageScore,
        fieldObservation: soilMoisture,
        sensor: sensor,
      );

      final soil = SoilInsightEngine.describe(visual, moisture: fusion.advisoryLevel);
      final pest = PestRiskEngine.evaluate(disease, visual);
      
      // Get vision-based health assessment
      var health = CropHealthEngine.evaluate(visual);
      
      // SAFETY OVERRIDE: If leaf is clearly healthy (very high green, very low damage),
      // force to Healthy regardless of other signals
      final isClearlyHealthyLeaf = visual.greenRatio > 0.35 && 
                                   visual.brownRatio < 0.08 &&
                                   visual.yellowRatio < 0.10 &&
                                   visual.rustLikeRatio < 0.04 &&
                                   visual.pestInjuryScore < 0.08 &&
                                   visual.textureDamageScore < 0.15;
      
      if (isClearlyHealthyLeaf) {
        health = CropHealthLevel.healthy;
      }
      
      // CONSISTENCY CHECK: If diagnosis is Healthy/Uncertain but health is Critical/Moderate,
      // trust the visual features ONLY if there are STRONG indicators
      // This prevents contradictions where disease says "Healthy" but health says "Critical"
      else if ((disease.label == 'Healthy' || disease.label == TflitePostProcess.uncertainLabel) &&
          (health == CropHealthLevel.critical || health == CropHealthLevel.moderate)) {
        // Use VERY strict criteria matching the health policy thresholds
        final hasRealStress = visual.brownRatio > 0.225 || 
                             visual.yellowRatio > 0.245 ||
                             visual.rustLikeRatio > 0.125 ||
                             visual.pestInjuryScore > 0.285 ||
                             visual.borderBrownBias > 0.35;
        
        if (!hasRealStress) {
          // No real stress indicators - override to healthy
          health = CropHealthLevel.healthy;
        }
      }
      
      final recs = RecommendationEngine.build(
        disease,
        soil,
        health,
        pest,
        visual,
        photoQuality,
        uncertainty,
        fusion.advisoryLevel,
      );

      return CropAnalysisReport(
        previewBytes: imageBytes,
        cropHealth: health,
        disease: disease,
        pestRisk: pest,
        soilInsight: soil,
        soilMoisture: soilMoisture,
        soilMoistureBand: fusion.band,
        soilMoistureSummary: fusion.headline,
        soilMoistureDetail: fusion.detail,
        recommendations: recs,
        usedTfliteModel: usedTflite,
        visionCorrectedTflite: visionCorrectedTflite,
        visualFeatures: visual,
        photoQuality: photoQuality,
        uncertainty: uncertainty,
        usedMultiScaleVision: true,
        soilImagePreviewBytes: soilImageBytes,
      );
    } catch (e, stackTrace) {
      print('Crop analysis error: $e\n$stackTrace');
      rethrow; // Re-throw to be caught by the UI
    }
  }
}
