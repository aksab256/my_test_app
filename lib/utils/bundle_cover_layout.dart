// lib/utils/bundle_cover_layout.dart
//
// Pure bundle-cover layout math (no Flutter, no Firebase).
// The composer renders original product images into a fixed canvas with a
// fixed, deterministic tile plan per component count (2-5). No AI, no
// regeneration: tiles are center-cropped originals; missing/invalid images
// get a neutral numbered fallback tile (never invented product imagery).

import 'dart:math' as math;

/// Fixed cover canvas (square, uniform for every bundle).
/// Covers are stored on Cloudinary (unsigned preset, folder
/// `bundle_covers`); the stored reference is the Cloudinary `public_id`,
/// never a local storage path.
class BundleCoverSpec {
  static const int canvasSize = 1080;
  static const int jpegQuality = 85;
}

/// One tile inside the canvas (pixel rect).
class CoverTile {
  /// Index of the component image (0-based).
  final int slot;

  final int x;
  final int y;
  final int width;
  final int height;

  /// True when the component image is missing/invalid: render fallback.
  final bool fallback;

  const CoverTile({
    required this.slot,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.fallback = false,
  });

  Map<String, int> toMap() => {
        'slot': slot,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };
}

/// Deterministic tile plan for [count] components (2-5).
/// Throws [ArgumentError] for any other count.
List<CoverTile> coverTiles(int count, {Set<int> fallbackSlots = const {}}) {
  const s = BundleCoverSpec.canvasSize;
  bool fb(int i) => fallbackSlots.contains(i);
  switch (count) {
    case 2:
      final w = s ~/ 2;
      return [
        CoverTile(slot: 0, x: 0, y: 0, width: w, height: s, fallback: fb(0)),
        CoverTile(slot: 1, x: w, y: 0, width: s - w, height: s, fallback: fb(1)),
      ];
    case 3:
      // Large lead tile + two stacked on the right.
      final w = (s * 2) ~/ 3;
      final h = s ~/ 2;
      return [
        CoverTile(slot: 0, x: 0, y: 0, width: w, height: s, fallback: fb(0)),
        CoverTile(slot: 1, x: w, y: 0, width: s - w, height: h, fallback: fb(1)),
        CoverTile(slot: 2, x: w, y: h, width: s - w, height: s - h, fallback: fb(2)),
      ];
    case 4:
      final w = s ~/ 2;
      final h = s ~/ 2;
      return [
        for (int i = 0; i < 4; i++)
          CoverTile(
            slot: i,
            x: (i % 2) * w,
            y: (i ~/ 2) * h,
            width: (i % 2 == 0) ? w : s - w,
            height: (i ~/ 2 == 0) ? h : s - h,
            fallback: fb(i),
          ),
      ];
    case 5:
      // Top row of three + bottom row of two.
      final tw = s ~/ 3;
      final th = s ~/ 2;
      final bw = s ~/ 2;
      return [
        CoverTile(slot: 0, x: 0, y: 0, width: tw, height: th, fallback: fb(0)),
        CoverTile(slot: 1, x: tw, y: 0, width: tw, height: th, fallback: fb(1)),
        CoverTile(slot: 2, x: tw * 2, y: 0, width: s - tw * 2, height: th, fallback: fb(2)),
        CoverTile(slot: 3, x: 0, y: th, width: bw, height: s - th, fallback: fb(3)),
        CoverTile(slot: 4, x: bw, y: th, width: s - bw, height: s - th, fallback: fb(4)),
      ];
    default:
      throw ArgumentError('Bundle cover needs 2-5 components (got $count).');
  }
}

/// Fingerprint of the cover inputs: any component/image change recomposes.
String coverFingerprint(List<CoverInput> inputs) {
  return inputs
      .map((e) => '${e.offerId}||${e.unitIndex}||${e.imageUrl ?? ''}')
      .join('##');
}

/// One cover input (original component image, may be null => fallback).
class CoverInput {
  final String offerId;
  final int unitIndex;
  final String? imageUrl;
  final String label;

  const CoverInput({
    required this.offerId,
    this.unitIndex = 0,
    this.imageUrl,
    required this.label,
  });

  bool get hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;
}

/// Validate + build tiles for inputs (2-5, fallback for imageless slots).
List<CoverTile> tilesForInputs(List<CoverInput> inputs) {
  if (inputs.length < 2 || inputs.length > 5) {
    throw ArgumentError(
        'Bundle cover needs 2-5 components (got ${inputs.length}).');
  }
  final fb = <int>{};
  for (int i = 0; i < inputs.length; i++) {
    if (!inputs[i].hasImage) fb.add(i);
  }
  return coverTiles(inputs.length, fallbackSlots: fb);
}

/// Largest centered square inside (w x h), as [x, y, size].
List<int> centerSquare(int w, int h) {
  final size = math.min(w, h);
  return [(w - size) ~/ 2, (h - size) ~/ 2, size];
}
