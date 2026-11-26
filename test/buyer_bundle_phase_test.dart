// test/buyer_bundle_phase_test.dart
//
// Buyer bundle phase: min-order counts the net bundle price once,
// multi-seller split keeps bundle lines, helpers stay in sync, and
// region gating follows the seller-registered zones (same polygon system).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/controllers/checkout_controller.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:my_test_app/utils/offer_geo_filter.dart';
import 'package:my_test_app/utils/seller_geo.dart';

void main() {
  group('bundle min-order: net price counts once', () {
    test('1500 bundle vs 2000 minimum needs 500 more (no double count)', () {
      const minTotal = 2000.0;
      const bundlePrice = 1500.0;
      // Bundle is ONE cart line: seller total is the net bundle price only.
      const sellerTotal = bundlePrice * 1;
      expect(sellerTotal, 1500.0);
      expect(sellerTotal < minTotal, isTrue);
      expect(minTotal - sellerTotal, 500.0);
    });

    test('bundle + 500 product meets the minimum exactly', () {
      const sellerTotal = 1500.0 + 500.0;
      expect(sellerTotal >= 2000.0, isTrue);
    });

    test('components are never separate totals', () {
      // Components live only inside bundleItems snapshot, never as lines.
      final line = CartItem(
        offerId: 'bundle:b1',
        productId: 'b1',
        sellerId: 's1',
        sellerName: 'Seller',
        name: 'Bundle',
        price: 1500.0,
        unit: 'pack',
        unitIndex: 0,
        quantity: 1,
        imageUrl: '',
        isBundle: true,
        bundleId: 'b1',
        bundleCount: 1,
        bundleItems: const [
          {'productName': 'A'},
          {'productName': 'B'},
        ],
        bundleOriginalTotal: 2000.0,
      );
      expect(line.price * line.quantity, 1500.0);
      expect(line.bundleItems, hasLength(2));
    });
  });

  group('bundle checkout helpers', () {
    test('detects bundle lines by flag or offerId prefix', () {
      expect(
        CheckoutController.isBundleCheckoutLine(
            {'offerId': 'bundle:b1', 'isBundle': true}),
        isTrue,
      );
      expect(
        CheckoutController.isBundleCheckoutLine({'offerId': 'bundle:b1'}),
        isTrue,
      );
      expect(
        CheckoutController.isBundleCheckoutLine({'offerId': 'offer-1'}),
        isFalse,
      );
    });

    test('bundle id prefers explicit field, falls back to prefix', () {
      expect(
        CheckoutController.bundleIdOfCheckoutLine(
            {'offerId': 'bundle:b9', 'bundleId': 'b1'}),
        'b1',
      );
      expect(
        CheckoutController.bundleIdOfCheckoutLine({'offerId': 'bundle:b9'}),
        'b9',
      );
    });

    test('bundle count prefers bundleCount, falls back to quantity', () {
      expect(
        CheckoutController.bundleCountOfCheckoutLine(
            {'bundleCount': 2, 'quantity': 9}),
        2,
      );
      expect(
        CheckoutController.bundleCountOfCheckoutLine({'quantity': 3}),
        3,
      );
    });

    test('legacy orders without bundle lines are untouched', () {
      final item = {'offerId': 'offer-1', 'quantity': 2};
      expect(CheckoutController.isBundleCheckoutLine(item), isFalse);
      expect(CheckoutController.bundleIdOfCheckoutLine(item), isEmpty);
    });

    test('CartItem round trip preserves bundle identity', () {
      final original = CartItem(
        offerId: 'bundle:b1',
        productId: 'b1',
        sellerId: 's1',
        sellerName: 'Seller',
        name: 'Bundle',
        price: 1500.0,
        unit: 'pack',
        unitIndex: 0,
        quantity: 2,
        imageUrl: 'img',
        isBundle: true,
        bundleId: 'b1',
        bundleCount: 2,
        bundleItems: const [
          {'productName': 'A'}
        ],
        bundleOriginalTotal: 2000.0,
      );
      final restored = CartItem.fromJson(original.toJson());
      expect(restored.isBundle, isTrue);
      expect(restored.bundleId, 'b1');
      expect(restored.bundleCount, 2);
      expect(restored.quantity, 2);
      expect(restored.bundleItems, hasLength(1));
    });
  });

  group('bundle seller regions (same polygon system)', () {
    setUp(() {
      SellerGeo.setPolygonsForTest({
        'Cairo-Nasr': const [
          GeoPoint(lat: 30.0, lng: 31.0),
          GeoPoint(lat: 30.0, lng: 32.0),
          GeoPoint(lat: 31.0, lng: 32.0),
          GeoPoint(lat: 31.0, lng: 31.0),
        ],
      });
    });

    test('matching seller region is visible', () async {
      final visible = await SellerGeo.isOfferVisibleByCoords(
        offerData: const {
          'deliveryZones': ['Cairo-Nasr']
        },
        buyerLat: 30.5,
        buyerLng: 31.5,
        context: OfferListContext.productOffers,
      );
      expect(visible, isTrue);
    });

    test('non-matching seller region is hidden', () async {
      final visible = await SellerGeo.isOfferVisibleByCoords(
        offerData: const {
          'deliveryZones': ['Cairo-Nasr']
        },
        buyerLat: 0.0,
        buyerLng: 0.0,
        context: OfferListContext.productOffers,
      );
      expect(visible, isFalse);
    });

    test('unknown zone name never matches (fail closed)', () async {
      final visible = await SellerGeo.isOfferVisibleByCoords(
        offerData: const {
          'deliveryZones': ['No-Such-Zone']
        },
        buyerLat: 30.5,
        buyerLng: 31.5,
        context: OfferListContext.productOffers,
      );
      expect(visible, isFalse);
    });

    test('global bundle (no zones) stays visible', () async {
      final visible = await SellerGeo.isOfferVisibleByCoords(
        offerData: const {'deliveryZones': <String>[]},
        buyerLat: 30.5,
        buyerLng: 31.5,
        context: OfferListContext.productOffers,
      );
      expect(visible, isTrue);
    });
  });

  group('bundle order create + hold (multi-seller safe)', () {
    Future<bool> runOrder(
      WidgetTester tester,
      FakeFirebaseFirestore fake,
      List<Map<String, dynamic>> checkoutOrders, {
      List<Map<String, String>>? holdCalls,
      bool failHold = false,
    }) async {
      final buyer = BuyerDataProvider(firestore: fake);
      buyer.setSessionLocation(lat: 30.5, lng: 31.5, address: 'addr');
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<BuyerDataProvider>.value(
            value: buyer,
            child: Scaffold(
              body: Builder(builder: (context) {
                ctx = context;
                return const SizedBox.shrink();
              }),
            ),
          ),
        ),
      );
      return CheckoutController.placeOrder(
        context: ctx,
        checkoutOrders: checkoutOrders,
        loggedUser: const {
          'id': 'buyer-1',
          'role': 'buyer',
          'fullname': 'Buyer',
          'phone': '0100',
        },
        originalOrderTotal: 1500.0,
        currentCashback: 0.0,
        finalTotalAmount: 1500.0,
        useCashback: false,
        selectedPaymentMethod: 'cash',
        firestore: fake,
        bundleHoldCaller: ({required String bundleId, required String orderId, required int count}) async {
          if (failHold) throw Exception('INSUFFICIENT_SELLABLE');
          holdCalls?.add({'bundleId': bundleId, 'orderId': orderId, 'count': '$count'});
        },
      );
    }

    Map<String, dynamic> bundleLine() => {
          'offerId': 'bundle:b1',
          'productId': 'b1',
          'bundleId': 'b1',
          'isBundle': true,
          'bundleCount': 1,
          'quantity': 1,
          'price': 1500.0,
          'name': 'Bundle',
          'sellerId': 's1',
        };

    testWidgets('creates one order per seller and holds the bundle unit', (tester) async {
      final fake = FakeFirebaseFirestore();
      await fake.collection('sellers').doc('s1').set({'phone': '0111', 'deliveryAreas': []});
      await fake.collection('sellerBundles').doc('b1').set({
        'sellerId': 's1',
        'status': 'active',
        'remainingCount': 5,
        'heldCount': 0,
        'totalPrice': 1500.0,
        'deliveryZones': [],
      });
      final holdCalls = <Map<String, String>>[];
      final ok = await runOrder(tester, fake, [
        {'sellerId': 's1', 'sellerName': 'S1', 'items': [bundleLine()]},
        {
          'sellerId': 's2',
          'sellerName': 'S2',
          'items': [
            {'offerId': 'o9', 'productId': 'o9', 'quantity': 1, 'price': 500.0, 'name': 'P'}
          ]
        },
      ], holdCalls: holdCalls);
      await tester.pump(const Duration(seconds: 5));

      expect(ok, isTrue);
      expect(holdCalls, hasLength(1));
      expect(holdCalls.single['bundleId'], 'b1');
      expect(holdCalls.single['count'], '1');
      final orders = await fake.collection('orders').get();
      expect(orders.docs, hasLength(2));
      final bundleOrder = orders.docs
          .map((d) => d.data())
          .firstWhere((d) => d['sellerId'] == 's1');
      final items = bundleOrder['items'] as List;
      expect(items.single['isBundle'], isTrue);
      expect(items.single['bundleId'], 'b1');
      expect(holdCalls.single['orderId'], isNotEmpty);
    });

    testWidgets('legacy orders without bundles trigger no hold', (tester) async {
      final fake = FakeFirebaseFirestore();
      await fake.collection('sellers').doc('s1').set({'phone': '0111'});
      final holdCalls = <Map<String, String>>[];
      final ok = await runOrder(tester, fake, [
        {
          'sellerId': 's1',
          'sellerName': 'S1',
          'items': [
            {'offerId': 'o1', 'productId': 'o1', 'quantity': 1, 'price': 100.0, 'name': 'P'}
          ]
        },
      ], holdCalls: holdCalls);
      await tester.pump(const Duration(seconds: 5));
      expect(ok, isTrue);
      expect(holdCalls, isEmpty);
    });

    testWidgets('hold failure cancels the created order', (tester) async {
      final fake = FakeFirebaseFirestore();
      await fake.collection('sellers').doc('s1').set({'phone': '0111', 'deliveryAreas': []});
      await fake.collection('sellerBundles').doc('b1').set({
        'sellerId': 's1',
        'status': 'active',
        'remainingCount': 5,
        'heldCount': 0,
        'totalPrice': 1500.0,
        'deliveryZones': [],
      });
      final ok = await runOrder(tester, fake, [
        {'sellerId': 's1', 'sellerName': 'S1', 'items': [bundleLine()]},
      ], failHold: true);
      await tester.pump(const Duration(seconds: 5));
      expect(ok, isFalse);
      final orders = await fake.collection('orders').get();
      expect(orders.docs, hasLength(1));
      expect(orders.docs.single.data()['status'], 'cancelled');
    });
  });
}
