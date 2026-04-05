import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../models/cnn_label_map.dart';
import 'image_preprocess.dart';

/// MobileNetV2 / EfficientNet-style input: **RGB**, values in **[0, 1]**, spatial **224×224**
/// (or model tensor H×W), **NHWC** `[1, H, W, 3]` or **NCHW** `[1, 3, H, W]`.
abstract final class CnnInputPreprocess {
  /// Letterbox (aspect-preserving) then fill float32 **R, G, B** in [0, 1].
  static Object buildInputTensor({
    required img.Image decoded,
    required List<int> inShape,
    required bool useFloat32,
  }) {
    if (inShape.length != 4) {
      throw ArgumentError('Expected 4D input, got $inShape');
    }

    final n = inShape[0];
    if (n != 1) {
      throw ArgumentError('Only batch size 1 supported, got $inShape');
    }

    // NHWC [1, H, W, 3]
    if (inShape[3] == 3) {
      final h = inShape[1];
      final w = inShape[2];
      final boxed = ImagePreprocess.letterboxRgb(decoded, w, h);
      return _nhwcBatch(boxed, h, w, useFloat32);
    }

    // NCHW [1, 3, H, W]
    if (inShape[1] == 3) {
      final h = inShape[2];
      final w = inShape[3];
      final boxed = ImagePreprocess.letterboxRgb(decoded, w, h);
      return _nchwBatch(boxed, h, w, useFloat32);
    }

    throw ArgumentError('Unsupported input layout: $inShape (need NHWC or NCHW with 3 channels)');
  }

  /// Prefer **224×224** when exporting models; other sizes are supported via tensor shape.
  static int expectedSpatialSize(List<int> inShape) {
    if (inShape.length != 4) return CnnLabelMap.inputSize;
    if (inShape[3] == 3) return math.max(inShape[1], inShape[2]);
    if (inShape[1] == 3) return math.max(inShape[2], inShape[3]);
    return CnnLabelMap.inputSize;
  }

  static List<List<List<List<num>>>> _nhwcBatch(img.Image boxed, int h, int w, bool float32) {
    return [
      List.generate(
        h,
        (y) => List.generate(
          w,
          (x) {
            final p = boxed.getPixel(x.clamp(0, boxed.width - 1), y.clamp(0, boxed.height - 1));
            final r = p.r / 255.0;
            final g = p.g / 255.0;
            final b = p.b / 255.0;
            if (float32) {
              return <double>[r, g, b];
            }
            return <int>[
              p.r.toInt().clamp(0, 255),
              p.g.toInt().clamp(0, 255),
              p.b.toInt().clamp(0, 255),
            ];
          },
        ),
      ),
    ];
  }

  /// Channel-first: index order R=0, G=1, B=2 (RGB).
  static List<List<List<List<num>>>> _nchwBatch(img.Image boxed, int h, int w, bool float32) {
    final planeR = List.generate(
      h,
      (y) => List.generate(w, (x) {
        final p = boxed.getPixel(x.clamp(0, boxed.width - 1), y.clamp(0, boxed.height - 1));
        return float32 ? p.r / 255.0 : p.r.toInt().clamp(0, 255);
      }),
    );
    final planeG = List.generate(
      h,
      (y) => List.generate(w, (x) {
        final p = boxed.getPixel(x.clamp(0, boxed.width - 1), y.clamp(0, boxed.height - 1));
        return float32 ? p.g / 255.0 : p.g.toInt().clamp(0, 255);
      }),
    );
    final planeB = List.generate(
      h,
      (y) => List.generate(w, (x) {
        final p = boxed.getPixel(x.clamp(0, boxed.width - 1), y.clamp(0, boxed.height - 1));
        return float32 ? p.b / 255.0 : p.b.toInt().clamp(0, 255);
      }),
    );
    return [[planeR, planeG, planeB]];
  }
}
