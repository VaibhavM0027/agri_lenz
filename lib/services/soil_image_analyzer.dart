import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Heuristic **appearance** of soil moisture from a soil photo (not a lab measurement).
/// Dark, low-luminance soil with moderate saturation often correlates with wetter samples;
/// bright, low-texture tan/gray patches correlate with dryness (lighting-dependent).
abstract final class SoilImageAnalyzer {
  const SoilImageAnalyzer._();

  /// Returns `null` if bytes missing or decode fails. Otherwise **0 = dry-looking**, **1 = wet-looking**.
  static double? moistureAppearanceScore(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) return null;
    
    try {
      var decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      
      // Resize large images to prevent memory issues (max 1024px)
      if (decoded.width > 1024 || decoded.height > 1024) {
        final scale = 1024 / math.max(decoded.width, decoded.height);
        final newWidth = (decoded.width * scale).round();
        final newHeight = (decoded.height * scale).round();
        decoded = img.copyResize(
          decoded,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.average,
        );
      }
      
      final w0 = decoded.width;
      final h0 = decoded.height;
      if (w0 < 8 || h0 < 8) return null;

    final s = img.copyResize(decoded, width: 200, interpolation: img.Interpolation.average);
    final w = s.width;
    final h = s.height;
    final x0 = (w * 0.15).round();
    final y0 = (h * 0.15).round();
    final x1 = (w * 0.85).round();
    final y1 = (h * 0.85).round();

    double lum(num r, num g, num b) => 0.299 * r + 0.587 * g + 0.114 * b;

    var n = 0;
    var sumL = 0.0;
    var sumEdge = 0.0;
    var edgeCount = 0;
    var tanDry = 0;

    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        final p = s.getPixel(x, y);
        final r = p.r.toInt();
        final g = p.g.toInt();
        final b = p.b.toInt();
        final l = lum(r, g, b) / 255.0;
        final mx = math.max(r, math.max(g, b));
        final mn = math.min(r, math.min(g, b));
        final sat = mx == 0 ? 0.0 : (mx - mn) / mx;

        n++;
        sumL += l;

        // Light tan / gray “dusty” soil — dryness cue (not green vegetation).
        if (l > 0.62 && sat < 0.38 && g < r + 25) tanDry++;

        if (x > x0 && y > y0) {
          final q = s.getPixel(x - 1, y);
          sumEdge += (p.r - q.r).abs() + (p.g - q.g).abs() + (p.b - q.b).abs();
          edgeCount++;
        }
      }
    }
    if (n == 0) return null;

    final meanL = sumL / n;
    final dryBias = tanDry / n;
    final texture = edgeCount == 0 ? 0.0 : (sumEdge / edgeCount) / 255.0;

    // Lower luminance → more likely moist/dark soil; high dryBias → light dry appearance.
    var score = 1.0 - meanL;
    score -= dryBias * 0.38;
    // Fine cracks / rough surface — slight dryness cue.
    score -= (texture.clamp(0.0, 0.45) - 0.12) * 0.15;

    return score.clamp(0.0, 1.0);
    } catch (e) {
      print('Warning: Soil image analysis failed: $e');
      return null;
    }
  }
}
