import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_test_app/controllers/checkout_controller.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';

void main() {
  late FakeFirebaseFirestore fake;

  setUp(() {
    fake = FakeFirebaseFirestore();
  });

  Map<String, dynamic> buyerUser({
    String id = 'buyer-1',
    String role = 'buyer',
  }) =>
      {
        'id': id,
        'role': role,
        'fullname': 'Test Buyer',
        'phone': '01000000000',
        'email': 'buyer@test.com',
      };

  Map<String, dynamic> orderItem({
    required String productId,
    required double price,
    required int quantity,
    String mainId = 'm1',
    String subId = 's1',
    bool isDeliveryFee = false,
  }) =>
      {
        'productId': productId,
        'price': price,
        'quantity': quantity,
        'mainId': mainId,
        'subId': subId,
        'name': 'Item $productId',
        if (isDeliveryFee) 'isDeliveryFee': true,
      };

  Map<String, dynamic> sellerOrder({
    required String sellerId,
    String sellerName = 'Seller',
    required List<Map<String, dynamic>> items,
  }) =>
      {
        'sellerId': sellerId,
        'sellerName': sellerName,
        'items': items,
      };

  BuyerDataProvider buyerWithAddress(
    String address, {
    double lat = 30.0,
    double lng = 31.0,
  }) {
    final buyer = BuyerDataProvider(firestore: fake);
    buyer.setSessionLocation(lat: lat, lng: lng, address: address);
    return buyer;
  }

  /// Pumps a minimal tree (Provider + Scaffold) and runs [CheckoutController.placeOrder].
  Future<bool> runPlaceOrder(
    WidgetTester tester, {
    required BuyerDataProvider buyer,
    List<Map<String, dynamic>> checkoutOrders = const [],
    Map<String, dynamic>? loggedUser,
    double originalOrderTotal = 0,
    double currentCashback = 0,
    double finalTotalAmount = 0,
    bool useCashback = false,
    dynamic selectedPaymentMethod = 'cash',
    Future<List<String>> Function(Map<String, dynamic> payload)? secureHandler,
  }) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<BuyerDataProvider>.value(
          value: buyer,
          child: Scaffold(
            body: Builder(
              builder: (context) {
                ctx = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );

    final result = await CheckoutController.placeOrder(
      context: ctx,
      checkoutOrders: checkoutOrders,
      loggedUser: loggedUser ?? buyerUser(),
      originalOrderTotal: originalOrderTotal,
      currentCashback: currentCashback,
      finalTotalAmount: finalTotalAmount,
      useCashback: useCashback,
      selectedPaymentMethod: selectedPaymentMethod,
      firestore: fake,
      secureOrdersHandler: secureHandler,
    );
    // Let success/error SnackBars settle so no timers leak between tests.
    await tester.pump(const Duration(seconds: 5));
    return result;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> docsOf(
    String collection,
  ) async {
    final snap = await fake.collection(collection).get();
    return snap.docs;
  }

  group('placeOrder validation', () {
    testWidgets('rejects an empty checkout list', (tester) async {
      final ok = await runPlaceOrder(
        tester,
        buyer: buyerWithAddress('12 Test St'),
        checkoutOrders: const [],
      );

      expect(ok, isFalse);
      expect(await docsOf('orders'), isEmpty);
    });

    testWidgets('rejects a logged user without an id', (tester) async {
      final user = buyerUser()..remove('id');

      final ok = await runPlaceOrder(
        tester,
        buyer: buyerWithAddress('12 Test St'),
        checkoutOrders: [
          sellerOrder(
            sellerId: 's1',
            items: [orderItem(productId: 'p1', price: 50.0, quantity: 1)],
          ),
        ],
        loggedUser: user,
      );

      expect(ok, isFalse);
      expect(await docsOf('orders'), isEmpty);
    });

    testWidgets('rejects when no delivery address is available',
        (tester) async {
      // Fresh provider: neither a session location nor a stored address.
      final ok = await runPlaceOrder(
        tester,
        buyer: BuyerDataProvider(firestore: fake),
        checkoutOrders: [
          sellerOrder(
            sellerId: 's1',
            items: [orderItem(productId: 'p1', price: 50.0, quantity: 1)],
          ),
        ],
      );

      expect(ok, isFalse);
      expect(await docsOf('orders'), isEmpty);
    });
  });

  group('placeOrder buyer direct path (cash, no promos)', () {
    testWidgets('creates an order with core buyer data', (tester) async {
      await fake.collection('sellers').doc('s1').set({
        'commissionRate': 0.1,
        'phone': '01110000000',
      });

      final ok = await runPlaceOrder(
        tester,
        buyer: buyerWithAddress('12 Test St'),
        checkoutOrders: [
          sellerOrder(
            sellerId: 's1',
            sellerName: 'Fresh Market',
            items: [orderItem(productId: 'p1', price: 50.0, quantity: 2)],
          ),
        ],
      );

      expect(ok, isTrue);
      final docs = await docsOf('orders');
      expect(docs, hasLength(1));
      final data = docs.single.data();
      expect(data['sellerId'], 's1');
      expect(data['sellerPhone'], '01110000000');
      expect(data['total'], 100.0);
      expect(data['status'], 'new-order');
      expect(data['paymentMethod'], 'cash');
      expect(data['commissionRate'], 0.1);
      expect(data['isCashbackUsed'], isFalse);
      expect(data['isFinancialSettled'], isFalse);
      expect(data['isCommissionProcessed'], isFalse);
      // Backfilled with the generated document id.
      expect(data['orderId'], docs.single.id);
      // Buyer block carries identity + location.
      expect(data['buyer']['id'], 'buyer-1');
      expect(data['buyer']['name'], 'Test Buyer');
      expect(data['buyer']['phone'], '01000000000');
      expect(data['buyer']['address'], '12 Test St');
      expect(data['buyer']['lat'], 30.0);
      expect(data['buyer']['lng'], 31.0);
      // Item category ids are mirrored for downstream queries.
      final items = data['items'] as List;
      expect(items, hasLength(1));
      expect(items.single['mainCategoryId'], 'm1');
      expect(items.single['subCategoryId'], 's1');
    });

    testWidgets('drops the delivery-fee line for buyers', (tester) async {
      await fake.collection('sellers').doc('s1').set({'phone': '0111'});

      final ok = await runPlaceOrder(
        tester,
        buyer: buyerWithAddress('12 Test St'),
        checkoutOrders: [
          sellerOrder(
            sellerId: 's1',
            items: [
              orderItem(productId: 'p1', price: 50.0, quantity: 1),
              orderItem(
                productId: 'DELIVERY_FEE',
                price: 15.0,
                quantity: 1,
                isDeliveryFee: true,
              ),
            ],
          ),
        ],
      );

      expect(ok, isTrue);
      final docs = await docsOf('orders');
      expect(docs, hasLength(1));
      final data = docs.single.data();
      expect(data['total'], 50.0);
      final items = data['items'] as List;
      expect(items, hasLength(1));
      expect(items.single['productId'], 'p1');
    });

    testWidgets('defaults a missing seller commission rate to zero',
        (tester) async {
      await fake.collection('sellers').doc('s2').set({'phone': '0222'});

      final ok = await runPlaceOrder(
        tester,
        buyer: buyerWithAddress('12 Test St'),
        checkoutOrders: [
          sellerOrder(
            sellerId: 's2',
            items: [orderItem(productId: 'p1', price: 20.0, quantity: 1)],
          ),
        ],
      );

      expect(ok, isTrue);
      final docs = await docsOf('orders');
      expect(docs.single.data()['commissionRate'], 0.0);
    });

    testWidgets('writes one order per seller with split totals',
        (tester) async {
      await fake.collection('sellers').doc('s1').set({'commissionRate': 0.05});
      await fake.collection('sellers').doc('s2').set({'commissionRate': 0.2});

      final ok = await runPlaceOrder(
        tester,
        buyer: buyerWithAddress('12 Test St'),
        checkoutOrders: [
          sellerOrder(
            sellerId: 's1',
            items: [orderItem(productId: 'p1', price: 100.0, quantity: 1)],
          ),
          sellerOrder(
            sellerId: 's2',
            items: [orderItem(productId: 'p2', price: 50.0, quantity: 2)],
          ),
        ],
      );

      expect(ok, isTrue);
      final docs = await docsOf('orders');
      expect(docs, hasLength(2));
      final bySeller = {for (final d in docs) d.data()['sellerId']: d.data()};
      expect(bySeller['s1']!['total'], 100.0);
      expect(bySeller['s2']!['total'], 100.0);
    });

    testWidgets('ignores an untouched cashback balance when not used',
        (tester) async {
      await fake.collection('sellers').doc('s1').set({});
      await fake.collection('users').doc('buyer-1').set({'cashback': 30.0});

      final ok = await runPlaceOrder(
        tester,
        buyer: buyerWithAddress('12 Test St'),
        checkoutOrders: [
          sellerOrder(
            sellerId: 's1',
            items: [orderItem(productId: 'p1', price: 40.0, quantity: 1)],
          ),
        ],
        currentCashback: 30.0,
        useCashback: false,
      );

      expect(ok, isTrue);
      final docs = await docsOf('orders');
      expect(docs.single.data()['isCashbackUsed'], isFalse);
      expect(docs.single.data()['insurance_points'], 0.0);
      final user =
          (await fake.collection('users').doc('buyer-1').get()).data()!;
      expect(user['cashback'], 30.0);
    });
  });

  group('placeOrder secure path (gift / buyer cashback)', () {
    testWidgets('routes a gifted item through the server handler',
        (tester) async {
      await fake.collection('sellers').doc('s1').set({'phone': '0111'});

      Map<String, dynamic>? captured;
      final ok = await runPlaceOrder(
        tester,
        buyer: buyerWithAddress('12 Test St'),
        checkoutOrders: [
          sellerOrder(
            sellerId: 's1',
            items: [
              orderItem(productId: 'p1', price: 60.0, quantity: 1),
              // Zero-price lines are auto-flagged as gifts,
              // which forces secure processing for buyers.
              orderItem(productId: 'gift-1', price: 0.0, quantity: 1),
            ],
          ),
        ],
        secureHandler: (payload) async {
          captured = payload;
          return ['srv-1'];
        },
      );

      expect(ok, isTrue);
      // No direct Firestore order writes on the secure path.
      expect(await docsOf('orders'), isEmpty);
      expect(captured, isNotNull);
      expect(captured!['userId'], 'buyer-1');
      expect(captured!['action'], 'lock_assets');
      expect(captured!['cashbackToReserve'], 0.0);
      expect(captured!['total_insurance_points'], 0.0);
      final ordersData = captured!['ordersData'] as List;
      expect(ordersData, hasLength(1));
      expect(ordersData.single['sellerId'], 's1');
      expect(ordersData.single['isCashbackUsed'], isFalse);
      expect(ordersData.single['status'], 'new-order');
    });

    testWidgets('reserves buyer cashback server-side without a direct update',
        (tester) async {
      await fake.collection('sellers').doc('s1').set({'commissionRate': 0.1});
      await fake.collection('users').doc('buyer-1').set({'cashback': 30.0});

      Map<String, dynamic>? captured;
      final ok = await runPlaceOrder(
        tester,
        buyer: buyerWithAddress('12 Test St'),
        checkoutOrders: [
          sellerOrder(
            sellerId: 's1',
            items: [orderItem(productId: 'p1', price: 100.0, quantity: 1)],
          ),
        ],
        currentCashback: 30.0,
        useCashback: true,
        secureHandler: (payload) async {
          captured = payload;
          return ['srv-1'];
        },
      );

      expect(ok, isTrue);
      expect(captured!['cashbackToReserve'], 30.0);
      final ordersData = captured!['ordersData'] as List;
      expect(ordersData.single['cashbackApplied'], 30.0);
      expect(ordersData.single['insurance_points'], 30.0);
      expect(ordersData.single['isCashbackUsed'], isTrue);
      // The server owns the deduction: no direct user update happens here.
      expect(await docsOf('orders'), isEmpty);
      final user =
          (await fake.collection('users').doc('buyer-1').get()).data()!;
      expect(user['cashback'], 30.0);
    });

    testWidgets('returns false when the server call fails', (tester) async {
      await fake.collection('sellers').doc('s1').set({});

      final ok = await runPlaceOrder(
        tester,
        buyer: buyerWithAddress('12 Test St'),
        checkoutOrders: [
          sellerOrder(
            sellerId: 's1',
            items: [orderItem(productId: 'p1', price: 100.0, quantity: 1)],
          ),
        ],
        currentCashback: 10.0,
        useCashback: true,
        secureHandler: (_) async => throw Exception('server down'),
      );

      expect(ok, isFalse);
    });
  });

  group('placeOrder consumer path', () {
    testWidgets(
        'writes to consumerorders, keeps the delivery fee, and deducts '
        'cashbackBalance', (tester) async {
      await fake
          .collection('deliverySupermarkets')
          .doc('sm1')
          .set({'phone': '02220000000'});
      await fake.collection('consumers').doc('c1').set({'cashbackBalance': 50.0});

      final ok = await runPlaceOrder(
        tester,
        buyer: buyerWithAddress('Consumer Ave'),
        loggedUser: buyerUser(id: 'c1', role: 'consumer'),
        checkoutOrders: [
          sellerOrder(
            sellerId: 'sm1',
            sellerName: 'Corner Supermarket',
            items: [
              orderItem(productId: 'p1', price: 100.0, quantity: 1),
              orderItem(
                productId: 'DELIVERY_FEE',
                price: 10.0,
                quantity: 1,
                isDeliveryFee: true,
              ),
            ],
          ),
        ],
        currentCashback: 50.0,
        useCashback: true,
      );

      expect(ok, isTrue);
      // Consumer orders land in their own collection.
      expect(await docsOf('orders'), isEmpty);
      final docs = await docsOf('consumerorders');
      expect(docs, hasLength(1));
      final data = docs.single.data();
      expect(data['customerId'], 'c1');
      expect(data['supermarketId'], 'sm1');
      expect(data['supermarketName'], 'Corner Supermarket');
      // Consumer phone comes from deliverySupermarkets, not sellers.
      expect(data['supermarketPhone'], '02220000000');
      expect(data['status'], 'new-order');
      expect(data['paymentMethod'], 'cash');
      // Delivery fee is retained for consumers: subtotal 110,
      // discount pro-rated to 55, final 55.
      expect(data['subtotalPrice'], 110.0);
      expect(data['finalAmount'], closeTo(55.0, 1e-9));
      final items = data['items'] as List;
      expect(items, hasLength(2));
      expect(data['deliveryLocation']['isGpsLocation'], isTrue);
      // Role-specific cashback field is deducted directly.
      final consumer =
          (await fake.collection('consumers').doc('c1').get()).data()!;
      expect(consumer['cashbackBalance'], 0.0);
    });

    testWidgets('caps the discount at the order total', (tester) async {
      await fake.collection('deliverySupermarkets').doc('sm1').set({});
      await fake
          .collection('consumers')
          .doc('c1')
          .set({'cashbackBalance': 100.0});

      final ok = await runPlaceOrder(
        tester,
        buyer: buyerWithAddress('Consumer Ave'),
        loggedUser: buyerUser(id: 'c1', role: 'consumer'),
        checkoutOrders: [
          sellerOrder(
            sellerId: 'sm1',
            items: [orderItem(productId: 'p1', price: 40.0, quantity: 1)],
          ),
        ],
        currentCashback: 100.0,
        useCashback: true,
      );

      expect(ok, isTrue);
      final docs = await docsOf('consumerorders');
      expect(docs.single.data()['finalAmount'], 0.0);
      final consumer =
          (await fake.collection('consumers').doc('c1').get()).data()!;
      expect(consumer['cashbackBalance'], 60.0);
    });
  });
}
