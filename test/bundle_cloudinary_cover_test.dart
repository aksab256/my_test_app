// test/bundle_cloudinary_cover_test.dart
//
// Bundle covers go to Cloudinary (unsigned preset, same as seller logos),
// never to Firebase Storage. Fake HTTP client: no network, no secrets.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:my_test_app/data_sources/bundle_cover_service.dart';
import 'package:my_test_app/utils/bundle_cover_layout.dart';

CoverInput _slot(String offer) =>
    CoverInput(offerId: offer, imageUrl: null, label: offer);

List<CoverInput> _inputs() => [_slot('a'), _slot('b'), _slot('c')];

/// Canned Cloudinary upload endpoint: records requests, replays a script.
class _FakeCloudinary extends http.BaseClient {
  final List<http.BaseRequest> requests = [];
  final List<Map<String, dynamic>> script;
  int _i = 0;

  _FakeCloudinary(this.script);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final step = script[_i < script.length ? _i++ : script.length - 1];
    if (step.containsKey('throw')) {
      throw Exception(step['throw']);
    }
    final status = step['status'] as int? ?? 200;
    final body = step['body'] as String? ?? '{}';
    return http.StreamedResponse(
        Stream.value(utf8.encode(body)), status);
  }
}

String _okBody(String publicId) => jsonEncode({
      'public_id': publicId,
      'secure_url':
          'https://res.cloudinary.com/dgmmx6jbu/image/upload/v9/$publicId.jpg',
    });

void main() {
  group('bundle_cloudinary_cover', () {
    test('reuses the app-wide unsigned Cloudinary setup', () {
      expect(BundleCoverCloudinary.uploadUrl,
          'https://api.cloudinary.com/v1_1/dgmmx6jbu/image/upload');
      expect(BundleCoverCloudinary.uploadPreset, 'commerce');
      expect(BundleCoverCloudinary.folder, 'bundle_covers');
      expect(BundleCoverCloudinary.imageHost, 'res.cloudinary.com');
    });

    test('upload sends preset+folder+file and stores public_id/secure_url', () async {
      final fake = _FakeCloudinary([
        {'body': _okBody('bundle_covers/abc123')}
      ]);
      final service = BundleCoverService(httpClient: fake);
      final result = await service.composeAndUpload(
          bundleDocId: 'b1', inputs: _inputs(), version: 2);

      expect(result.coverImagePath, 'bundle_covers/abc123');
      expect(result.coverImageUrl, contains('res.cloudinary.com'));
      expect(result.coverVersion, 2);
      expect(result.fallbackCount, 3); // imageless inputs -> fallback tiles
      expect(result.toMap()['coverStatus'], 'fallback');

      expect(fake.requests.length, 1);
      final req = fake.requests.single;
      expect(req.url.toString(), BundleCoverCloudinary.uploadUrl);
      expect(req, isA<http.MultipartRequest>());
      final multi = req as http.MultipartRequest;
      expect(multi.fields['upload_preset'], 'commerce');
      expect(multi.fields['folder'], 'bundle_covers');
      expect(multi.files.length, 1);
      expect(multi.files.single.filename, 'cover.jpg');
    });

    test('non-200 upload throws and yields no reference to store', () async {
      final fake = _FakeCloudinary([
        {'status': 400, 'body': '{"error":{"message":"bad preset"}}'}
      ]);
      final service = BundleCoverService(httpClient: fake);
      await expectLater(
        service.composeAndUpload(bundleDocId: 'b1', inputs: _inputs()),
        throwsA(isA<BundleCoverException>()),
      );
      // The throw happens before any result exists, so a caller keeping
      // the previous (or missing) cover reference leaves the bundle
      // consistent and the reservation untouched.
    });

    test('transport failure throws (bundle stays consistent)', () async {
      final fake = _FakeCloudinary([
        {'throw': 'socket reset'}
      ]);
      final service = BundleCoverService(httpClient: fake);
      await expectLater(
        service.composeAndUpload(bundleDocId: 'b1', inputs: _inputs()),
        throwsA(isA<BundleCoverException>()),
      );
    });

    test('missing public_id or foreign host is rejected', () async {
      for (final body in [
        jsonEncode({'secure_url': 'https://res.cloudinary.com/x/y.jpg'}),
        jsonEncode({
          'public_id': 'bundle_covers/a',
          'secure_url': 'https://evil.example.com/a.jpg'
        }),
        'not-json{{{',
      ]) {
        final fake = _FakeCloudinary([
          {'body': body}
        ]);
        final service = BundleCoverService(httpClient: fake);
        await expectLater(
          service.composeAndUpload(bundleDocId: 'b1', inputs: _inputs()),
          throwsA(isA<BundleCoverException>()),
          reason: 'body: $body',
        );
      }
    });

    test('replace uploads a new asset and never deletes the old one', () async {
      final fake = _FakeCloudinary([
        {'body': _okBody('bundle_covers/old111')},
        {'body': _okBody('bundle_covers/new222')},
      ]);
      final service = BundleCoverService(httpClient: fake);
      final first = await service.composeAndUpload(
          bundleDocId: 'b1', inputs: _inputs(), version: 1);
      final second = await service.composeAndUpload(
          bundleDocId: 'b1', inputs: _inputs(), version: 2);

      expect(first.coverImagePath, isNot(second.coverImagePath));
      expect(second.coverVersion, 2);
      // Policy matches the rest of the app (logoUrl replacement): no
      // destroy/delete call exists — both requests hit the upload endpoint.
      expect(fake.requests.length, 2);
      for (final r in fake.requests) {
        expect(r.url.toString(), BundleCoverCloudinary.uploadUrl);
        expect(r.method, 'POST');
      }
    });
  });
}
