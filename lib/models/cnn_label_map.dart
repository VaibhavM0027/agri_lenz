/// Canonical class order for CNN outputs: **index i = line i in assets/models/labels.txt**.
///
/// MobileNetV2 / EfficientNet-Lite heads must be trained so `output[i]` corresponds to
/// `canonicalLabels[i]`. Re-export your Keras/PyTorch label list in the same order before TFLite conversion.
abstract final class CnnLabelMap {
  /// Standard spatial size for MobileNetV2 / many EfficientNet-Lite TFLite classifiers.
  static const int inputSize = 224;

  /// Must match [assets/models/labels.txt] line-for-line (trimmed, non-empty lines only).
  static const List<String> canonicalLabels = [
    'Healthy',
    'Leaf Blight',
    'Powdery Mildew',
    'Rust',
    'Leaf Spot',
    'Pest Damage',
  ];

  /// Returns false if the bundled [labels.txt] order does not match the model contract.
  static bool validateAgainstFile(List<String> fileLabels) {
    if (fileLabels.length != canonicalLabels.length) return false;
    for (var i = 0; i < canonicalLabels.length; i++) {
      if (fileLabels[i] != canonicalLabels[i]) return false;
    }
    return true;
  }

  /// Human-readable index table for debugging / support.
  static String indexLegend() {
    final b = StringBuffer('CNN output index → label:\n');
    for (var i = 0; i < canonicalLabels.length; i++) {
      b.writeln('  [$i] ${canonicalLabels[i]}');
    }
    return b.toString();
  }
}
