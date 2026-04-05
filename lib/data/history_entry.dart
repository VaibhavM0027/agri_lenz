import 'dart:convert';
import 'dart:typed_data';

import '../models/analysis_models.dart';

class HistoryEntry {
  HistoryEntry({
    required this.id,
    required this.createdAt,
    required this.imageFileName,
    required this.diseaseLabel,
    required this.diseaseConfidence,
    required this.allScores,
    required this.cropHealthIndex,
    required this.pestRiskIndex,
    required this.soilInsight,
    required this.recommendations,
    required this.usedTfliteModel,
    required this.visionCorrectedTflite,
    required this.usedMultiScaleVision,
    required this.visualGreenRatio,
    required this.visualPestInjuryScore,
    required this.photoQualityScore,
    required this.photoQualityHint,
    required this.uncertaintyIsAmbiguous,
    required this.uncertaintyMessage,
    this.runnerUpLabel,
    this.runnerUpScore,
  });

  final String id;
  final DateTime createdAt;
  final String imageFileName;
  final String diseaseLabel;
  final double diseaseConfidence;
  final Map<String, double> allScores;
  final int cropHealthIndex;
  final int pestRiskIndex;
  final String soilInsight;
  final List<String> recommendations;
  final bool usedTfliteModel;
  final bool visionCorrectedTflite;
  final bool usedMultiScaleVision;
  final double visualGreenRatio;
  final double visualPestInjuryScore;
  final int photoQualityScore;
  final String photoQualityHint;
  final bool uncertaintyIsAmbiguous;
  final String uncertaintyMessage;
  final String? runnerUpLabel;
  final double? runnerUpScore;

  factory HistoryEntry.fromReport(
    CropAnalysisReport r, {
    required String id,
    required String imageFileName,
  }) {
    final v = r.visualFeatures;
    return HistoryEntry(
      id: id,
      createdAt: DateTime.now().toUtc(),
      imageFileName: imageFileName,
      diseaseLabel: r.disease.label,
      diseaseConfidence: r.disease.confidence,
      allScores: Map<String, double>.from(r.disease.allScores),
      cropHealthIndex: r.cropHealth.index,
      pestRiskIndex: r.pestRisk.index,
      soilInsight: r.soilInsight,
      recommendations: List<String>.from(r.recommendations),
      usedTfliteModel: r.usedTfliteModel,
      visionCorrectedTflite: r.visionCorrectedTflite,
      usedMultiScaleVision: r.usedMultiScaleVision,
      visualGreenRatio: v.greenRatio,
      visualPestInjuryScore: v.pestInjuryScore,
      photoQualityScore: r.photoQuality.score,
      photoQualityHint: r.photoQuality.hint,
      uncertaintyIsAmbiguous: r.uncertainty.isAmbiguous,
      uncertaintyMessage: r.uncertainty.message,
      runnerUpLabel: r.uncertainty.runnerUpLabel,
      runnerUpScore: r.uncertainty.runnerUpScore,
    );
  }

  CropAnalysisReport toReport(Uint8List previewBytes) {
    final vf = LeafVisualFeatures(
      greenRatio: visualGreenRatio,
      yellowRatio: 0.12,
      brownRatio: 0.08,
      paleRatio: 0.1,
      darkSpotRatio: 0.08,
      rustLikeRatio: 0.04,
      borderBrownBias: 0.1,
      textureDamageScore: 0.18,
      pestInjuryScore: visualPestInjuryScore,
    );
    return CropAnalysisReport(
      previewBytes: previewBytes,
      cropHealth: CropHealthLevel.values[cropHealthIndex.clamp(0, CropHealthLevel.values.length - 1)],
      disease: DiseasePrediction(
        label: diseaseLabel,
        confidence: diseaseConfidence,
        allScores: Map<String, double>.from(allScores),
      ),
      pestRisk: PestRiskLevel.values[pestRiskIndex.clamp(0, PestRiskLevel.values.length - 1)],
      soilInsight: soilInsight,
      recommendations: List<String>.from(recommendations),
      usedTfliteModel: usedTfliteModel,
      visionCorrectedTflite: visionCorrectedTflite,
      visualFeatures: vf,
      photoQuality: AnalysisQuality(score: photoQualityScore, hint: photoQualityHint),
      uncertainty: UncertaintyHint(
        isAmbiguous: uncertaintyIsAmbiguous,
        message: uncertaintyMessage,
        runnerUpLabel: runnerUpLabel,
        runnerUpScore: runnerUpScore,
      ),
      usedMultiScaleVision: usedMultiScaleVision,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'imageFileName': imageFileName,
        'diseaseLabel': diseaseLabel,
        'diseaseConfidence': diseaseConfidence,
        'allScores': allScores,
        'cropHealthIndex': cropHealthIndex,
        'pestRiskIndex': pestRiskIndex,
        'soilInsight': soilInsight,
        'recommendations': recommendations,
        'usedTfliteModel': usedTfliteModel,
        'visionCorrectedTflite': visionCorrectedTflite,
        'usedMultiScaleVision': usedMultiScaleVision,
        'visualGreenRatio': visualGreenRatio,
        'visualPestInjuryScore': visualPestInjuryScore,
        'photoQualityScore': photoQualityScore,
        'photoQualityHint': photoQualityHint,
        'uncertaintyIsAmbiguous': uncertaintyIsAmbiguous,
        'uncertaintyMessage': uncertaintyMessage,
        'runnerUpLabel': runnerUpLabel,
        'runnerUpScore': runnerUpScore,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> j) {
    final scores = <String, double>{};
    final raw = j['allScores'];
    if (raw is Map) {
      raw.forEach((k, v) {
        scores[k.toString()] = (v as num).toDouble();
      });
    }
    return HistoryEntry(
      id: j['id'] as String,
      createdAt: DateTime.parse(j['createdAt'] as String),
      imageFileName: j['imageFileName'] as String,
      diseaseLabel: j['diseaseLabel'] as String,
      diseaseConfidence: (j['diseaseConfidence'] as num).toDouble(),
      allScores: scores,
      cropHealthIndex: j['cropHealthIndex'] as int,
      pestRiskIndex: j['pestRiskIndex'] as int,
      soilInsight: j['soilInsight'] as String,
      recommendations: (j['recommendations'] as List<dynamic>).map((e) => e as String).toList(),
      usedTfliteModel: j['usedTfliteModel'] as bool,
      visionCorrectedTflite: j['visionCorrectedTflite'] as bool,
      usedMultiScaleVision: j['usedMultiScaleVision'] as bool? ?? true,
      visualGreenRatio: (j['visualGreenRatio'] as num?)?.toDouble() ?? 0.3,
      visualPestInjuryScore: (j['visualPestInjuryScore'] as num?)?.toDouble() ?? 0.1,
      photoQualityScore: j['photoQualityScore'] as int? ?? 60,
      photoQualityHint: j['photoQualityHint'] as String? ?? '',
      uncertaintyIsAmbiguous: j['uncertaintyIsAmbiguous'] as bool? ?? false,
      uncertaintyMessage: j['uncertaintyMessage'] as String? ?? '',
      runnerUpLabel: j['runnerUpLabel'] as String?,
      runnerUpScore: (j['runnerUpScore'] as num?)?.toDouble(),
    );
  }

  static String encodeList(List<HistoryEntry> entries) =>
      jsonEncode(entries.map((e) => e.toJson()).toList());

  static List<HistoryEntry> decodeList(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>)).toList();
  }
}
