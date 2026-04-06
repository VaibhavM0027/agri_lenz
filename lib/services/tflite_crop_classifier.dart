import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/analysis_models.dart';
import '../models/cnn_label_map.dart';
import 'cnn_input_preprocess.dart';

bool _bufferLooksLikeTflite(ByteData data) {
  final u = data.buffer.asUint8List();
  if (u.length < 16) return false;
  for (var i = 0; i < u.length - 4; i++) {
    if (u[i] == 0x54 && u[i + 1] == 0x46 && u[i + 2] == 0x4c && u[i + 3] == 0x33) {
      return true;
    }
  }
  return false;
}

/// TensorFlow Lite runner aligned with **MobileNetV2 / EfficientNet-Lite** style inputs:
/// letterbox resize to **H×W** (typically **224×224**), **RGB**, **[0,1] float32** or **uint8**.
///
/// Output index `i` ↔ `labels[i]` (must match [CnnLabelMap.canonicalLabels]).
class TfliteCropClassifier {
  TfliteCropClassifier(this._interpreter, this._labels);

  final Interpreter _interpreter;
  final List<String> _labels;

  static Future<TfliteCropClassifier?> tryLoad(List<String> labels) async {
    if (!CnnLabelMap.validateAgainstFile(labels)) {
      debugPrint(
        'agri_lenz: TFLite not loaded — labels.txt must match CnnLabelMap.canonicalLabels order.\n'
        '${CnnLabelMap.indexLegend()}',
      );
      return null;
    }
    try {
      final data = await rootBundle.load('assets/models/crop_model.tflite');
      if (!_bufferLooksLikeTflite(data)) return null;

      final options = InterpreterOptions()..threads = 4;
      final interpreter = Interpreter.fromBuffer(
        data.buffer.asUint8List(),
        options: options,
      );
      return TfliteCropClassifier(interpreter, labels);
    } catch (e) {
      debugPrint('agri_lenz: TFLite load failed: $e');
      return null;
    }
  }

  void dispose() => _interpreter.close();

  /// Raw CNN prediction (no confidence gate). Apply [TflitePostProcess.applyConfidenceGate] in the pipeline.
  DiseasePrediction? classify(Uint8List imageBytes) {
    try {
      final inputTensor = _interpreter.getInputTensor(0);
      final outputTensor = _interpreter.getOutputTensor(0);
      final inShape = inputTensor.shape;
      final outShape = outputTensor.shape;
      final outLen = outShape.fold<int>(1, (a, b) => a * b);
      if (outLen != _labels.length) return null;

      var decoded = img.decodeImage(imageBytes);
      if (decoded == null) return null;
      
      // Resize large images to prevent memory issues with TFLite (max 1024px)
      if (decoded.width > 1024 || decoded.height > 1024) {
        final scale = 1024 / math.max(decoded.width, decoded.height);
        final newWidth = (decoded.width * scale).round();
        final newHeight = (decoded.height * scale).round();
        decoded = img.copyResize(
          decoded,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.linear,
        );
      }

    final inputType = inputTensor.type;
    final Object input;
    try {
      switch (inputType) {
        case TensorType.float32:
          input = CnnInputPreprocess.buildInputTensor(
            decoded: decoded,
            inShape: inShape,
            useFloat32: true,
          );
        case TensorType.uint8:
        case TensorType.int8:
          input = CnnInputPreprocess.buildInputTensor(
            decoded: decoded,
            inShape: inShape,
            useFloat32: false,
          );
        default:
          return null;
      }
    } catch (e, st) {
      debugPrint('agri_lenz: CNN input build failed: $e\n$st');
      return null;
    }

    final output = switch (outputTensor.type) {
      TensorType.float32 => List<double>.filled(outLen, 0),
      TensorType.uint8 || TensorType.int8 => List<int>.filled(outLen, 0),
      _ => null,
    };
    if (output == null) return null;

    _interpreter.run(input, output);

    final List<double> probs;
    if (output is List<double>) {
      probs = _toProbabilities(output);
    } else if (output is List<int>) {
      final raw = output.map((e) => (e / 255.0).clamp(0.0, 1.0)).toList();
      final s = raw.fold<double>(0, (a, b) => a + b);
      probs = s > 0 ? raw.map((e) => e / s).toList() : List.filled(outLen, 1.0 / outLen);
    } else {
      return null;
    }

    var bestI = 0;
    var bestV = probs[0];
    for (var i = 1; i < probs.length; i++) {
      if (probs[i] > bestV) {
        bestV = probs[i];
        bestI = i;
      }
    }

    final map = <String, double>{for (var i = 0; i < _labels.length; i++) _labels[i]: probs[i]};
    return DiseasePrediction(
      label: _labels[bestI],
      confidence: bestV.clamp(0.0, 1.0),
      allScores: map,
    );
    } catch (e) {
      print('Warning: TFLite classification failed: $e');
      return null;
    }
  }

  /// Treat as logits (softmax) unless values already look like a probability simplex.
  static List<double> _toProbabilities(List<double> xs) {
    final s = xs.fold<double>(0, (a, b) => a + b);
    final inSimplex = xs.every((e) => e >= -0.05 && e <= 1.05) && (s - 1.0).abs() < 0.03;
    if (inSimplex) {
      return xs.map((e) => e.clamp(0.0, 1.0)).toList();
    }
    return _softmax(xs);
  }

  static List<double> _softmax(List<double> xs) {
    final m = xs.reduce(math.max);
    var sum = 0.0;
    final exps = <double>[];
    for (final x in xs) {
      final e = math.exp((x - m).clamp(-40.0, 40.0));
      exps.add(e);
      sum += e;
    }
    if (sum <= 0) return List.filled(xs.length, 1.0 / xs.length);
    return exps.map((e) => e / sum).toList();
  }
}
