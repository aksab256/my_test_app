// test/recently_added_carousel_test.dart
//
// RecentlyAdded section on the buyer home (no Firebase, no network):
// - renders one card per item with name + price + seller.
// - card tap routes outward with the item payload.
// - empty list renders nothing (no title, no space).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_test_app/widgets/recently_added_carousel.dart';

Map<String, dynamic> recentItem({
  String offerId = 'o1',
  String productId = 'p1',
  String name = 'زيت شطارة',
  double price = 1020.0,
  String seller = 'Test Seller Store',
}) {
  return {
    'offerId': offerId,
    'productId': productId,
    'productName': name,
    'price': price,
    'sellerName': seller,
  };
}

void main() {
  group('RecentlyAddedCarousel', () {
    testWidgets('renders one card per item with price', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecentlyAddedCarousel(items: [
              recentItem(),
              recentItem(offerId: 'o2', name: 'سكر', price: 500.0),
            ]),
          ),
        ),
      );
      expect(find.text('أضيف حديثًا'), findsOneWidget);
      expect(find.byKey(const Key('recent-item-o1')), findsOneWidget);
      expect(find.byKey(const Key('recent-item-o2')), findsOneWidget);
      expect(find.textContaining('1020'), findsOneWidget);
      expect(find.textContaining('500'), findsOneWidget);
      expect(find.textContaining('ج.م'), findsWidgets);
    });

    testWidgets('card tap routes outward with the item', (tester) async {
      Map<String, dynamic>? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecentlyAddedCarousel(
              items: [recentItem()],
              onOpen: (m) => opened = m,
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('recent-item-o1')));
      expect(opened?['offerId'], 'o1');
      expect(opened?['productId'], 'p1');
    });

    testWidgets('empty list renders nothing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
            home: Scaffold(body: RecentlyAddedCarousel(items: []))),
      );
      expect(find.text('أضيف حديثًا'), findsNothing);
    });

    testWidgets('horizontal scroll stays responsive over frames',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecentlyAddedCarousel(
              items: List.generate(
                8,
                (i) => recentItem(
                  offerId: 'o$i',
                  name: 'منتج $i',
                  price: 100.0 + i,
                ),
              ),
            ),
          ),
        ),
      );
      final list = find.byType(Scrollable);
      expect(list, findsOneWidget);
      final stopwatch = Stopwatch()..start();
      await tester.fling(list, const Offset(-300, 0), 800);
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(10000));
      expect(find.text('أضيف حديثًا'), findsOneWidget);
    });
  });
}
