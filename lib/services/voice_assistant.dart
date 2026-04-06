import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/analysis_models.dart';

/// Voice assistant that reads out analysis results for farmers
class VoiceAssistantService {
  static final FlutterTts _tts = FlutterTts();
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5); // Slower for clarity
    await _tts.setVolume(1.0);
    
    _isInitialized = true;
  }

  /// Speak the full analysis report in farmer-friendly language
  static Future<void> speakAnalysis(CropAnalysisReport report) async {
    await initialize();
    
    final disease = report.disease.label;
    final confidence = (report.disease.confidence * 100).toStringAsFixed(0);
    final health = report.cropHealth.name.toUpperCase();
    
    String message = "Hello farmer! ";
    
    // Disease diagnosis
    if (disease == 'Healthy' || disease == 'Uncertain') {
      message += "Good news! Your crop appears to be healthy. ";
    } else {
      message += "I detected $disease with $confidence percent confidence. ";
    }
    
    // Health status
    message += "Overall crop health is $health. ";
    
    // Soil moisture
    if (report.soilMoistureSummary != null && report.soilMoistureSummary!.isNotEmpty) {
      message += "Soil condition: ${report.soilMoistureSummary}. ";
    }
    
    // Key recommendations
    if (report.recommendations.isNotEmpty) {
      message += "Here are my recommendations. ";
      
      for (var i = 0; i < report.recommendations.length && i < 3; i++) {
        final rec = report.recommendations[i];
        message += "Number ${i + 1}: $rec. ";
      }
    }
    
    // Treatment plan availability
    message += "Check the treatment plan tab for detailed step-by-step instructions.";
    
    await _tts.speak(message);
  }

  /// Quick health status announcement
  static Future<void> speakQuickStatus(CropAnalysisReport report) async {
    await initialize();
    
    final health = report.cropHealth;
    String status;
    
    switch (health) {
      case CropHealthLevel.healthy:
        status = "Your crops are looking great! Keep up the good work.";
        break;
      case CropHealthLevel.moderate:
        status = "Your crops need some attention. Please check the recommendations.";
        break;
      case CropHealthLevel.critical:
        status = "Warning! Your crops need immediate attention. Check the treatment plan now.";
        break;
    }
    
    await _tts.speak(status);
  }

  /// Stop speaking
  static Future<void> stop() async {
    await _tts.stop();
  }

  /// Check if currently speaking
  static Future<bool> isSpeaking() async {
    try {
      final state = await _tts.awaitSpeakCompletion(true) ? true : false;
      return state;
    } catch (e) {
      return false;
    }
  }
}

/// Widget for voice control button
class VoiceControlButton extends StatefulWidget {
  const VoiceControlButton({
    super.key,
    required this.report,
    this.isQuick = false,
  });

  final CropAnalysisReport report;
  final bool isQuick;

  @override
  State<VoiceControlButton> createState() => _VoiceControlButtonState();
}

class _VoiceControlButtonState extends State<VoiceControlButton> {
  bool _isSpeaking = false;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        _isSpeaking ? Icons.volume_off : Icons.volume_up,
        color: _isSpeaking ? Colors.red : null,
      ),
      tooltip: _isSpeaking ? 'Stop speaking' : 'Listen to results',
      onPressed: _toggleVoice,
    );
  }

  Future<void> _toggleVoice() async {
    if (_isSpeaking) {
      await VoiceAssistantService.stop();
      setState(() => _isSpeaking = false);
    } else {
      setState(() => _isSpeaking = true);
      
      try {
        if (widget.isQuick) {
          await VoiceAssistantService.speakQuickStatus(widget.report);
        } else {
          await VoiceAssistantService.speakAnalysis(widget.report);
        }
      } finally {
        if (mounted) {
          setState(() => _isSpeaking = false);
        }
      }
    }
  }
}
