import 'package:flutter_test/flutter_test.dart';
import 'package:my_test_app/utils/phone_format.dart';

// Phase 3: Marketplace login formatter — every accepted spelling of one
// Egyptian mobile number must collapse to the SAME Akedly 20-form, so /send
// binds the right transaction and the identity lookup hits the right doc.
// Mirrors backend akedly.js normalizePhone exactly.
void main() {
  group('formatPhoneToAkedly20', () {
    const cases = <List<String>>[
      // [input, expected20]
      ['01021070462', '201021070462'],
      ['201021070462', '201021070462'],
      ['+201021070462', '201021070462'],
      ['00201021070462', '201021070462'],
      ['010 2107 0462', '201021070462'],
      ['01112345678', '201112345678'],
      ['201112345678', '201112345678'],
      ['00201112345678', '201112345678'],
      ['01278287168', '201278287168'],
      ['201278287168', '201278287168'],
      ['+201278287168', '201278287168'],
      ['01551445210', '201551445210'],
      ['201551445210', '201551445210'],
      ['00201551445210', '201551445210'],
    ];

    for (final c in cases) {
      test('formats "${c[0]}" to "${c[1]}"', () {
        expect(formatPhoneToAkedly20(c[0]), c[1]);
      });
    }

    test('0020-form no longer gains a spurious extra 20 prefix', () {
      // Regression: old code produced '200201021070462' for 0020-input.
      final out = formatPhoneToAkedly20('00201021070462');
      expect(out, '201021070462');
      expect(out.length, 12);
    });
  });
}
