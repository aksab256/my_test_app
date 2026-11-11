import 'package:flutter_test/flutter_test.dart';
import 'package:my_test_app/utils/profile_update.dart';

// Locks the My Account contract: a profile save from '/myDetails' must
// never carry an address key, and the locked address label shows the
// registered value even when partial.
void main() {
  group('buildProfileNameUpdate', () {
    test('consumer update uses fullname and never address', () {
      final updates = buildProfileNameUpdate(
        isConsumerCollection: true,
        name: '  أحمد  ',
      );

      expect(updates, {'fullname': 'أحمد'});
      expect(updates.containsKey('address'), isFalse);
    });

    test('non-consumer update uses name and never address', () {
      final updates = buildProfileNameUpdate(
        isConsumerCollection: false,
        name: 'تاجر أكسب',
      );

      expect(updates, {'name': 'تاجر أكسب'});
      expect(updates.containsKey('address'), isFalse);
    });
  });

  group('registeredAddressLabel', () {
    test('shows the registered value even when partial', () {
      expect(registeredAddressLabel('شارع'), 'شارع');
      expect(registeredAddressLabel('  الإسكندرية  '), 'الإسكندرية');
    });

    test('falls back only when the address is missing', () {
      expect(registeredAddressLabel(null), 'غير متوفر');
      expect(registeredAddressLabel(''), 'غير متوفر');
      expect(registeredAddressLabel('   '), 'غير متوفر');
    });
  });
}
