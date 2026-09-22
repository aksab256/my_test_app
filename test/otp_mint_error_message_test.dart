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
}
