import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_test_app/controllers/checkout_controller.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';

// A2: اختبار شرط التوجيه للمسار الآمن:
//   needsSecureProcessing = !isConsumer && (discountUsed > 0 || isGiftEligible)
//
// القاعدة: استدعاء secureOrdersHandler = المسار الآمن،
// وكتابة مستند مباشر في orders/consumerorders = المسار المباشر.
// يستخدم نفس الـseams الموجودة (firestore وsecureOrdersHandler) دون أي
// production seam جديد. لا يعدّل أي production code.
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
  }) =>
      {
        'productId': productId,
        'price': price,
        'quantity': quantity,
        'mainId': mainId,
        'subId': subId,
        'name': 'Item $productId',
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
    await tester.pump(const Duration(seconds: 5));
    return result;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> docsOf(
    String collection,
  ) async {
    final snap = await fake.collection(collection).get();
    return snap.docs;
  }

  group('A2: needsSecureProcessing routing', () {
    testWidgets('B2B + discount > 0 routes through the secure handler',
        (tester) async {
      await fake.collection('sellers').doc('s1').set({
        'commissionRate': 0.1,
        'phone': '01110000000',
      });
      await fake.collection('users').doc('buyer-1').set({'cashback': 30.0});

      var secureCalled = false;
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
          secureCalled = true;
          captured = payload;
          return ['srv-1'];
        },
      );

      expect(ok, isTrue);
      expect(secureCalled, isTrue);
      // المسار الآمن لا يكتب طلبات مباشرة.
      expect(await docsOf('orders'), isEmpty);
      expect(captured!['cashbackToReserve'], 30.0);
    });

    testWidgets('B2B + gift routes through the secure handler', (tester) async {
      await fake.collection('sellers').doc('s1').set({'phone': '0111'});

      var secureCalled = false;
      Map<String, dynamic>? captured;
      final ok = await runPlaceOrder(
        tester,
        buyer: buyerWithAddress('12 Test St'),
        checkoutOrders: [
          sellerOrder(
            sellerId: 's1',
            items: [
              orderItem(productId: 'p1', price: 60.0, quantity: 1),
              // سطر صفري السعر → يُعلَّم كهدية → isGiftEligible.
              orderItem(productId: 'gift-1', price: 0.0, quantity: 1),
            ],
          ),
        ],
        currentCashback: 0.0,
        useCashback: false,
        secureHandler: (payload) async {
          secureCalled = true;
          captured = payload;
          return ['srv-1'];
        },
      );

      expect(ok, isTrue);
      expect(secureCalled, isTrue);
      expect(await docsOf('orders'), isEmpty);
      expect(captured!['cashbackToReserve'], 0.0);
      final ordersData = captured!['ordersData'] as List;
      expect(ordersData, hasLength(1));
      expect(ordersData.single['isCashbackUsed'], isFalse);
      final items = ordersData.single['items'] as List;
      expect(items.any((i) => i['isGift'] == true), isTrue);
    });

    testWidgets('plain B2B order never touches the secure handler',
        (tester) async {
      await fake.collection('sellers').doc('s1').set({
        'commissionRate': 0.05,
        'phone': '0111',
      });
      // رصيد موجود لكن غير مستخدم → discountUsed = 0 ولا هدايا.
      await fake.collection('users').doc('buyer-1').set({'cashback': 40.0});

      var secureCalled = false;
      final ok = await runPlaceOrder(
        tester,
        buyer: buyerWithAddress('12 Test St'),
        checkoutOrders: [
          sellerOrder(
            sellerId: 's1',
            items: [orderItem(productId: 'p1', price: 100.0, quantity: 1)],
          ),
        ],
        currentCashback: 40.0,
        useCashback: false,
        secureHandler: (payload) async {
          secureCalled = true;
          return ['srv-should-never-happen'];
        },
      );

      expect(ok, isTrue);
      expect(secureCalled, isFalse);
      final docs = await docsOf('orders');
      expect(docs, hasLength(1));
      expect(docs.single.data()['sellerId'], 's1');
      expect(docs.single.data()['isCashbackUsed'], isFalse);
      final user =
          (await fake.collection('users').doc('buyer-1').get()).data()!;
      expect(user['cashback'], 40.0);
    });

    testWidgets('B2B + useCashback with zero balance stays on direct path',
        (tester) async {
      await fake.collection('sellers').doc('s1').set({'phone': '0111'});
      await fake.collection('users').doc('buyer-1').set({'cashback': 0.0});

      var secureCalled = false;
      final ok = await runPlaceOrder(
        tester,
        buyer: buyerWithAddress('12 Test St'),
        checkoutOrders: [
          sellerOrder(
            sellerId: 's1',
            items: [orderItem(productId: 'p1', price: 100.0, quantity: 1)],
          ),
        ],
        // العلم مرفوع لكن الرصيد صفر → discountUsed = 0 → لا مسار آمن.
        currentCashback: 0.0,
        useCashback: true,
        secureHandler: (payload) async {
          secureCalled = true;
          return ['srv-should-never-happen'];
        },
      );

      expect(ok, isTrue);
      expect(secureCalled, isFalse);
      expect(await docsOf('orders'), hasLength(1));
    });

    testWidgets('consumer + discount stays on direct path (isConsumer)',
        (tester) async {
      await fake
          .collection('deliverySupermarkets')
          .doc('sm1')
          .set({'phone': '02220000000'});
      await fake.collection('consumers').doc('c1').set({'cashbackBalance': 50.0});

      var secureCalled = false;
      final ok = await runPlaceOrder(
        tester,
        buyer: buyerWithAddress('Consumer Ave'),
        loggedUser: buyerUser(id: 'c1', role: 'consumer'),
        checkoutOrders: [
          sellerOrder(
            sellerId: 'sm1',
            sellerName: 'Corner Supermarket',
            items: [orderItem(productId: 'p1', price: 100.0, quantity: 1)],
          ),
        ],
        currentCashback: 50.0,
        useCashback: true,
        secureHandler: (payload) async {
          secureCalled = true;
          return ['srv-should-never-happen'];
        },
      );

      expect(ok, isTrue);
      expect(secureCalled, isFalse);
      expect(await docsOf('orders'), isEmpty);
      final docs = await docsOf('consumerorders');
      expect(docs, hasLength(1));
      // الخصم طُبّق مباشرة: 100 − 50 = 50، والرصيد صار صفرًا.
      expect(docs.single.data()['finalAmount'], closeTo(50.0, 1e-9));
      final consumer =
          (await fake.collection('consumers').doc('c1').get()).data()!;
      expect(consumer['cashbackBalance'], closeTo(0.0, 1e-9));
    });

    testWidgets('consumer + gift stays on direct path (isConsumer)',
        (tester) async {
      await fake
          .collection('deliverySupermarkets')
          .doc('sm1')
          .set({'phone': '02220000000'});
      await fake.collection('consumers').doc('c1').set({'cashbackBalance': 0.0});

      var secureCalled = false;
      final ok = await runPlaceOrder(
        tester,
        buyer: buyerWithAddress('Consumer Ave'),
        loggedUser: buyerUser(id: 'c1', role: 'consumer'),
        checkoutOrders: [
          sellerOrder(
            sellerId: 'sm1',
            sellerName: 'Corner Supermarket',
            items: [
              orderItem(productId: 'p1', price: 60.0, quantity: 1),
              orderItem(productId: 'gift-1', price: 0.0, quantity: 1),
            ],
          ),
        ],
        currentCashback: 0.0,
        useCashback: false,
        secureHandler: (payload) async {
          secureCalled = true;
          return ['srv-should-never-happen'];
        },
      );

      expect(ok, isTrue);
      expect(secureCalled, isFalse);
      expect(await docsOf('orders'), isEmpty);
      final docs = await docsOf('consumerorders');
      expect(docs, hasLength(1));
      final data = docs.single.data();
      // الهدية محفوظة مع الطلب، والمجموع يستبعدها: 60 − 0 = 60.
      final items = data['items'] as List;
      expect(items, hasLength(2));
      expect(items.any((i) => i['isGift'] == true), isTrue);
      expect(data['subtotalPrice'], 60.0);
      expect(data['finalAmount'], closeTo(60.0, 1e-9));
    });
  });
}
