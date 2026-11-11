import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_test_app/widgets/home_action_buttons.dart';

void main() {
  group('home action buttons (buyer header/cart)', () {
    testWidgets('shira button renders and forwards taps', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShiraPulseButton(onTap: () => tapped++, size: 38),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // الزر نفسه مرسوم (محتوى اللوجو يعتمد على حزمة الأصول).
      expect(find.byType(ShiraPulseButton), findsOneWidget);

      await tester.tap(find.byType(ShiraPulseButton));
      await tester.pump();
      expect(tapped, 1);
    });

    testWidgets('cart button hides badge at zero and shows count otherwise',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CartFabButton(count: 0, onTap: _noop)),
        ),
      );
      expect(find.text('0'), findsNothing);
      expect(find.byIcon(Icons.shopping_cart_rounded), findsOneWidget);
    });

    testWidgets('cart button shows count and forwards taps', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CartFabButton(count: 5, onTap: () => tapped++),
          ),
        ),
      );
      expect(find.text('5'), findsOneWidget);

      await tester.tap(find.byType(CartFabButton));
      await tester.pump();
      expect(tapped, 1);
    });

    testWidgets('cart button caps large counts at 99+', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CartFabButton(count: 150, onTap: _noop)),
        ),
      );
      expect(find.text('99+'), findsOneWidget);
    });
  });
}

void _noop() {}
