// test/whatsapp_consent_state_test.dart
//
// Focused regression tests for the «WhatsApp order notifications» consent
// card on the «My Account» screen: number normalization (with country code)
// and the server-truth active check (never active before a reliable save).
import 'package:flutter_test/flutter_test.dart';
import 'package:my_test_app/utils/whatsapp_consent_state.dart';

void main() {
  group('normalizeWhatsappNumber', () {
    test('accepts E.164 and 00 forms', () {
      expect(normalizeWhatsappNumber('+201012345678'), '+201012345678');
      expect(normalizeWhatsappNumber('00201012345678'), '+201012345678');
    });

    test('accepts Egyptian local 01 form and separators', () {
      expect(normalizeWhatsappNumber('01012345678'), '+201012345678');
      expect(normalizeWhatsappNumber('+20 101 234 5678'), '+201012345678');
      expect(normalizeWhatsappNumber('(010) 1234-5678'), '+201012345678');
    });

    test('rejects unusable input', () {
      expect(normalizeWhatsappNumber(null), isNull);
      expect(normalizeWhatsappNumber(''), isNull);
      expect(normalizeWhatsappNumber('   '), isNull);
      expect(normalizeWhatsappNumber('123'), isNull);
      expect(normalizeWhatsappNumber('+20'), isNull);
      expect(normalizeWhatsappNumber('not-a-number'), isNull);
      expect(normalizeWhatsappNumber('+20101234567890123'), isNull);
    });
  });

  group('isWhatsappActive', () {
    test('false unless opt-in is true with a valid number', () {
      expect(isWhatsappActive(null), isFalse);
      expect(isWhatsappActive({}), isFalse);
      expect(
        isWhatsappActive(
            {'whatsappOptIn': true, 'whatsappNumber': '01012345678'}),
        isTrue,
      );
      expect(
        isWhatsappActive(
            {'whatsappOptIn': true, 'whatsappNumber': 'bad'}),
        isFalse,
      );
      expect(
        isWhatsappActive(
            {'whatsappOptIn': false, 'whatsappNumber': '+201012345678'}),
        isFalse,
      );
      // Draft toggle alone never counts: only the persisted document matters.
      expect(isWhatsappActive({'whatsappNumber': '+201012345678'}), isFalse);
    });
  });
}
