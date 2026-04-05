import '../models/analysis_models.dart';
import 'tflite_post_process.dart';

class SoilInsightEngine {
  static String describe(LeafVisualFeatures f) {
    if (f.pestInjuryScore > 0.12) {
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
    if (f.greenRatio > 0.35 && f.yellowRatio < 0.08 && f.brownRatio < 0.08 && f.pestInjuryScore < 0.06) {
      return 'Leaf color suggests adequate fertility from this view';
    }
    return 'No strong soil stress signature — keep balanced NPK and organic matter';
  }
}

class PestRiskEngine {
  static bool _treatAsHealthyForPest(String label) =>
      label == 'Healthy' || label == TflitePostProcess.uncertainLabel;

  static PestRiskLevel evaluate(DiseasePrediction disease, LeafVisualFeatures f) {
    if (disease.label == 'Pest Damage') return PestRiskLevel.high;

    if (!_treatAsHealthyForPest(disease.label)) return PestRiskLevel.high;

    if (f.pestInjuryScore > 0.095) return PestRiskLevel.high;
    if (f.pestInjuryScore > 0.055 || f.textureDamageScore > 0.165 || f.darkSpotRatio > 0.065) {
      return PestRiskLevel.medium;
    }
    return PestRiskLevel.low;
  }
}

class CropHealthEngine {
  static CropHealthLevel evaluate(DiseasePrediction disease, LeafVisualFeatures f, PestRiskLevel pest) {
    final healthy = disease.label == 'Healthy';
    final conf = disease.confidence;

    if (disease.label == 'Pest Damage' || (pest == PestRiskLevel.high && f.pestInjuryScore > 0.08)) {
      return f.pestInjuryScore > 0.14 || disease.confidence > 0.72
          ? CropHealthLevel.critical
          : CropHealthLevel.moderate;
    }

    if (healthy &&
        conf > 0.68 &&
        f.greenRatio > 0.22 &&
        f.brownRatio < 0.11 &&
        f.pestInjuryScore < 0.055 &&
        f.textureDamageScore < 0.155) {
      return CropHealthLevel.healthy;
    }

    if (f.pestInjuryScore > 0.07 || pest == PestRiskLevel.high) {
      return f.pestInjuryScore > 0.12 ? CropHealthLevel.critical : CropHealthLevel.moderate;
    }

    final severe = disease.label == 'Leaf Blight' || disease.label == 'Rust';
    if (severe && conf > 0.4) return CropHealthLevel.critical;

    if (disease.label == 'Leaf Spot' && conf > 0.52) return CropHealthLevel.critical;

    if (disease.label == 'Powdery Mildew' && conf > 0.65) return CropHealthLevel.critical;

    if (!healthy && conf > 0.58) return CropHealthLevel.critical;

    if (!healthy && conf > 0.26) return CropHealthLevel.moderate;

    if (healthy && conf > 0.52 && (f.yellowRatio > 0.12 || f.brownRatio > 0.1)) {
      return CropHealthLevel.moderate;
    }

    if (f.brownRatio + f.darkSpotRatio > 0.26) return CropHealthLevel.moderate;

    return CropHealthLevel.healthy;
  }
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

    if (disease.label == 'Pest Damage' || visual.pestInjuryScore > 0.08) {
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

    switch (disease.label) {
      case TflitePostProcess.uncertainLabel:
        break;
      case 'Leaf Blight':
        add('Use an appropriate fungicide promptly and remove heavily infected tissue');
        add('Improve canopy airflow and avoid prolonged leaf wetness');
      case 'Powdery Mildew':
        add('Apply sulfur- or neem-based treatments suitable for your crop');
        add('Reduce crowding and humidity around leaves where possible');
      case 'Rust':
        add('Apply a labeled rust fungicide and destroy crop debris near the field');
      case 'Leaf Spot':
        add('Use a copper or broad-spectrum fungicide per label; avoid overhead irrigation');
      case 'Pest Damage':
        break;
      default:
        break;
    }

    if (pest == PestRiskLevel.high && disease.label != 'Pest Damage') {
      add('High pest pressure risk — scout twice weekly and rotate modes of action if spraying');
    } else if (pest == PestRiskLevel.medium) {
      add('Monitor for spreading holes or new frass; treat early while damage is localized');
    }

    if (health == CropHealthLevel.critical) {
      add('Isolate affected plants if feasible and consult an agronomist for local protocols');
    }

    add('Keep consistent irrigation and photograph changes every few days');

    return out.take(10).toList();
  }
}
