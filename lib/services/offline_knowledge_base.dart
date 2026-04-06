import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Offline knowledge base for disease information and treatments
class OfflineKnowledgeBase {
  static const String _keyDiseases = 'offline_disease_knowledge';
  static const String _keyLastUpdate = 'knowledge_last_update';
  
  /// Initialize with comprehensive disease database
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_keyDiseases);
    
    if (existing != null) return; // Already initialized
    
    // Pre-populate with common crop diseases
    final diseases = _getDefaultDiseaseDatabase();
    await prefs.setString(_keyDiseases, jsonEncode(diseases));
    await prefs.setString(_keyLastUpdate, DateTime.now().toIso8601String());
  }
  
  /// Get disease information (works offline)
  static Future<DiseaseInfo?> getDiseaseInfo(String diseaseName) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyDiseases);
    
    if (data == null) return null;
    
    try {
      final List<dynamic> jsonList = jsonDecode(data);
      final diseases = jsonList.map((json) => DiseaseInfo.fromJson(json)).toList();
      
      // Find matching disease (case-insensitive)
      return diseases.firstWhere(
        (d) => d.name.toLowerCase().contains(diseaseName.toLowerCase()),
        orElse: () => DiseaseInfo(
          name: diseaseName,
          description: 'Information not available offline.',
          symptoms: [],
          treatment: [],
          prevention: [],
          affectedCrops: [],
        ),
      );
    } catch (e) {
      return null;
    }
  }
  
  /// Get all stored diseases
  static Future<List<DiseaseInfo>> getAllDiseases() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyDiseases);
    
    if (data == null) return [];
    
    try {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList.map((json) => DiseaseInfo.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }
  
  /// Update disease database (when online)
  static Future<void> updateDatabase(List<DiseaseInfo> diseases) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDiseases, jsonEncode(diseases.map((d) => d.toJson()).toList()));
    await prefs.setString(_keyLastUpdate, DateTime.now().toIso8601String());
  }
  
  /// Check if database is outdated (>30 days)
  static Future<bool> isOutdated() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUpdate = prefs.getString(_keyLastUpdate);
    
    if (lastUpdate == null) return true;
    
    final updateDate = DateTime.parse(lastUpdate);
    final daysSinceUpdate = DateTime.now().difference(updateDate).inDays;
    
    return daysSinceUpdate > 30;
  }
  
  static List<Map<String, dynamic>> _getDefaultDiseaseDatabase() {
    return [
      {
        'name': 'Leaf Blight',
        'description': 'Fungal disease causing brown/yellow lesions on leaves',
        'symptoms': [
          'Brown or yellow spots on leaves',
          'Lesions expand and merge',
          'Leaves turn yellow and die',
          'Reduced photosynthesis',
        ],
        'treatment': [
          'Apply fungicide (Mancozeb 2.5g/L)',
          'Remove infected leaves immediately',
          'Improve air circulation',
          'Avoid overhead irrigation',
        ],
        'prevention': [
          'Use resistant varieties',
          'Crop rotation (3-year cycle)',
          'Maintain proper plant spacing',
          'Apply preventive fungicide in humid conditions',
        ],
        'affectedCrops': ['Rice', 'Wheat', 'Tomato', 'Potato'],
      },
      {
        'name': 'Powdery Mildew',
        'description': 'White powdery fungal growth on leaf surfaces',
        'symptoms': [
          'White powdery coating on leaves',
          'Yellowing beneath white patches',
          'Distorted leaf growth',
          'Premature leaf drop',
        ],
        'treatment': [
          'Apply sulfur-based fungicide',
          'Use neem oil spray (5ml/L)',
          'Increase plant spacing',
          'Remove severely infected parts',
        ],
        'prevention': [
          'Plant resistant varieties',
          'Ensure good air circulation',
          'Avoid excessive nitrogen fertilizer',
          'Apply potassium bicarbonate preventively',
        ],
        'affectedCrops': ['Grapes', 'Cucumber', 'Squash', 'Rose'],
      },
      {
        'name': 'Rust Disease',
        'description': 'Orange-brown rust-colored pustules on leaves',
        'symptoms': [
          'Orange/brown pustules on leaf undersides',
          'Yellow spots on upper leaf surface',
          'Premature leaf fall',
          'Stunted growth',
        ],
        'treatment': [
          'Apply triazole fungicide',
          'Remove infected plant debris',
          'Avoid wetting foliage',
          'Apply at first sign of infection',
        ],
        'prevention': [
          'Use certified disease-free seeds',
          'Practice crop rotation',
          'Plant resistant cultivars',
          'Monitor regularly during humid weather',
        ],
        'affectedCrops': ['Wheat', 'Coffee', 'Bean', 'Sunflower'],
      },
      {
        'name': 'Bacterial Wilt',
        'description': 'Bacterial infection causing sudden wilting',
        'symptoms': [
          'Sudden wilting of entire plant',
          'Yellowing of lower leaves',
          'Brown discoloration in stem',
          'White bacterial ooze from cut stem',
        ],
        'treatment': [
          'No effective chemical treatment',
          'Remove and destroy infected plants',
          'Soil solarization',
          'Apply copper-based bactericide',
        ],
        'prevention': [
          'Use resistant rootstocks',
          'Improve soil drainage',
          'Rotate with non-host crops',
          'Disinfect tools between plants',
        ],
        'affectedCrops': ['Tomato', 'Potato', 'Pepper', 'Eggplant'],
      },
      {
        'name': 'Anthracnose',
        'description': 'Fungal disease causing sunken lesions on fruits and leaves',
        'symptoms': [
          'Dark sunken lesions on fruits',
          'Brown spots on leaves',
          'Pink spore masses in center',
          'Fruit rot and premature drop',
        ],
        'treatment': [
          'Apply chlorothalonil fungicide',
          'Remove infected fruits/leaves',
          'Improve air circulation',
          'Harvest fruits early to avoid infection',
        ],
        'prevention': [
          'Use disease-free seeds',
          'Mulch to prevent soil splash',
          'Avoid working when plants are wet',
          'Apply copper fungicide preventively',
        ],
        'affectedCrops': ['Mango', 'Avocado', 'Bean', 'Strawberry'],
      },
    ];
  }
}

class DiseaseInfo {
  const DiseaseInfo({
    required this.name,
    required this.description,
    required this.symptoms,
    required this.treatment,
    required this.prevention,
    required this.affectedCrops,
  });

  final String name;
  final String description;
  final List<String> symptoms;
  final List<String> treatment;
  final List<String> prevention;
  final List<String> affectedCrops;
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'symptoms': symptoms,
    'treatment': treatment,
    'prevention': prevention,
    'affectedCrops': affectedCrops,
  };
  
  factory DiseaseInfo.fromJson(Map<String, dynamic> json) {
    return DiseaseInfo(
      name: json['name'] as String,
      description: json['description'] as String,
      symptoms: List<String>.from(json['symptoms']),
      treatment: List<String>.from(json['treatment']),
      prevention: List<String>.from(json['prevention']),
      affectedCrops: List<String>.from(json['affectedCrops']),
    );
  }
}
