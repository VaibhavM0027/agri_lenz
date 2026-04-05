import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Lighting normalization + letterbox helpers to improve robustness and TFLite geometry.
class ImagePreprocess {
  const ImagePreprocess._();

  /// Perceptual luminance stretch (5th–95th percentile) to reduce under/over exposure bias.
  static Uint8List normalizeIlluminationBytes(Uint8List raw) {
    final im = img.decodeImage(raw);
    if (im == null) return raw;
    final out = normalizeIllumination(im);
    return Uint8List.fromList(img.encodeJpg(out, quality: 90));
  }

  static img.Image normalizeIllumination(img.Image src) {
    final w = src.width;
    final h = src.height;
    if (w == 0 || h == 0) return src;

    final lumSamples = <int>[];
    for (var y = 0; y < h; y += 2) {
      for (var x = 0; x < w; x += 2) {
        final p = src.getPixel(x, y);
        final l = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round().clamp(0, 255);
        lumSamples.add(l);
      }
    }
    lumSamples.sort();
    if (lumSamples.isEmpty) return src;

    final i5 = (lumSamples.length * 0.05).floor().clamp(0, lumSamples.length - 1);
    final i95 = (lumSamples.length * 0.95).floor().clamp(0, lumSamples.length - 1);
    var lo = lumSamples[i5].toDouble();
    var hi = lumSamples[i95].toDouble();
    if (hi - lo < 24) {
      lo = math.max(0, lo - 20);
      hi = math.min(255, hi + 20);
    }
    final range = (hi - lo).clamp(1.0, 255.0);

    final copy = img.Image.from(src);
    for (final px in copy) {
      final l = 0.299 * px.r + 0.587 * px.g + 0.114 * px.b;
      final f = ((l - lo) / range * 255).clamp(0.0, 255.0);
      final gain = l <= 0 ? 1.0 : f / l;
      px
        ..r = (px.r * gain).clamp(0, 255)
        ..g = (px.g * gain).clamp(0, 255)
        ..b = (px.b * gain).clamp(0, 255);
    }
    return copy;
  }

  /// Aspect-preserving fit into [tw]×[th] with padding (reduces stretch distortion for CNNs).
  static img.Image letterboxRgb(img.Image src, int tw, int th) {
    final scale = math.min(tw / src.width, th / src.height);
    final nw = math.max(1, (src.width * scale).round());
    final nh = math.max(1, (src.height * scale).round());
    final rs = img.copyResize(src, width: nw, height: nh, interpolation: img.Interpolation.linear);
    final canvas = img.Image(width: tw, height: th, numChannels: src.numChannels);
    const padR = 18;
    const padG = 48;
    const padB = 22;
    img.fill(canvas, color: img.ColorRgb8(padR, padG, padB));
    final ox = (tw - nw) ~/ 2;
    final oy = (th - nh) ~/ 2;
    img.compositeImage(canvas, rs, dstX: ox, dstY: oy);
    return canvas;
  }
}
