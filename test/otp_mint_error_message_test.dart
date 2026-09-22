import 'package:flutter_test/flutter_test.dart';
import 'package:my_test_app/widgets/login_form_widget.dart';

void main() {
  test('mint statuses map to distinct user-facing messages', () {
    expect(LoginFormWidget.mintErrorMessage(400), contains('غير صحيح'));
    expect(
      LoginFormWidget.mintErrorMessage(410),
      contains('انتهت صلاحية'),
    );
    expect(LoginFormWidget.mintErrorMessage(429), contains('محاولات'));
    expect(LoginFormWidget.mintErrorMessage(503), contains('غير متاحة'));
  });

  test('unknown mint status falls back to generic wrong-code message', () {
    expect(LoginFormWidget.mintErrorMessage(500), contains('خاطئ'));
    expect(LoginFormWidget.mintErrorMessage(-1), contains('خاطئ'));
  });

  test('review numbers match in both local and international forms', () {
    expect(
      LoginFormWidget.isReviewNumber('01278287168', '201278287168'),
      isTrue,
    );
    expect(
      LoginFormWidget.isReviewNumber('01551445210', '201551445210'),
      isTrue,
    );
    expect(
      LoginFormWidget.isReviewNumber('01021070461', '201021070461'),
      isTrue,
    );
    // Either form alone is enough (mirrors the submit/verify checks).
    expect(LoginFormWidget.isReviewNumber('01021070461', ''), isTrue);
    expect(LoginFormWidget.isReviewNumber('', '201278287168'), isTrue);
  });

  test('normal numbers never match the review allowlist', () {
    expect(
      LoginFormWidget.isReviewNumber('01000000000', '201000000000'),
      isFalse,
    );
    expect(
      LoginFormWidget.isReviewNumber('+201021070461', '+201021070461'),
      isFalse,
    );
    expect(
      LoginFormWidget.isReviewNumber('0102107046', '20102107046'),
      isFalse,
    );
    expect(LoginFormWidget.isReviewNumber('', ''), isFalse);
  });

  test('review step id and code are reserved for the local path', () {
    expect(LoginFormWidget.reviewStepId, isNotEmpty);
    expect(LoginFormWidget.reviewCode, hasLength(6));
  });
}
