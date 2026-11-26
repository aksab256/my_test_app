// test/buyer_bundle_widgets_test.dart
//
// Buyer bundle storefront widgets (no Firebase, no network):
// - BundleHomeHero: wide peeking cards + view-all entry point.
// - AllBundlesScreen: magazine layout grouped by seller (injected bundles).
// - BundleDetailsScreen: components, net price, and terms display.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_test_app/models/bundle_model.dart';
import 'package:my_test_app/screens/buyer/all_bundles_screen.dart';
import 'package:my_test_app/screens/buyer/bundle_details_screen.dart';
import 'package:my_test_app/widgets/bundle_home_hero.dart';

SellerBundleModel testBundle({
  String id = 'b1',
  String sellerId = 's1',
  String sellerName = 'Seller One',
  double price = 1500.0,
  double original = 2000.0,
  int sellable = 5,
  List<String> zones = const [],
}) {
  return SellerBundleModel(
    id: id,
    sellerId: sellerId,
    bundleName: 'Bundle $id',
    items: const [
      BundleItemModel(
        offerId: 'p1',
        productId: 'p1',
        productName: 'Product A',
        unitName: 'piece',
        qtyRequired: 2,
        priceSnapshot: 500.0,
      ),
      BundleItemModel(
        offerId: 'p2',
        productId: 'p2',
        productName: 'Product B',
        unitName: 'pack',
        qtyRequired: 1,
        priceSnapshot: 1000.0,
      ),
    ],
    totalPrice: price,
    originalTotal: original,
    sellerName: sellerName,
    remainingCount: sellable,
    deliveryZones: zones,
  );
}

void main() {
  group('BundleHomeHero (wide peeking cards)', () {
    testWidgets('renders one wide card per bundle with saving', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BundleHomeHero(bundles: [testBundle(), testBundle(id: 'b2')]),
          ),
        ),
      );
      expect(find.byKey(const Key('bundle-hero-b1')), findsOneWidget);
      expect(find.byKey(const Key('bundle-hero-b2')), findsOneWidget);
      expect(find.textContaining('500'), findsWidgets);
    });

    testWidgets('view-all button and card tap route outward', (tester) async {
      String? opened;
      var viewAll = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BundleHomeHero(
              bundles: [testBundle()],
              onOpen: (b) => opened = b.id,
              onViewAll: () => viewAll = true,
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('bundles-view-all')));
      expect(viewAll, isTrue);
      await tester.tap(find.byKey(const Key('bundle-hero-b1')));
      expect(opened, 'b1');
    });

    testWidgets('empty list renders nothing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BundleHomeHero(bundles: []))),
      );
      expect(find.text('باقات مميزة'), findsNothing);
    });
  });

  group('AllBundlesScreen (magazine grouped by seller)', () {
    testWidgets('groups bundles under each seller header', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AllBundlesScreen(bundles: [
            testBundle(id: 'b1', sellerId: 's1', sellerName: 'Seller One'),
            testBundle(id: 'b2', sellerId: 's1', sellerName: 'Seller One'),
            testBundle(id: 'b3', sellerId: 's2', sellerName: 'Seller Two'),
          ]),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Seller One'), findsOneWidget);
      expect(find.text('Seller Two'), findsOneWidget);
      expect(find.byKey(const Key('bundle-card-b1')), findsOneWidget);
      expect(find.byKey(const Key('bundle-card-b2')), findsOneWidget);
      expect(find.byKey(const Key('bundle-card-b3')), findsOneWidget);
    });

    testWidgets('empty state mentions region', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AllBundlesScreen(bundles: [])),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('منطقتك'), findsOneWidget);
    });
  });

  group('BundleDetailsScreen (components + price + terms)', () {
    testWidgets('shows components with quantities and terms note', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: BundleDetailsScreen(bundle: testBundle())),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bundle-component-p1-0')), findsOneWidget);
      expect(find.byKey(const Key('bundle-component-p2-0')), findsOneWidget);
      expect(find.textContaining('1500'), findsWidgets);
      expect(find.textContaining('الحجز يتم'), findsNothing);
      expect(find.textContaining('جميع المناطق'), findsOneWidget);
      expect(find.textContaining('السعر الأصلي'), findsWidgets);
      expect(find.textContaining('التقريبي'), findsNothing);
      expect(find.byKey(const Key('bundle-add-to-cart')), findsOneWidget);
    });

    testWidgets('shows seller zones in terms when present', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
            home: BundleDetailsScreen(
                bundle: testBundle(zones: const ['Nasr']))),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Nasr'), findsWidgets);
    });
  });
}
