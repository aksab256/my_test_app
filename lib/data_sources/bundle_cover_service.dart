// lib/data_sources/bundle_cover_service.dart
//
// Bundle Image Composer (frontend): rasterizes ORIGINAL component images
// into one fixed cover (1080x1080 JPEG q85) with a deterministic tile plan,
// uploads it to Cloudinary with the SAME unsigned setup the app already
// uses everywhere else (cloud dgmmx6jbu + preset "commerce", no API secret
// in the app), and returns reference metadata for the bundle record.
//
// No AI, no regeneration: tiles are center-cropped originals;
// missing/invalid images become neutral numbered fallback tiles.
// The stored reference is Cloudinary's `public_id` (coverImagePath) plus
// `secure_url` (coverImageUrl). Old assets are never deleted: the app has
// no image-deletion flow (logoUrl replacement orphans the old asset), so a
// cover replace only points the bundle doc at the new asset after a
// successful upload — the new reference is never written before success.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:my_test_app/utils/bundle_cover_layout.dart';

/// Same unsigned Cloudinary setup the app already uses (seller logos,
/// merchant onboarding docs): no keys or secrets live in the client.
class BundleCoverCloudinary {
  static const String uploadUrl =
      'https://api.cloudinary.com/v1_1/dgmmx6jbu/image/upload';
  static const String uploadPreset = 'commerce';

  /// Folder for bundle covers (mirrors the `merchant_logos` folder usage).
  static const String folder = 'bundle_covers';

  /// Only URLs served by our own Cloudinary cloud are stored.
  static const String imageHost = 'res.cloudinary.com';
}

/// Thrown when the cover cannot be produced or uploaded at all.
/// Callers treat this as "proceed without cover" (fallback display).
class BundleCoverException implements Exception {
  final String message;
  const BundleCoverException(this.message);

  @override
  String toString() => 'BundleCoverException: $message';
}

class BundleCoverResult {
  /// Cloudinary `public_id` of the uploaded cover (stable reference for any
  /// future server-side cleanup; never a Firebase Storage path).
  final String coverImagePath;

  /// Cloudinary `secure_url` for direct display (buyer-ready).
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
  final http.Client _http;
  final Duration fetchTimeout;

  BundleCoverService(
      {http.Client? httpClient,
      this.fetchTimeout = const Duration(seconds: 10)})
      : _http = httpClient ?? http.Client();

  /// Compose the cover from [inputs] and upload it to Cloudinary.
  /// Returns reference metadata for the bundle record. Throws
  /// [BundleCoverException] when no cover bytes could be produced or the
  /// upload fails — in that case NOTHING is written to the bundle doc by
  /// this service, so the caller must keep the existing (or missing) cover
  /// reference and the reservation stays untouched.
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
      throw BundleCoverException('تعذر تركيب صورة الغلاف: $e');
    }

    final now = DateTime.now().toUtc();
    late final String publicId;
    late final String secureUrl;
    try {
      final request = http.MultipartRequest(
          'POST', Uri.parse(BundleCoverCloudinary.uploadUrl));
      request.fields['upload_preset'] = BundleCoverCloudinary.uploadPreset;
      request.fields['folder'] = BundleCoverCloudinary.folder;
      request.files.add(http.MultipartFile.fromBytes('file', jpg,
          filename: 'cover.jpg'));
      final streamed =
          await _http.send(request).timeout(fetchTimeout);
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode != 200) {
        throw BundleCoverException(
            'فشل رفع صورة الغلاف إلى Cloudinary (${streamed.statusCode}).');
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        throw BundleCoverException(
            'فشل رفع صورة الغلاف إلى Cloudinary (رد غير صالح).');
      }
      publicId = (decoded['public_id'] ?? '').toString();
      secureUrl = (decoded['secure_url'] ?? '').toString();
      final host = Uri.tryParse(secureUrl)?.host ?? '';
      if (publicId.isEmpty ||
          secureUrl.isEmpty ||
          host != BundleCoverCloudinary.imageHost) {
        throw BundleCoverException(
            'فشل رفع صورة الغلاف إلى Cloudinary (بيانات ناقصة).');
      }
    } on BundleCoverException {
      rethrow;
    } catch (e) {
      throw BundleCoverException('فشل رفع صورة الغلاف إلى Cloudinary: $e');
    }

    return BundleCoverResult(
      coverImagePath: publicId,
      coverImageUrl: secureUrl,
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
      throw BundleCoverException('تعذر تركيب معاينة الغلاف: $e');
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
