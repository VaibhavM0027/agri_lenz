#!/usr/bin/env python3
"""
Train a MobileNetV2 classifier and export **float32** TFLite for Agri Lenz.

**Class order must match** `assets/models/labels.txt` and `lib/models/cnn_label_map.dart`
(CnnLabelMap.canonicalLabels), index i → output[i].

Expected folder layout under --data-dir::

    Healthy/
    Leaf Blight/
    Powdery Mildew/
    Rust/
    Leaf Spot/
    Pest Damage/

Install: ``pip install tensorflow``

Example::

    python tool/export_plant_disease_tflite.py ./plant_village_subset --epochs 8 --out crop_model.tflite

**Training tip (robustness):** mix full-leaf **healthy** images with random crops that **include lesion margins**
(yellow/brown/rust/tan against green). That teaches the CNN real discoloration patterns; Agri Lenz still applies a
**vision-first health tier** in the app (green + no holes → healthy) so deploy the model with clear lesion examples
in validation to avoid “everything diseased” logits.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


CANONICAL_LABELS = [
    "Healthy",
    "Leaf Blight",
    "Powdery Mildew",
    "Rust",
    "Leaf Spot",
    "Pest Damage",
]

INPUT_SIZE = 224


def main() -> int:
    try:
        import tensorflow as tf
        from tensorflow import keras
        from tensorflow.keras import layers
    except ImportError:
        print("Install TensorFlow: pip install tensorflow", file=sys.stderr)
        return 1

    ap = argparse.ArgumentParser(description="Train MobileNetV2 → TFLite for Agri Lenz")
    ap.add_argument(
        "data_dir",
        type=Path,
        help="Root directory with one subfolder per class (folder names = labels above)",
    )
    ap.add_argument("--epochs", type=int, default=10)
    ap.add_argument("--batch-size", type=int, default=32)
    ap.add_argument("--learning-rate", type=float, default=1e-4)
    ap.add_argument(
        "--out",
        type=Path,
        default=Path("crop_disease_mobilenetv2.tflite"),
        help="Output .tflite path",
    )
    ap.add_argument("--validation-split", type=float, default=0.15)
    ap.add_argument("--seed", type=int, default=42)
    args = ap.parse_args()

    data_dir = args.data_dir.resolve()
    if not data_dir.is_dir():
        print(f"Not a directory: {data_dir}", file=sys.stderr)
        return 1

    missing = [name for name in CANONICAL_LABELS if not (data_dir / name).is_dir()]
    if missing:
        print(
            "Missing class folders (names must match exactly, including spaces):\n  "
            + "\n  ".join(missing),
            file=sys.stderr,
        )
        return 1

    keras.utils.set_random_seed(args.seed)

    # Fixed order = CNN output indices (do not rely on alphabetical sorting).
    train_ds = keras.utils.image_dataset_from_directory(
        data_dir,
        labels="inferred",
        label_mode="int",
        class_names=CANONICAL_LABELS,
        image_size=(INPUT_SIZE, INPUT_SIZE),
        batch_size=args.batch_size,
        shuffle=True,
        seed=args.seed,
        validation_split=args.validation_split,
        subset="training",
    )
    val_ds = keras.utils.image_dataset_from_directory(
        data_dir,
        labels="inferred",
        label_mode="int",
        class_names=CANONICAL_LABELS,
        image_size=(INPUT_SIZE, INPUT_SIZE),
        batch_size=args.batch_size,
        shuffle=False,
        seed=args.seed,
        validation_split=args.validation_split,
        subset="validation",
    )

    normalization = layers.Rescaling(1.0 / 255.0)
    train_ds = train_ds.map(lambda x, y: (normalization(x), y), num_parallel_calls=tf.data.AUTOTUNE)
    val_ds = val_ds.map(lambda x, y: (normalization(x), y), num_parallel_calls=tf.data.AUTOTUNE)
    train_ds = train_ds.prefetch(tf.data.AUTOTUNE)
    val_ds = val_ds.prefetch(tf.data.AUTOTUNE)

    base = keras.applications.MobileNetV2(
        input_shape=(INPUT_SIZE, INPUT_SIZE, 3),
        include_top=False,
        weights="imagenet",
    )
    base.trainable = False

    inputs = keras.Input(shape=(INPUT_SIZE, INPUT_SIZE, 3))
    x = base(inputs, training=False)
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dropout(0.2)(x)
    outputs = layers.Dense(len(CANONICAL_LABELS), activation="softmax", dtype="float32")(x)
    model = keras.Model(inputs, outputs)

    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=args.learning_rate),
        loss=keras.losses.SparseCategoricalCrossentropy(),
        metrics=["accuracy"],
    )

    model.fit(train_ds, validation_data=val_ds, epochs=args.epochs, verbose=1)

    base.trainable = True
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=args.learning_rate / 10),
        loss=keras.losses.SparseCategoricalCrossentropy(),
        metrics=["accuracy"],
    )
    fine_tune_epochs = max(2, args.epochs // 3)
    model.fit(train_ds, validation_data=val_ds, epochs=fine_tune_epochs, verbose=1)

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = []
    tflite_model = converter.convert()

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_bytes(tflite_model)

    meta = {
        "input_size": INPUT_SIZE,
        "input_dtype": "float32",
        "normalize": "[0,1] per channel (Rescaling 1/255)",
        "labels": CANONICAL_LABELS,
        "output": "softmax probabilities, same order as labels",
    }
    meta_path = args.out.with_suffix(".json")
    meta_path.write_text(json.dumps(meta, indent=2), encoding="utf-8")

    print(f"Wrote {args.out} ({len(tflite_model)} bytes)")
    print(f"Wrote {meta_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
