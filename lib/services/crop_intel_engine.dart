import '../models/analysis_models.dart';
import 'crop_health_policy.dart';
import 'disease_remedies.dart';
import 'soil_moisture_advisor.dart';
import 'tflite_post_process.dart';
import 'vision_robust.dart';

class SoilInsightEngine {
  static String describe(LeafVisualFeatures f, {SoilMoistureLevel? moisture}) {
    var base = _baseLeafSoilHint(f);
    if (moisture != null) {
      final cross = SoilMoistureAdvisor.crossCheckWithLeaf(base, moisture);
      if (cross.isNotEmpty) {
        base = '$base $cross';
      }
    }
    return base;
  }

  static String _baseLeafSoilHint(LeafVisualFeatures f) {
    if (f.pestInjuryScore > 0.16) {
      return 'Irregular holes, speckles, or chew marks — often insect or mechanical injury rather than soil chemistry alone';
    }
    if (f.yellowRatio > 0.16) {
      return 'Nitrogen deficiency likely (yellowing patterns)';
    }
    if (f.borderBrownBias > 0.22 || f.brownRatio > 0.2) {
      return 'Potassium deficiency or marginal scorch — check K and irrigation';
    }
    if (f.paleRatio > 0.22) {
      return 'Pale foliage — poor soil fertility or micronutrient stress possible';
    }
    if (f.greenRatio > 0.35 && f.yellowRatio < 0.08 && f.brownRatio < 0.08 && f.pestInjuryScore < 0.085) {
      return 'Leaf color suggests adequate fertility from this view';
    }
    return 'No strong soil stress signature — keep balanced NPK and organic matter';
  }
}

class PestRiskEngine {
  static bool _treatAsHealthyForPest(String label) =>
      label == 'Healthy' || label == TflitePostProcess.uncertainLabel;

  static PestRiskLevel evaluate(DiseasePrediction disease, LeafVisualFeatures f) {
    final lush = VisionRobustness.isHealthyLookingCanopy(f);

    if (disease.label == 'Pest Damage') {
      if (disease.confidence >= 0.72 || f.pestInjuryScore > (lush ? 0.11 : 0.095)) {
        return PestRiskLevel.high;
      }
      return PestRiskLevel.medium;
    }

    // Healthy / uncertain: pest tier follows **visible injury** only — no automatic “high”.
    if (_treatAsHealthyForPest(disease.label)) {
      final highP = lush ? 0.165 : 0.125;
      final medP = lush ? 0.10 : 0.078;
      final medTex = lush ? 0.26 : 0.195;
      final medDark = lush ? 0.092 : 0.072;

      if (f.pestInjuryScore > highP) return PestRiskLevel.high;
      if (f.pestInjuryScore > medP || f.textureDamageScore > medTex || f.darkSpotRatio > medDark) {
        return PestRiskLevel.medium;
      }
      return PestRiskLevel.low;
    }

    // Diseased tissue can attract secondary pests, but avoid labeling every disease photo “high”.
    if (f.pestInjuryScore > (lush ? 0.14 : 0.115)) return PestRiskLevel.high;
    if (disease.label == 'Leaf Blight' || disease.label == 'Rust') {
      return PestRiskLevel.medium;
    }
    return PestRiskLevel.medium;
  }
}

class CropHealthEngine {
  static CropHealthLevel evaluate(LeafVisualFeatures f) => CropHealthPolicy.resolve(f);
}

class RecommendationEngine {
  static List<String> build(
    DiseasePrediction disease,
    String soil,
    CropHealthLevel health,
    PestRiskLevel pest,
    LeafVisualFeatures visual,
    AnalysisQuality photo,
    UncertaintyHint uncertainty,
    SoilMoistureLevel? soilMoisture,
  ) {
    final out = <String>[];

    void add(String s) {
      if (!out.contains(s)) out.add(s);
    }

    if (disease.label == TflitePostProcess.uncertainLabel) {
      add('CNN confidence was below 70% — treat as precautionary; rescan with a sharper, well-lit leaf photo');
      add('If the plant looks fine in the field, monitor without treatment until a clearer diagnosis');
    }

    if (photo.score < 58) {
      add('Retake the photo with sharper focus and soft daylight — low image quality reduces detection accuracy');
    }
    if (uncertainty.isAmbiguous) {
      add('Scan a second leaf from the same plant to confirm — top diagnoses were statistically close');
    }

    if (soilMoisture != null) {
      for (final line in SoilMoistureAdvisor.recommendations(soilMoisture)) {
        add(line);
      }
    }

    if (disease.label != TflitePostProcess.uncertainLabel) {
      for (final line in DiseaseRemedies.forLabel(disease.label)) {
        add(line);
      }
    }

    if (health == CropHealthLevel.healthy &&
        disease.label != 'Healthy' &&
        disease.label != TflitePostProcess.uncertainLabel) {
      add(
        'Health tier follows leaf color + holes: this photo still looks mostly green/intact — '
        'use the disease label as a hint and verify on the plant or rescan another leaf.',
      );
    }

    final showPestIpm = disease.label == 'Pest Damage' ||
        (visual.pestInjuryScore > 0.135 && VisionRobustness.allowAggressivePestHeuristics(visual));
    if (showPestIpm) {
      add('Inspect leaf undersides with a hand lens for mites, aphids, caterpillars, or beetle adults');
      add('Shake foliage over white paper — moving specks can confirm thrips or mites');
      add('Consider labeled biocontrol or reduced-risk insecticides (neem, spinosad, soaps) per crop label');
      add('Remove heavily damaged leaves and destroy them away from the field to reduce egg loads');
      add('Install yellow sticky traps to monitor flying pests and time sprays');
    }

    if (soil.contains('Nitrogen')) {
      add('Apply nitrogen-rich fertilizer (for example urea) per local extension guidance');
    }
    if (soil.contains('Potassium')) {
      add('Consider potassium supplement and review irrigation uniformity');
    }
    if (soil.contains('fertility') || soil.contains('micronutrient')) {
      add('Improve organic matter and run a soil test for micronutrients');
    }

    // Disease-specific remedy lines come from [DiseaseRemedies] (Plant-Village–style IPM hints).

    if (pest == PestRiskLevel.high && disease.label != 'Pest Damage') {
      add('High pest pressure risk — scout twice weekly and rotate modes of action if spraying');
    } else if (pest == PestRiskLevel.medium) {
      add('Monitor for spreading holes or new frass; treat early while damage is localized');
    }

    if (health == CropHealthLevel.critical) {
      add('Isolate affected plants if feasible and consult an agronomist for local protocols');
    }

    add('Keep consistent irrigation and photograph changes every few days');

    return out.take(18).toList();
  }
}
