import 'package:flutter_test/flutter_test.dart';
import 'package:my_test_app/helpers/places_api_helper.dart';

void main() {
  group('parsePlacesStatus', () {
    test('maps known statuses', () {
      expect(parsePlacesStatus('OK'), PlacesApiStatus.ok);
      expect(parsePlacesStatus('ZERO_RESULTS'), PlacesApiStatus.zeroResults);
      expect(parsePlacesStatus('NOT_FOUND'), PlacesApiStatus.notFound);
      expect(parsePlacesStatus('REQUEST_DENIED'), PlacesApiStatus.requestDenied);
      expect(parsePlacesStatus('OVER_QUERY_LIMIT'), PlacesApiStatus.overQueryLimit);
      expect(parsePlacesStatus('INVALID_REQUEST'), PlacesApiStatus.invalidRequest);
    });

    test('unknown and null fall back to unknown without throwing', () {
      expect(parsePlacesStatus('SOMETHING_NEW'), PlacesApiStatus.unknown);
      expect(parsePlacesStatus(null), PlacesApiStatus.unknown);
      expect(parsePlacesStatus(42), PlacesApiStatus.unknown);
    });
  });

  test('user messages never expose request data', () {
    for (final s in PlacesApiStatus.values) {
      final msg = placesUserMessage(s);
      expect(msg.contains('AIza'), isFalse);
      expect(msg.contains('http'), isFalse);
      expect(msg.contains('key='), isFalse);
    }
    expect(placesUserMessage(PlacesApiStatus.ok), isEmpty);
  });

  test('log line carries status only, never secrets', () {
    final line = placesLogLine(
        'autocomplete', PlacesApiStatus.requestDenied, 'The provided API key is invalid.');
    expect(line, contains('requestDenied'));
    expect(line.contains('AIza'), isFalse);
    expect(line.contains('http'), isFalse);
  });

  group('parsePlaceDetailsLocation', () {
    test('extracts lat/lng on OK', () {
      expect(
        parsePlaceDetailsLocation({
          'status': 'OK',
          'result': {
            'geometry': {
              'location': {'lat': 30.0, 'lng': 31.0}
            }
          }
        }),
        {'lat': 30.0, 'lng': 31.0},
      );
    });

    test('null on denied/missing geometry without throwing', () {
      expect(parsePlaceDetailsLocation({'status': 'REQUEST_DENIED'}), isNull);
      expect(parsePlaceDetailsLocation({'status': 'OK'}), isNull);
      expect(parsePlaceDetailsLocation({'status': 'OK', 'result': {}}), isNull);
      expect(
        parsePlaceDetailsLocation({
          'status': 'OK',
          'result': {
            'geometry': {'location': {'lat': 'x'}}
          }
        }),
        isNull,
      );
    });
  });
}
