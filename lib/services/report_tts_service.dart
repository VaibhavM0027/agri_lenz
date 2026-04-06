import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';

/// Reads the text report aloud (on supported platforms).
abstract final class ReportTtsService {
  const ReportTtsService._();

  static final FlutterTts _tts = FlutterTts();

  static Future<void> speakReport(String plainText) async {
    if (kIsWeb) return;
    await _tts.stop();
    await _tts.setSpeechRate(0.42);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _tts.speak(plainText);
  }

  static Future<void> stop() async {
    if (kIsWeb) return;
    await _tts.stop();
  }
}
