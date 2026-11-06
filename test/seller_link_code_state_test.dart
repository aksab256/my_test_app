// test/seller_link_code_state_test.dart
//
// Focused regression tests for the Rabia link-code card on the «My Account»
// screen: the card must read ONLY `temp_link_code` from the authorized
// session document, distinguish available/expired/consumed/unavailable, and
// never consult the dead `integrationCode` path.
import 'package:flutter_test/flutter_test.dart';
import 'package:my_test_app/utils/seller_link_code_state.dart';

void main() {
  group('classifySellerLinkCode', () {
    test('available: code present and window still valid', () {
      final now = DateTime.now();
      final view = classifySellerLinkCode(
        {
          'temp_link_code': 'RABIA-ABC123',
          'link_code_expires_at': now.add(const Duration(minutes: 9)).millisecondsSinceEpoch,
        },
        now: now,
      );
      expect(view.state, SellerLinkCodeState.available);
      expect(view.code, 'RABIA-ABC123');
    });

    test('expired: code present but window passed', () {
      final now = DateTime.now();
      final view = classifySellerLinkCode(
        {
          'temp_link_code': 'RABIA-ABC123',
          'link_code_expires_at': now.subtract(const Duration(seconds: 1)).millisecondsSinceEpoch,
        },
        now: now,
      );
      expect(view.state, SellerLinkCodeState.expired);
      // The stale code is still returned for copy purposes, display masks it.
      expect(view.code, 'RABIA-ABC123');
    });

    test('expired: missing or unparseable expiry fails closed', () {
      final now = DateTime.now();
      expect(
        classifySellerLinkCode({'temp_link_code': 'RABIA-ABC123'}, now: now).state,
        SellerLinkCodeState.expired,
      );
      expect(
        classifySellerLinkCode(
          {'temp_link_code': 'RABIA-ABC123', 'link_code_expires_at': 'not-a-date'},
          now: now,
        ).state,
        SellerLinkCodeState.expired,
      );
    });

    test('linkedConsumed: empty code with verified link', () {
      final view = classifySellerLinkCode({'erp_link_verified': true});
      expect(view.state, SellerLinkCodeState.linkedConsumed);
      expect(view.code, isEmpty);
    });

    test('unavailable: empty code with no verified link', () {
      expect(classifySellerLinkCode({}).state, SellerLinkCodeState.unavailable);
      expect(classifySellerLinkCode(null).state, SellerLinkCodeState.unavailable);
      expect(
        classifySellerLinkCode({'temp_link_code': '   ', 'erp_link_verified': false}).state,
        SellerLinkCodeState.unavailable,
      );
    });

    test('ignores non-string temp_link_code values', () {
      expect(
        classifySellerLinkCode({'temp_link_code': 12345}).state,
        SellerLinkCodeState.unavailable,
      );
    });

    test('never reads the dead integrationCode path', () {
      // Even when integrationCode holds a value, the view must stay
      // unavailable: nothing ever writes that field, so surfacing it would
      // display a code from an unknown origin.
      final view = classifySellerLinkCode({'integrationCode': 'RABIA-STALE'});
      expect(view.state, SellerLinkCodeState.unavailable);
      expect(view.code, isEmpty);
    });

    test('accepts DateTime and ISO-8601 expiries', () {
      final now = DateTime.now();
      final future = now.add(const Duration(minutes: 5));
      expect(
        classifySellerLinkCode(
          {'temp_link_code': 'RABIA-X', 'link_code_expires_at': future},
          now: now,
        ).state,
        SellerLinkCodeState.available,
      );
      expect(
        classifySellerLinkCode(
          {'temp_link_code': 'RABIA-X', 'link_code_expires_at': future.toIso8601String()},
          now: now,
        ).state,
        SellerLinkCodeState.available,
      );
    });
  });
}
