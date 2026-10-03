import 'package:flutter_test/flutter_test.dart';
import 'package:my_test_app/widgets/login_form_widget.dart';

void main() {
  group('OTP send cooldown (login flow)', () {
    test('cooldown window is 60 seconds', () {
      expect(OtpSendCooldown.windowSeconds, 60);
    });

    test('no cooldown before any successful send', () {
      final now = DateTime(2026, 9, 25, 22, 55, 0);
      expect(OtpSendCooldown.isActive(null, now), isFalse);
      expect(OtpSendCooldown.remaining(null, now), 0);
    });

    test('cooldown active right after a successful send', () {
      final sentAt = DateTime(2026, 9, 25, 22, 55, 0);
      final during = sentAt.add(const Duration(seconds: 10));
      expect(OtpSendCooldown.isActive(sentAt, during), isTrue);
      expect(OtpSendCooldown.remaining(sentAt, during), 50);
    });

    test('cooldown expires after 60 seconds', () {
      final sentAt = DateTime(2026, 9, 25, 22, 55, 0);
      final after = sentAt.add(const Duration(seconds: 60));
      expect(OtpSendCooldown.isActive(sentAt, after), isFalse);
      expect(OtpSendCooldown.remaining(sentAt, after), 0);
    });

    test('remaining never goes negative', () {
      final sentAt = DateTime(2026, 9, 25, 22, 55, 0);
      final late = sentAt.add(const Duration(minutes: 10));
      expect(OtpSendCooldown.remaining(sentAt, late), 0);
    });
  });
}
