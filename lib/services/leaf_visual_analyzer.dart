import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/analysis_models.dart';
import 'image_preprocess.dart';

/// Derives leaf color/texture signals used for soil hints, damage heuristics,
/// pest-injury proxies, and fallback disease scoring when no TFLite model is bundled.
class LeafVisualAnalyzer {
  /// Fuses multiple sampling scales + illumination-normalized pass (reduces false “healthy”).
  static LeafVisualFeatures analyzeEnhanced(Uint8List imageBytes) {
    final normalized = ImagePreprocess.normalizeIlluminationBytes(imageBytes);
    return _averageFeatures([
      analyze(imageBytes, sampleWidth: 228),
      analyze(imageBytes, sampleWidth: 172),
      analyze(normalized, sampleWidth: 200),
    ]);
  }

  static LeafVisualFeatures _averageFeatures(List<LeafVisualFeatures> list) {
    final n = list.length;
    if (n == 0) {
      return const LeafVisualFeatures(
        greenRatio: 0.25,
        yellowRatio: 0.2,
        brownRatio: 0.15,
        paleRatio: 0.2,
        darkSpotRatio: 0.1,
        rustLikeRatio: 0.05,
        borderBrownBias: 0.1,
        textureDamageScore: 0.22,
        pestInjuryScore: 0.22,
      );
    }
    var gr = 0.0,
        yr = 0.0,
        br = 0.0,
        pr = 0.0,
        dr = 0.0,
        rr = 0.0,
        bb = 0.0,
        tx = 0.0,
        ps = 0.0;
    for (final f in list) {
      gr += f.greenRatio;
      yr += f.yellowRatio;
      br += f.brownRatio;
      pr += f.paleRatio;
      dr += f.darkSpotRatio;
      rr += f.rustLikeRatio;
      bb += f.borderBrownBias;
      tx += f.textureDamageScore;
      ps += f.pestInjuryScore;
    }
    final inv = 1.0 / n;
    return LeafVisualFeatures(
      greenRatio: gr * inv,
      yellowRatio: yr * inv,
      brownRatio: br * inv,
      paleRatio: pr * inv,
      darkSpotRatio: dr * inv,
      rustLikeRatio: rr * inv,
      borderBrownBias: bb * inv,
      textureDamageScore: tx * inv,
      pestInjuryScore: ps * inv,
    );
  }

  static LeafVisualFeatures analyze(Uint8List imageBytes, {int sampleWidth = 200}) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      return const LeafVisualFeatures(
        greenRatio: 0.25,
        yellowRatio: 0.2,
        brownRatio: 0.15,
        paleRatio: 0.2,
        darkSpotRatio: 0.1,
        rustLikeRatio: 0.05,
        borderBrownBias: 0.1,
        textureDamageScore: 0.35,
        pestInjuryScore: 0.35,
      );
    }

    final sample = img.copyResize(decoded, width: sampleWidth, interpolation: img.Interpolation.average);
    final w = sample.width;
    final h = sample.height;
    if (w == 0 || h == 0) {
      return const LeafVisualFeatures(
        greenRatio: 0.25,
        yellowRatio: 0.2,
        brownRatio: 0.15,
        paleRatio: 0.2,
        darkSpotRatio: 0.1,
        rustLikeRatio: 0.05,
        borderBrownBias: 0.1,
        textureDamageScore: 0.35,
        pestInjuryScore: 0.35,
      );
    }

    var n = 0;
    var green = 0, yellow = 0, brown = 0, pale = 0, dark = 0, rust = 0;
    var borderBrown = 0, borderN = 0;

    final border = math.max(3, math.min(w, h) ~/ 16);

    double lum(num r, num g, num b) => 0.299 * r + 0.587 * g + 0.114 * b;

    bool isLeafGreen(int r, int g, int b) => g > r + 8 && g > b + 8 && g > 52;

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = sample.getPixel(x, y);
        final r = p.r.toInt();
        final g = p.g.toInt();
        final b = p.b.toInt();
        final l = lum(r, g, b);
        final mx = math.max(r, math.max(g, b));
        final mn = math.min(r, math.min(g, b));
        final sat = mx == 0 ? 0.0 : (mx - mn) / mx;

        n++;

        final isGreenish = g > r + 12 && g > b + 12 && g > 70;
        if (isGreenish) green++;

        final isYellowish = r > 110 && g > 110 && b < r - 15 && b < g - 15 && sat > 0.15;
        if (isYellowish) yellow++;

        final isBrownish = l < 120 && r > 50 && g > 40 && b > 20 && r >= b - 10 && sat < 0.45;
        if (isBrownish) brown++;

        final isPale = sat < 0.18 && l > 130;
        if (isPale) pale++;

        if (l < 58) dark++;

        final rustLike = r > 115 && r > g * 1.12 && r > b * 1.08 && sat > 0.12;
        if (rustLike) rust++;

        final onBorder = x < border || y < border || x >= w - border || y >= h - border;
        if (onBorder) {
          borderN++;
          if (isBrownish || l < 90) borderBrown++;
        }
      }
    }

    final inv = 1.0 / n;
    final greenRatio = green * inv;
    final yellowRatio = yellow * inv;
    final brownRatio = brown * inv;
    final paleRatio = pale * inv;
    final darkSpotRatio = dark * inv;
    final rustLikeRatio = rust * inv;
    final borderBrownBias = borderN == 0 ? 0.0 : borderBrown / borderN;

    final textureDamageScore = _textureDamage(sample);
    final pestInjuryScore = _pestInjuryScore(sample, greenRatio, isLeafGreen, lum);

    return LeafVisualFeatures(
      greenRatio: greenRatio,
      yellowRatio: yellowRatio,
      brownRatio: brownRatio,
      paleRatio: paleRatio,
      darkSpotRatio: darkSpotRatio,
      rustLikeRatio: rustLikeRatio,
      borderBrownBias: borderBrownBias,
      textureDamageScore: textureDamageScore,
      pestInjuryScore: pestInjuryScore,
    );
  }

  static double _textureDamage(img.Image im) {
    final w = im.width;
    final h = im.height;
    if (w < 8 || h < 8) return 0.22;

    var sum = 0.0;
    var count = 0;
    const step = 3;

    for (var y = 1; y < h - 1; y += step) {
      for (var x = 1; x < w - 1; x += step) {
        final c = im.getPixel(x, y);
        final u = im.getPixel(x, y - 1);
        final v = im.getPixel(x, y + 1);
        final l = im.getPixel(x - 1, y);
        final rr = im.getPixel(x + 1, y);
        final dr = (c.r - u.r).abs() + (c.r - v.r).abs() + (c.r - l.r).abs() + (c.r - rr.r).abs();
        final dg = (c.g - u.g).abs() + (c.g - v.g).abs() + (c.g - l.g).abs() + (c.g - rr.g).abs();
        final db = (c.b - u.b).abs() + (c.b - v.b).abs() + (c.b - l.b).abs() + (c.b - rr.b).abs();
        sum += (dr + dg + db) / (12 * 255);
        count++;
      }
    }

    if (count == 0) return 0.22;
    return (sum / count).clamp(0.0, 1.0);
  }

  static double _pestInjuryScore(
    img.Image im,
    double greenRatio,
    bool Function(int r, int g, int b) isLeafGreen,
    double Function(num r, num g, num b) lum,
  ) {
    final w = im.width;
    final h = im.height;
    if (w < 5 || h < 5) return 0.2;

    var holeEdge = 0;
    var speckle = 0;
    var darkCore = 0;
    var chewMargin = 0;
    var n2 = 0;

    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final p = im.getPixel(x, y);
        final r = p.r.toInt();
        final g = p.g.toInt();
        final b = p.b.toInt();
        final l = lum(r, g, b);

        var greenNbr = 0;
        var nbrLum = 0.0;
        var nbrCount = 0;
        for (final o in const [
          [0, -1],
          [0, 1],
          [-1, 0],
          [1, 0],
        ]) {
          final q = im.getPixel(x + o[0], y + o[1]);
          final qr = q.r.toInt();
          final qg = q.g.toInt();
          final qb = q.b.toInt();
          if (isLeafGreen(qr, qg, qb)) greenNbr++;
          nbrLum += lum(qr, qg, qb);
          nbrCount++;
        }
        final meanNbr = nbrLum / nbrCount;

        n2++;

        if (l < 55) darkCore++;

        // Hole / tear rim: darker patch touching green leaf tissue.
        if (l < 92 && l > 18 && greenNbr >= 1) holeEdge++;

        // Speckle: local dark dot on brighter leaf background (thrips / frass / small wounds).
        if (l < 82 && meanNbr - l > 22) speckle++;

        // Chewing: strong local contrast while center pixel still looks like leaf green.
        if (isLeafGreen(r, g, b)) {
          final gx = (im.getPixel(x + 1, y).r - im.getPixel(x - 1, y).r).abs() +
              (im.getPixel(x + 1, y).g - im.getPixel(x - 1, y).g).abs();
          final gy = (im.getPixel(x, y + 1).r - im.getPixel(x, y - 1).r).abs() +
              (im.getPixel(x, y + 1).g - im.getPixel(x, y - 1).g).abs();
          final grad = (gx + gy) / (4 * 255);
          if (grad > 0.18) chewMargin++;
        }
      }
    }

    if (n2 == 0) return 0.15;

    final inv2 = 1.0 / n2;
    final dCore = darkCore * inv2;
    final dHole = holeEdge * inv2;
    final dSpeck = speckle * inv2;
    final dChew = chewMargin * inv2;

    var score = dCore * 2.8 + dHole * 2.05 + dSpeck * 1.65 + dChew * 1.35;

    // Real leaf photos are mostly green; boost sensitivity when tissue looks like a leaf.
    if (greenRatio > 0.22) score *= 1.0 + (greenRatio - 0.22).clamp(0.0, 0.5) * 0.55;

    return score.clamp(0.0, 1.0);
  }
}
