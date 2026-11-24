// test/bundle_cover_layout_test.dart
//
// Bundle Image Composer layout: fixed canvas, deterministic tiles (2-5),
// fallback handling, and fingerprint-driven recomposition.
// Pure Dart: no Flutter widgets, no Firebase.

import 'package:flutter_test/flutter_test.dart';
import 'package:my_test_app/utils/bundle_cover_layout.dart';

CoverInput input(String offer, {String? imageUrl, int unit = 0}) =>
    CoverInput(
        offerId: offer,
        unitIndex: unit,
        imageUrl: imageUrl,
        label: offer);

void main() {
  group('bundle_cover_layout', () {
    test('canvas is fixed 1080 square with quality 85', () {
      expect(BundleCoverSpec.canvasSize, 1080);
      expect(BundleCoverSpec.jpegQuality, 85);
    });

    test('cover of 2 fills the canvas side by side', () {
      final tiles = coverTiles(2);
      expect(tiles.length, 2);
      final total = tiles.fold(0, (sum, t) => sum + t.width * t.height);
      expect(total, 1080 * 1080);
    });

    test('cover of 3 uses a large lead tile', () {
      final tiles = coverTiles(3);
      expect(tiles.length, 3);
      expect(tiles[0].width, greaterThan(tiles[1].width));
      final total = tiles.fold(0, (sum, t) => sum + t.width * t.height);
      expect(total, 1080 * 1080);
    });

    test('cover of 5 fills the canvas with 3+2 rows', () {
      final tiles = coverTiles(5);
      expect(tiles.length, 5);
      final total = tiles.fold(0, (sum, t) => sum + t.width * t.height);
      expect(total, 1080 * 1080);
    });

    test('counts outside 2-5 are rejected', () {
      expect(() => coverTiles(1), throwsArgumentError);
      expect(() => coverTiles(6), throwsArgumentError);
      expect(() => tilesForInputs([input('a')]), throwsArgumentError);
      expect(
          () => tilesForInputs(
              List.generate(6, (i) => input('o$i'))),
          throwsArgumentError);
    });

    test('missing image becomes a neutral fallback tile', () {
      final tiles = tilesForInputs([
        input('a', imageUrl: 'https://x/a.jpg'),
        input('b'),
        input('c', imageUrl: ''),
      ]);
      expect(tiles.length, 3);
      expect(tiles[0].fallback, isFalse);
      expect(tiles[1].fallback, isTrue);
      expect(tiles[2].fallback, isTrue);
    });

    test('fingerprint changes when a component or image changes', () {
      final before = [
        input('a', imageUrl: 'https://x/a.jpg'),
        input('b', imageUrl: 'https://x/b.jpg'),
      ];
      final sameAgain = [
        input('a', imageUrl: 'https://x/a.jpg'),
        input('b', imageUrl: 'https://x/b.jpg'),
      ];
      final swappedImage = [
        input('a', imageUrl: 'https://x/a2.jpg'),
        input('b', imageUrl: 'https://x/b.jpg'),
      ];
      final swappedOffer = [
        input('a', imageUrl: 'https://x/a.jpg'),
        input('c', imageUrl: 'https://x/b.jpg'),
      ];
      expect(coverFingerprint(sameAgain), coverFingerprint(before));
      expect(coverFingerprint(swappedImage),
          isNot(coverFingerprint(before)));
      expect(coverFingerprint(swappedOffer),
          isNot(coverFingerprint(before)));
    });

    test('storage path is deterministic per bundle id', () {
      expect(BundleCoverSpec.objectPath('b123'), 'bundles/b123/cover.jpg');
      expect(BundleCoverSpec.objectPath('b123'),
          BundleCoverSpec.objectPath('b123'));
      expect(BundleCoverSpec.objectPath('b1'),
          isNot(BundleCoverSpec.objectPath('b2')));
    });

    test('centerSquare crops to the largest centered square', () {
      expect(centerSquare(800, 600), [100, 0, 600]);
      expect(centerSquare(600, 800), [0, 100, 600]);
      expect(centerSquare(500, 500), [0, 0, 500]);
    });
  });
}
