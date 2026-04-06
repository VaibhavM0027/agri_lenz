import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/analysis_models.dart';

/// Blur + exposure heuristics so users know when a retake will improve accuracy.
class PhotoQualityAnalyzer {
  const PhotoQualityAnalyzer._();

  static AnalysisQuality assess(Uint8List bytes) {
    try {
      final im = img.decodeImage(bytes);
      if (im == null) {
        return const AnalysisQuality(score: 35, hint: 'Image could not be read — try another file.');
      }

      // Resize large images to prevent memory issues (max 1024px for quality check)
      img.Image workingImage = im;
      if (im.width > 1024 || im.height > 1024) {
        final scale = 1024 / math.max(im.width, im.height);
        final newWidth = (im.width * scale).round();
        final newHeight = (im.height * scale).round();
        workingImage = img.copyResize(
          im,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.average,
        );
      }

      final small = img.copyResize(workingImage, width: math.min(320, workingImage.width), interpolation: img.Interpolation.average);
      final w = small.width;
      final h = small.height;
      if (w < 8 || h < 8) {
        return const AnalysisQuality(score: 40, hint: 'Photo resolution is very low — move closer to the leaf.');
      }

    var sumL = 0.0;
    var sumL2 = 0.0;
    var n = 0;
    var lapSum = 0.0;
    var lapN = 0;

    double lum(img.Pixel p) => 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;

    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final c = small.getPixel(x, y);
        final l = lum(c);
        sumL += l;
        sumL2 += l * l;
        n++;

        final u = lum(small.getPixel(x, y - 1));
        final d = lum(small.getPixel(x, y + 1));
        final le = lum(small.getPixel(x - 1, y));
        final r = lum(small.getPixel(x + 1, y));
        final lap = (4 * l - u - d - le - r).abs();
        lapSum += lap * lap;
        lapN++;
      }
    }

    final meanL = sumL / n;
    final varL = (sumL2 / n - meanL * meanL).clamp(0.0, 1e9);
    final lapVar = lapN == 0 ? 0.0 : lapSum / lapN;

    var sharpScore = (lapVar / 6.0).clamp(0.0, 100.0);
    if (sharpScore > 100) sharpScore = 100;

    var brightScore = 100.0;
    if (meanL < 55) brightScore = 40 + meanL;
    if (meanL > 220) brightScore = 100 - (meanL - 220) * 2;

    final combined = (sharpScore * 0.62 + brightScore * 0.28 + (varL / 2).clamp(0, 20) * 0.1).round().clamp(0, 100);

    String hint;
    if (combined >= 72) {
      hint = 'Good photo quality — suitable for reliable analysis.';
    } else if (lapVar < 120 && meanL > 45) {
      hint = 'Image looks soft or blurry — hold steady, tap to focus, and fill the frame with the leaf.';
    } else if (meanL < 55) {
      hint = 'Very dark — add light or enable flash so vein and spot details are visible.';
    } else if (meanL > 225) {
      hint = 'Very bright — reduce glare; shaded diffuse light shows damage patterns better.';
    } else {
      hint = 'Acceptable — for best accuracy, use sharp focus and even lighting.';
    }

    return AnalysisQuality(score: combined, hint: hint);
    } catch (e) {
      print('Warning: Photo quality assessment failed: $e');
      return const AnalysisQuality(score: 50, hint: 'Could not fully assess photo quality — proceeding with analysis.');
    }
  }
}

class ClassUncertaintyAnalyzer {
  const ClassUncertaintyAnalyzer._();

  static UncertaintyHint fromScores(Map<String, double> scores) {
    if (scores.length < 2) {
      return const UncertaintyHint(isAmbiguous: false, message: '');
    }
    final entries = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = entries[0];
    final second = entries[1];
    final gap = top.value - second.value;
    if (gap >= 0.14) {
      return UncertaintyHint(
        isAmbiguous: false,
        message: 'Top match is clearly ahead of other classes.',
        runnerUpLabel: second.key,
        runnerUpScore: second.value,
      );
    }
    return UncertaintyHint(
      isAmbiguous: true,
      message:
          'Close call between “${top.key}” and “${second.key}” — take a closer, sharper photo or scan another leaf.',
      runnerUpLabel: second.key,
      runnerUpScore: second.value,
    );
  }
}
