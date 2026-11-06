import 'package:flutter_test/flutter_test.dart';
import 'package:my_test_app/screens/auth/new_client_screen.dart';
import 'package:my_test_app/screens/buyer/buyer_home_screen.dart';
import 'package:my_test_app/screens/consumer/consumer_home_screen.dart';
import 'package:my_test_app/screens/seller_screen.dart';

void main() {
  test('active registrations auto sign in, pending stays waiting', () {
    expect(
      NewClientScreen.shouldAutoSignInAfterRegister(status: 'active'),
      isTrue,
    );
    expect(
      NewClientScreen.shouldAutoSignInAfterRegister(status: 'pending'),
      isFalse,
    );
    expect(
      NewClientScreen.shouldAutoSignInAfterRegister(status: ''),
      isFalse,
    );
  });

  test('seller without approval never auto signs in', () {
    // Seller registers via request-only (no OTP) with pending status.
    expect(
      NewClientScreen.shouldAutoSignInAfterRegister(status: 'pending'),
      isFalse,
    );
    expect(
      NewClientScreen.registerHomeRoute('seller'),
      SellerScreen.routeName,
    );
  });

  test('registration routes mirror login home mapping', () {
    expect(
      NewClientScreen.registerHomeRoute('buyer'),
      BuyerHomeScreen.routeName,
    );
    expect(
      NewClientScreen.registerHomeRoute('consumer'),
      ConsumerHomeScreen.routeName,
    );
    expect(
      NewClientScreen.registerHomeRoute('seller'),
      SellerScreen.routeName,
    );
    expect(
      NewClientScreen.registerHomeRoute('unknown'),
      SellerScreen.routeName,
    );
  });
}
