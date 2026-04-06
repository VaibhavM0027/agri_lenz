/// Curated remedy hints (IPM-style), similar in spirit to disease + remedy flows in
/// community apps like [Plants-disease-detection](https://github.com/anotherwebguy/Plants-disease-detection).
/// Always follow local labels and extension advice for your crop.
abstract final class DiseaseRemedies {
  const DiseaseRemedies._();

  static List<String> forLabel(String label) {
    switch (label) {
      case 'Healthy':
        return const [
          '✅ Excellent! Your crop looks healthy — maintain current practices.',
          '📊 Continue regular monitoring every 3-4 days to catch early signs.',
          '💧 Ensure consistent watering schedule based on soil moisture levels.',
          '🌱 Apply balanced fertilizer every 2-3 weeks during growing season.',
          '🔍 Scout field edges first — pests often start there.',
        ];
      case 'Leaf Blight':
        return const [
          '🚨 IMMEDIATE ACTION: Remove and destroy infected leaves (burn or bury 30cm deep).',
          '💊 Apply fungicide within 24-48 hours: Use strobilurin (Azoxystrobin) or SDHI-based products.',
          '⏰ Reapply fungicide every 7-10 days until symptoms stop spreading.',
          '🌿 Cultural Control: Increase plant spacing by 15-20% for better air circulation.',
          '💧 Switch to drip irrigation — avoid wetting foliage, especially in evenings.',
          '🧼 Sanitize all tools with 10% bleach solution between plants.',
          '📅 Prevention: Start preventive sprays 2 weeks before typical blight season.',
          '🔄 Rotate crops next season — avoid planting same family in affected area for 2 years.',
        ];
      case 'Powdery Mildew':
        return const [
          '🚨 IMMEDIATE: Prune heavily infected areas; improve airflow immediately.',
          '💊 Organic Treatment: Mix 1 tbsp baking soda + 1 tsp liquid soap per liter of water. Spray weekly.',
          '💊 Chemical Option: Apply sulfur-based fungicide or potassium bicarbonate (follow label rates).',
          '🌡️ Environmental Fix: Reduce humidity below 70% — space plants wider.',
          '💧 Water at soil level only; never overhead irrigate infected plants.',
          '☀️ Maximize sunlight exposure — trim surrounding vegetation blocking light.',
          '🛡️ Resistant Varieties: Consider mildew-resistant cultivars for next planting.',
          '📊 Monitor daily — powdery mildew spreads rapidly in warm, humid conditions.',
        ];
      case 'Rust':
        return const [
          '🚨 CRITICAL: Rust spreads via wind-borne spores — act within 24 hours!',
          '💊 Fungicide Program: Apply triazole-based fungicide (e.g., Propiconazole) immediately.',
          '⏰ Repeat application every 10-14 days; rotate fungicide classes to prevent resistance.',
          '🗑️ Destroy all fallen leaves and debris — they harbor overwintering spores.',
          '🚫 Do NOT work in fields when plants are wet — this spreads spores.',
          '🌾 Crop Rotation: Avoid susceptible hosts in same field for 2-3 years.',
          '🌬️ Improve air movement: Thin dense canopies, orient rows with prevailing winds.',
          '🔔 Early Warning: Watch for small orange/yellow pustules on leaf undersides.',
        ];
      case 'Leaf Spot':
        return const [
          '🚨 Early Intervention: Begin treatment at first sign — spots multiply quickly.',
          '💊 Copper-Based Spray: Apply copper hydroxide or chlorothalonil (per crop label).',
          '⏰ Spray interval: Every 7 days during wet weather, 10-14 days when dry.',
          '🌱 Mulching: Apply 5-8cm organic mulch to prevent soil splash onto leaves.',
          '💧 Drainage: Fix waterlogged areas — fungal spores thrive in standing water.',
          '✂️ Remove lower leaves touching soil — common entry point for pathogens.',
          '🌦️ Weather Watch: Increase scouting after rain events or heavy dew.',
          '🔄 Sanitation: Clean greenhouse structures between seasons with disinfectant.',
        ];
      case 'Pest Damage':
        return const [
          '🔍 IDENTIFY FIRST: Check leaf undersides with magnifying glass — note pest type.',
          '🐛 Caterpillars/Worms: Hand-pick if few; use Bt (Bacillus thuringiensis) spray for larger infestations.',
          '🕷️ Mites/Aphids: Spray neem oil (2%) or insecticidal soap; repeat every 5-7 days.',
          '🪲 Beetles: Install pheromone traps; apply spinosad-based insecticide if severe.',
          '🌿 Biological Control: Release ladybugs (aphids) or predatory mites (spider mites).',
          '🛡️ Physical Barrier: Use floating row covers on young plants.',
          '🔄 IPM Strategy: Rotate 2-3 different insecticide modes of action to prevent resistance.',
          '📊 Trap Monitoring: Place yellow sticky cards — check twice weekly for flying pests.',
          '🗑️ Destroy heavily damaged leaves away from field to reduce egg populations.',
        ];
      default:
        return const [
          '⚠️ Uncertain diagnosis — take 2-3 more photos from different angles.',
          '📞 Consult local agricultural extension officer for on-site verification.',
          '🔬 Send sample to plant pathology lab if symptoms persist or worsen.',
          '📸 Document progression: Photograph same leaf every 2 days to track changes.',
        ];
    }
  }
}
