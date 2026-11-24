// lib/data_sources/bundle_cover_service.dart
//
// Bundle Image Composer (frontend): rasterizes ORIGINAL component images
// into one fixed cover (1080x1080 JPEG q85) with a deterministic tile plan,
// uploads it to Firebase Storage, and returns path metadata for the bundle
// record. No AI, no regeneration: tiles are center-cropped originals;
// missing/invalid images become neutral numbered fallback tiles.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import 'package:my_test_app/utils/bundle_cover_layout.dart';

/// Thrown when the cover cannot be produced or uploaded at all.
/// Callers treat this as "proceed without cover" (fallback display).
class BundleCoverException implements Exception {
  final String message;
  const BundleCoverException(this.message);

  @override
  String toString() => 'BundleCoverException: $message';
}

class BundleCoverResult {
  /// Storage object path, e.g. `bundles/b_<key>/cover.jpg`.
  final String coverImagePath;

  /// Public download URL for direct display (buyer-ready).
  final String coverImageUrl;

  final DateTime coverUpdatedAt;
  final int coverVersion;
  final String fingerprint;
  final int fallbackCount;

  const BundleCoverResult({
    required this.coverImagePath,
    required this.coverImageUrl,
    required this.coverUpdatedAt,
    required this.coverVersion,
    required this.fingerprint,
    required this.fallbackCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'coverImagePath': coverImagePath,
      'coverImageUrl': coverImageUrl,
      'coverUpdatedAt': coverUpdatedAt.toIso8601String(),
      'coverVersion': coverVersion,
      'coverFingerprint': fingerprint,
      'coverFallbackCount': fallbackCount,
      'coverStatus': fallbackCount > 0 ? 'fallback' : 'ready',
    };
  }
}

class BundleCoverService {
  final FirebaseStorage _storage;
  final Duration fetchTimeout;

  BundleCoverService(
      {FirebaseStorage? storage,
      this.fetchTimeout = const Duration(seconds: 10)})
      : _storage = storage ?? FirebaseStorage.instance;

  /// Compose the cover from [inputs] and upload it for [bundleDocId].
  /// Returns metadata for the bundle record. Throws [BundleCoverException]
  /// only when no cover bytes could be produced or uploaded.
  Future<BundleCoverResult> composeAndUpload({
    required String bundleDocId,
    required List<CoverInput> inputs,
    int version = 1,
  }) async {
    final tiles = tilesForInputs(inputs);
    final canvas =
        img.Image(width: BundleCoverSpec.canvasSize, height: BundleCoverSpec.canvasSize);
    img.fill(canvas, color: img.ColorRgb8(240, 244, 241));

    int fallbacks = 0;
    for (int i = 0; i < tiles.length; i++) {
      final tile = tiles[i];
      img.Image? photo;
      if (!tile.fallback) {
        try {
          final bytes = await _fetch(inputs[i].imageUrl!)
              .timeout(fetchTimeout);
          photo = img.decodeImage(bytes);
        } catch (_) {
          photo = null;
        }
      }
      if (photo == null) {
        fallbacks++;
        _paintFallback(canvas, tile, i);
      } else {
        _paintPhoto(canvas, tile, photo);
      }
    }

    Uint8List jpg;
    try {
      jpg = Uint8List.fromList(
          img.encodeJpg(canvas, quality: BundleCoverSpec.jpegQuality));
    } catch (e) {
      throw BundleCoverException('تعذر ترميز صورة الغلاف: $e');
    }

    final path = BundleCoverSpec.objectPath(bundleDocId);
    final now = DateTime.now().toUtc();
    late final String url;
    try {
      final ref = _storage.ref(path);
      await ref.putData(
        jpg,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'bundleDocId': bundleDocId,
            'coverVersion': '$version',
            'fingerprint': coverFingerprint(inputs),
            'composedAt': now.toIso8601String(),
          },
        ),
      );
      url = await ref.getDownloadURL();
    } catch (e) {
      throw BundleCoverException('فشل رفع صورة الغلاف إلى التخزين: $e');
    }

    return BundleCoverResult(
      coverImagePath: path,
      coverImageUrl: url,
      coverUpdatedAt: now,
      coverVersion: version,
      fingerprint: coverFingerprint(inputs),
      fallbackCount: fallbacks,
    );
  }

  /// Compose cover bytes for live preview (same renderer as upload).
  /// Returns JPEG bytes, or throws [BundleCoverException] on encode failure.
  /// Network failures degrade to fallback tiles, never to an exception.
  Future<Uint8List> composePreviewBytes(List<CoverInput> inputs) async {
    final tiles = tilesForInputs(inputs);
    final canvas =
        img.Image(width: BundleCoverSpec.canvasSize, height: BundleCoverSpec.canvasSize);
    img.fill(canvas, color: img.ColorRgb8(240, 244, 241));
    for (int i = 0; i < tiles.length; i++) {
      final tile = tiles[i];
      img.Image? photo;
      if (!tile.fallback) {
        try {
          final bytes =
              await _fetch(inputs[i].imageUrl!).timeout(fetchTimeout);
          photo = img.decodeImage(bytes);
        } catch (_) {
          photo = null;
        }
      }
      if (photo == null) {
        _paintFallback(canvas, tile, i);
      } else {
        _paintPhoto(canvas, tile, photo);
      }
    }
    try {
      return Uint8List.fromList(
          img.encodeJpg(canvas, quality: BundleCoverSpec.jpegQuality));
    } catch (e) {
      throw BundleCoverException('تعذر ترميز معاينة الغلاف: $e');
    }
  }

  Future<Uint8List> _fetch(String url) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close();
      if (res.statusCode != 200) {
        throw BundleCoverException('صورة غير صالحة ($url): ${res.statusCode}');
      }
      final chunks = <int>[];
      await for (final c in res) {
        chunks.addAll(c);
      }
      return Uint8List.fromList(chunks);
    } finally {
      client.close(force: true);
    }
  }

  void _paintPhoto(img.Image canvas, CoverTile tile, img.Image photo) {
    final sq = centerSquare(photo.width, photo.height);
    final cropped = img.copyCrop(photo,
        x: sq[0], y: sq[1], width: sq[2], height: sq[2]);
    final fitted =
        img.copyResize(cropped, width: tile.width, height: tile.height);
    img.compositeImage(canvas, fitted, dstX: tile.x, dstY: tile.y);
  }

  void _paintFallback(img.Image canvas, CoverTile tile, int index) {
    // Neutral tile + slot number (no product imagery invented).
    final tileImg =
        img.Image(width: tile.width, height: tile.height);
    img.fill(tileImg, color: img.ColorRgb8(27, 94, 32));
    final label = '${index + 1}';
    img.drawString(tileImg, label,
        font: img.arial48,
        x: (tile.width ~/ 2) - 16,
        y: (tile.height ~/ 2) - 28,
        color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(canvas, tileImg, dstX: tile.x, dstY: tile.y);
  }
}
