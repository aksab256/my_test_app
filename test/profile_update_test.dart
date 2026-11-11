import 'package:flutter_test/flutter_test.dart';
import 'package:my_test_app/utils/profile_update.dart';

// Locks the My Account contract: a profile save from '/myDetails' must
// never carry an address key — the address stays fixed as registered.
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
}
