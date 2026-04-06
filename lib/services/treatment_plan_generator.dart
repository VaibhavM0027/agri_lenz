import '../models/analysis_models.dart';

/// Generates a structured treatment timeline based on disease diagnosis and severity.
class TreatmentPlanGenerator {
  const TreatmentPlanGenerator._();

  static TreatmentPlan generate({
    required DiseasePrediction disease,
    required CropHealthLevel health,
    required PestRiskLevel pest,
    required LeafVisualFeatures visual,
  }) {
    final phases = <TreatmentPhase>[];

    // Phase 1: Immediate Actions (0-48 hours)
    phases.add(_generateImmediateActions(disease, health, pest));

    // Phase 2: Short-term Treatment (3-7 days)
    phases.add(_generateShortTermTreatment(disease, health, visual));

    // Phase 3: Monitoring & Adjustment (1-2 weeks)
    phases.add(_generateMonitoringPhase(disease, health));

    // Phase 4: Long-term Prevention (2+ weeks)
    phases.add(_generatePreventionPhase(disease, health));

    return TreatmentPlan(
      disease: disease.label,
      severity: health,
      phases: phases,
      estimatedRecoveryDays: _estimateRecoveryDays(disease, health),
      successRate: _calculateSuccessRate(disease, health, pest),
    );
  }

  static TreatmentPhase _generateImmediateActions(
    DiseasePrediction disease,
    CropHealthLevel health,
    PestRiskLevel pest,
  ) {
    final tasks = <TreatmentTask>[];

    if (health == CropHealthLevel.critical) {
      tasks.add(const TreatmentTask(
        title: 'Isolate affected plants',
        description: 'Move or mark infected plants to prevent spread to healthy crops',
        priority: TaskPriority.critical,
        dayOffset: 0,
      ));
    }

    // DISEASE-SPECIFIC immediate actions
    switch (disease.label) {
      case 'Leaf Blight':
        tasks.add(const TreatmentTask(
          title: 'Remove infected leaves immediately',
          description: 'Cut off diseased foliage with sterilized shears. Dispose by burning or burying 30cm deep.',
          priority: TaskPriority.critical,
          dayOffset: 0,
        ));
        tasks.add(const TreatmentTask(
          title: 'Apply strobilurin fungicide',
          description: 'Use Azoxystrobin or similar strobilurin-based spray within 24 hours',
          priority: TaskPriority.critical,
          dayOffset: 0,
        ));
        tasks.add(const TreatmentTask(
          title: 'Sanitize all tools',
          description: 'Clean pruning shears with 10% bleach solution between each plant',
          priority: TaskPriority.high,
          dayOffset: 0,
        ));
        break;

      case 'Rust':
        tasks.add(const TreatmentTask(
          title: 'Destroy all fallen debris',
          description: 'Collect and burn all leaf litter around plants - rust spores overwinter here',
          priority: TaskPriority.critical,
          dayOffset: 0,
        ));
        tasks.add(const TreatmentTask(
          title: 'Apply triazole fungicide NOW',
          description: 'Spray Propiconazole or Tebuconazole immediately - rust spreads via wind in 24hrs',
          priority: TaskPriority.critical,
          dayOffset: 0,
        ));
        tasks.add(const TreatmentTask(
          title: 'Stop overhead watering',
          description: 'Switch to drip irrigation - wet foliage accelerates rust spread',
          priority: TaskPriority.high,
          dayOffset: 0,
        ));
        break;

      case 'Powdery Mildew':
        tasks.add(const TreatmentTask(
          title: 'Prune for air circulation',
          description: 'Remove dense growth and lower leaves to improve airflow immediately',
          priority: TaskPriority.high,
          dayOffset: 0,
        ));
        tasks.add(const TreatmentTask(
          title: 'Apply baking soda solution',
          description: 'Mix 1 tbsp baking soda + 1 tsp liquid soap per liter water. Spray thoroughly.',
          priority: TaskPriority.high,
          dayOffset: 0,
        ));
        tasks.add(const TreatmentTask(
          title: 'Reduce humidity',
          description: 'Space plants wider, remove surrounding vegetation blocking air movement',
          priority: TaskPriority.medium,
          dayOffset: 0,
        ));
        break;

      case 'Leaf Spot':
        tasks.add(const TreatmentTask(
          title: 'Remove spotted leaves',
          description: 'Cut off leaves with visible spots. Do NOT compost - destroy away from field.',
          priority: TaskPriority.high,
          dayOffset: 0,
        ));
        tasks.add(const TreatmentTask(
          title: 'Apply copper-based fungicide',
          description: 'Use copper hydroxide or chlorothalonil spray according to crop label rates',
          priority: TaskPriority.high,
          dayOffset: 0,
        ));
        tasks.add(const TreatmentTask(
          title: 'Apply mulch barrier',
          description: 'Add 5-8cm organic mulch to prevent soil splash carrying spores onto leaves',
          priority: TaskPriority.medium,
          dayOffset: 0,
        ));
        break;

      case 'Pest Damage':
        tasks.add(const TreatmentTask(
          title: 'Identify the pest species',
          description: 'Check leaf undersides with magnifying glass. Note: caterpillars, aphids, mites, or beetles?',
          priority: TaskPriority.critical,
          dayOffset: 0,
        ));
        if (pest == PestRiskLevel.high) {
          tasks.add(const TreatmentTask(
            title: 'Apply targeted insecticide',
            description: 'Use neem oil (2%) for soft-bodied pests or spinosad for caterpillars/beetles',
            priority: TaskPriority.critical,
            dayOffset: 0,
          ));
        } else {
          tasks.add(const TreatmentTask(
            title: 'Hand-pick visible pests',
            description: 'Remove caterpillars and beetles manually if infestation is light',
            priority: TaskPriority.medium,
            dayOffset: 0,
          ));
        }
        tasks.add(const TreatmentTask(
          title: 'Install sticky traps',
          description: 'Place yellow sticky cards near plants to monitor flying pest populations',
          priority: TaskPriority.medium,
          dayOffset: 0,
        ));
        break;

      case 'Healthy':
        tasks.add(const TreatmentTask(
          title: 'Continue regular monitoring',
          description: 'No treatment needed! Keep scouting every 3-4 days to catch issues early',
          priority: TaskPriority.low,
          dayOffset: 0,
        ));
        tasks.add(const TreatmentTask(
          title: 'Maintain current practices',
          description: 'Your crop management is working well - keep up the good work!',
          priority: TaskPriority.low,
          dayOffset: 0,
        ));
        break;

      default:
        tasks.add(const TreatmentTask(
          title: 'Take additional photos',
          description: 'Capture 2-3 more images from different angles for better diagnosis',
          priority: TaskPriority.medium,
          dayOffset: 0,
        ));
        tasks.add(const TreatmentTask(
          title: 'Consult local expert',
          description: 'Contact agricultural extension officer for on-site verification',
          priority: TaskPriority.medium,
          dayOffset: 0,
        ));
    }

    return TreatmentPhase(
      name: 'Immediate Actions',
      timeframe: '0-48 hours',
      tasks: tasks,
      icon: '🚨',
    );
  }

  static TreatmentPhase _generateShortTermTreatment(
    DiseasePrediction disease,
    CropHealthLevel health,
    LeafVisualFeatures visual,
  ) {
    final tasks = <TreatmentTask>[];

    // DISEASE-SPECIFIC short-term treatments
    switch (disease.label) {
      case 'Leaf Blight':
        tasks.add(const TreatmentTask(
          title: 'Second fungicide application',
          description: 'Reapply strobilurin or SDHI fungicide (7-10 day interval from first spray)',
          priority: TaskPriority.high,
          dayOffset: 3,
        ));
        tasks.add(const TreatmentTask(
          title: 'Check for new lesions',
          description: 'Inspect all plants - if spreading, consider switching to multi-site fungicide',
          priority: TaskPriority.high,
          dayOffset: 5,
        ));
        break;

      case 'Rust':
        tasks.add(const TreatmentTask(
          title: 'Repeat triazole fungicide',
          description: 'Second application of Propiconazole (10-14 day interval). Rotate chemistry if possible.',
          priority: TaskPriority.high,
          dayOffset: 3,
        ));
        tasks.add(const TreatmentTask(
          title: 'Monitor surrounding fields',
          description: 'Check neighboring crops for rust pustules - wind can carry spores long distances',
          priority: TaskPriority.medium,
          dayOffset: 5,
        ));
        break;

      case 'Powdery Mildew':
        tasks.add(const TreatmentTask(
          title: 'Weekly baking soda spray',
          description: 'Reapply baking soda solution. For severe cases, add sulfur-based fungicide.',
          priority: TaskPriority.high,
          dayOffset: 3,
        ));
        tasks.add(const TreatmentTask(
          title: 'Assess humidity levels',
          description: 'If still humid, increase plant spacing further or add fans in greenhouse',
          priority: TaskPriority.medium,
          dayOffset: 5,
        ));
        break;

      case 'Leaf Spot':
        tasks.add(const TreatmentTask(
          title: 'Second copper fungicide spray',
          description: 'Reapply copper hydroxide (7-day interval in wet weather, 10-14 days if dry)',
          priority: TaskPriority.high,
          dayOffset: 3,
        ));
        tasks.add(const TreatmentTask(
          title: 'Improve drainage',
          description: 'Fix waterlogged areas - fungal spores thrive in standing water around roots',
          priority: TaskPriority.medium,
          dayOffset: 5,
        ));
        break;

      case 'Pest Damage':
        tasks.add(const TreatmentTask(
          title: 'Second insecticide application',
          description: 'Reapply neem oil or spinosad (5-7 day interval). Check for pest resistance.',
          priority: TaskPriority.high,
          dayOffset: 3,
        ));
        tasks.add(const TreatmentTask(
          title: 'Release beneficial insects',
          description: 'Introduce ladybugs (for aphids) or predatory mites (for spider mites) if available',
          priority: TaskPriority.medium,
          dayOffset: 5,
        ));
        break;

      case 'Healthy':
        tasks.add(const TreatmentTask(
          title: 'Apply balanced fertilizer',
          description: 'Use NPK fertilizer according to crop stage to maintain healthy growth',
          priority: TaskPriority.low,
          dayOffset: 4,
        ));
        tasks.add(const TreatmentTask(
          title: 'Scout field edges',
          description: 'Check perimeter plants first - pests and diseases often start at field borders',
          priority: TaskPriority.low,
          dayOffset: 5,
        ));
        break;

      default:
        tasks.add(TreatmentTask(
          title: 'Second treatment application',
          description: 'Reapply fungicide/insecticide as per product label instructions',
          priority: TaskPriority.high,
          dayOffset: 3,
        ));
        tasks.add(const TreatmentTask(
          title: 'Assess treatment effectiveness',
          description: 'Check if symptoms are spreading or stabilizing',
          priority: TaskPriority.medium,
          dayOffset: 5,
        ));
    }

    // Nutrient support for recovery (all diseases)
    if (disease.label != 'Healthy' && (visual.yellowRatio > 0.12 || visual.paleRatio > 0.18)) {
      tasks.add(const TreatmentTask(
        title: 'Apply foliar fertilizer',
        description: 'Use nitrogen-rich foliar feed to boost plant recovery and new growth',
        priority: TaskPriority.medium,
        dayOffset: 4,
      ));
    }

    return TreatmentPhase(
      name: 'Short-term Treatment',
      timeframe: '3-7 days',
      tasks: tasks,
      icon: '💊',
    );
  }

  static TreatmentPhase _generateMonitoringPhase(
    DiseasePrediction disease,
    CropHealthLevel health,
  ) {
    final tasks = <TreatmentTask>[];

    tasks.add(const TreatmentTask(
      title: 'Photograph progress',
      description: 'Take photos of same leaves to track improvement or worsening',
      priority: TaskPriority.medium,
      dayOffset: 7,
    ));

    // DISEASE-SPECIFIC monitoring
    if (disease.label != 'Healthy') {
      tasks.add(const TreatmentTask(
        title: 'Scout surrounding plants',
        description: 'Check nearby plants for early signs of disease spread',
        priority: TaskPriority.high,
        dayOffset: 8,
      ));

      switch (disease.label) {
        case 'Leaf Blight':
          tasks.add(const TreatmentTask(
            title: 'Assess fungicide effectiveness',
            description: 'If lesions still spreading after 10 days, switch to different fungicide class',
            priority: TaskPriority.medium,
            dayOffset: 10,
          ));
          break;
        case 'Rust':
          tasks.add(const TreatmentTask(
            title: 'Check for orange pustules',
            description: 'Inspect leaf undersides - if new rust spots appear, reapply triazole fungicide',
            priority: TaskPriority.high,
            dayOffset: 10,
          ));
          break;
        case 'Powdery Mildew':
          tasks.add(const TreatmentTask(
            title: 'Monitor white powder growth',
            description: 'If white coating persists, add sulfur fungicide to baking soda spray rotation',
            priority: TaskPriority.medium,
            dayOffset: 10,
          ));
          break;
        case 'Leaf Spot':
          tasks.add(const TreatmentTask(
            title: 'Count new spots',
            description: 'If spot count increasing, improve drainage and increase copper spray frequency',
            priority: TaskPriority.medium,
            dayOffset: 10,
          ));
          break;
        case 'Pest Damage':
          tasks.add(const TreatmentTask(
            title: 'Check pest population',
            description: 'If pests still active, rotate to different insecticide mode of action',
            priority: TaskPriority.high,
            dayOffset: 10,
          ));
          break;
      }
    }

    return TreatmentPhase(
      name: 'Monitoring & Adjustment',
      timeframe: '1-2 weeks',
      tasks: tasks,
      icon: '📊',
    );
  }

  static TreatmentPhase _generatePreventionPhase(
    DiseasePrediction disease,
    CropHealthLevel health,
  ) {
    final tasks = <TreatmentTask>[];

    tasks.add(const TreatmentTask(
      title: 'Improve field sanitation',
      description: 'Remove plant debris and weeds that harbor pathogens',
      priority: TaskPriority.medium,
      dayOffset: 14,
    ));

    if (disease.label != 'Healthy') {
      tasks.add(const TreatmentTask(
        title: 'Plan crop rotation',
        description: 'Avoid planting same crop family in this area next season',
        priority: TaskPriority.low,
        dayOffset: 21,
      ));

      tasks.add(const TreatmentTask(
        title: 'Soil testing',
        description: 'Test soil nutrients and pH for optimal growing conditions',
        priority: TaskPriority.medium,
        dayOffset: 15,
      ));
    }

    tasks.add(const TreatmentTask(
      title: 'Set up monitoring traps',
      description: 'Install yellow sticky cards for early pest detection',
      priority: TaskPriority.low,
      dayOffset: 14,
    ));

    return TreatmentPhase(
      name: 'Long-term Prevention',
      timeframe: '2+ weeks',
      tasks: tasks,
      icon: '🛡️',
    );
  }

  static int _estimateRecoveryDays(DiseasePrediction disease, CropHealthLevel health) {
    if (disease.label == 'Healthy') return 0;

    var baseDays = switch (disease.label) {
      'Leaf Blight' => 14,
      'Powdery Mildew' => 10,
      'Rust' => 18,
      'Leaf Spot' => 12,
      'Pest Damage' => 7,
      _ => 10,
    };

    // Adjust based on severity
    if (health == CropHealthLevel.critical) {
      baseDays = (baseDays * 1.5).round();
    } else if (health == CropHealthLevel.moderate) {
      baseDays = (baseDays * 1.2).round();
    }

    return baseDays;
  }

  static double _calculateSuccessRate(
    DiseasePrediction disease,
    CropHealthLevel health,
    PestRiskLevel pest,
  ) {
    if (disease.label == 'Healthy') return 100.0;

    var rate = switch (disease.label) {
      'Leaf Blight' => 85.0,
      'Powdery Mildew' => 90.0,
      'Rust' => 80.0,
      'Leaf Spot' => 88.0,
      'Pest Damage' => 92.0,
      _ => 75.0,
    };

    // Reduce success rate for critical cases
    if (health == CropHealthLevel.critical) {
      rate -= 10.0;
    }

    // High pest pressure reduces success
    if (pest == PestRiskLevel.high) {
      rate -= 5.0;
    }

    return rate.clamp(60.0, 98.0);
  }
}

class TreatmentPlan {
  const TreatmentPlan({
    required this.disease,
    required this.severity,
    required this.phases,
    required this.estimatedRecoveryDays,
    required this.successRate,
  });

  final String disease;
  final CropHealthLevel severity;
  final List<TreatmentPhase> phases;
  final int estimatedRecoveryDays;
  final double successRate;

  String get severityLabel {
    return switch (severity) {
      CropHealthLevel.healthy => 'Healthy - Maintenance Mode',
      CropHealthLevel.moderate => 'Moderate - Active Treatment',
      CropHealthLevel.critical => 'Critical - Intensive Care',
    };
  }
}

class TreatmentPhase {
  const TreatmentPhase({
    required this.name,
    required this.timeframe,
    required this.tasks,
    required this.icon,
  });

  final String name;
  final String timeframe;
  final List<TreatmentTask> tasks;
  final String icon;
}

class TreatmentTask {
  const TreatmentTask({
    required this.title,
    required this.description,
    required this.priority,
    required this.dayOffset,
  });

  final String title;
  final String description;
  final TaskPriority priority;
  final int dayOffset;

  String get priorityEmoji {
    return switch (priority) {
      TaskPriority.critical => '🔴',
      TaskPriority.high => '🟠',
      TaskPriority.medium => '🟡',
      TaskPriority.low => '🟢',
    };
  }
}

enum TaskPriority { critical, high, medium, low }
