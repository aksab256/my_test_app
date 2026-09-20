import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_test_app/controllers/checkout_controller.dart';
import 'package:my_test_app/models/consumer_order_model.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';

// A5: DELIVERY_FEE filtering.
//
// القاعدة الذهبية هنا: سطر الرسوم الذي ينتجه proceedToCheckout فعليًا هو
// {productId: 'DELIVERY_FEE', quantity: 1} WITHOUT أي 'isDeliveryFee' flag،
// لأن CartItem.toJson() لا يصدّر هذا المفتاح. لذلك:
// - fixtures "production-shaped" (بدون flag) هي المرجع لسلوك الإنتاج.
// - fixtures "flagged" توثّق شكلًا مختلفًا موجودًا في الكود فقط.
// الاختبارات المعلّمة CHARACTERIZATION توثّق السلوك الحالي دون تثبيته
// كـbehavior مرغوب، وبعضها يحتاج قرار business (D1).
// يستخدم الـfirestore seam الموجود فقط، دون أي production change.
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

  /// سطر رسوم بشكل الإنتاج الحقيقي: productId فقط، وبدون أي flag
  /// ما لم يُطلب صراحةً (legacy/test shape).
  Map<String, dynamic> feeLine(double price, {bool flagged = false}) => {
        'productId': 'DELIVERY_FEE',
        'price': price,
        'quantity': 1,
        'mainId': 'm1',
        'subId': 's1',
        'name': 'رسوم التوصيل',
        if (flagged) 'isDeliveryFee': true,
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

  group('A5: DELIVERY_FEE filtering', () {
    testWidgets('consumer production-shaped fee (no flag) is kept in the order',
        (tester) async {
      await fake
          .collection('deliverySupermarkets')
          .doc('sm1')
          .set({'phone': '02220000000'});
      await fake.collection('consumers').doc('c1').set({'cashbackBalance': 0.0});

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
              feeLine(10.0),
            ],
          ),
        ],
      );

      expect(ok, isTrue);
      final docs = await docsOf('consumerorders');
      expect(docs, hasLength(1));
      final data = docs.single.data();
      // السطر لا يختفي بسبب غياب الـflag، ويدخل الحساب: 100 + 10.
      final items = data['items'] as List;
      expect(items, hasLength(2));
      expect(
        items.where((i) => i['productId'] == 'DELIVERY_FEE'),
        hasLength(1),
      );
      expect(data['subtotalPrice'], 110.0);
      expect(data['finalAmount'], 110.0);
      // لا سكالر deliveryFee في مستند الإنتاج (مسار fallback الموديل).
      expect(data['deliveryFee'], isNull);
    });

    testWidgets(
        'CHARACTERIZATION (needs business D1): consumer production-shaped '
        'fee is inside the cashback base', (tester) async {
      await fake
          .collection('deliverySupermarkets')
          .doc('sm1')
          .set({'phone': '02220000000'});
      await fake
          .collection('consumers')
          .doc('c1')
          .set({'cashbackBalance': 55.0});

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
              feeLine(10.0),
            ],
          ),
        ],
        // السلوك الحالي: القاعدة 110 (شاملة الرسوم) → الخصم 55.
        currentCashback: 55.0,
        useCashback: true,
      );

      expect(ok, isTrue);
      final docs = await docsOf('consumerorders');
      expect(docs.single.data()['finalAmount'], closeTo(55.0, 1e-9));
      final consumer =
          (await fake.collection('consumers').doc('c1').get()).data()!;
      expect(consumer['cashbackBalance'], closeTo(0.0, 1e-9));
    });

    testWidgets('flagged fee (legacy shape) is excluded from the cashback base',
        (tester) async {
      await fake
          .collection('deliverySupermarkets')
          .doc('sm1')
          .set({'phone': '02220000000'});
      await fake
          .collection('consumers')
          .doc('c1')
          .set({'cashbackBalance': 200.0});

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
              feeLine(10.0, flagged: true),
            ],
          ),
        ],
        // الشكل المعلّم: القاعدة 100 → الخصم 100، موزّع 110 على subtotal
        // 110 → النهائي 0، والباقي 200 − 100 = 100.
        currentCashback: 200.0,
        useCashback: true,
      );

      expect(ok, isTrue);
      final docs = await docsOf('consumerorders');
      expect(docs.single.data()['subtotalPrice'], 110.0);
      expect(docs.single.data()['finalAmount'], closeTo(0.0, 1e-9));
      final consumer =
          (await fake.collection('consumers').doc('c1').get()).data()!;
      expect(consumer['cashbackBalance'], closeTo(100.0, 1e-9));
    });

    testWidgets('B2B production-shaped fee is dropped entirely',
        (tester) async {
      await fake.collection('sellers').doc('s1').set({'phone': '0111'});

      var secureCalled = false;
      final ok = await runPlaceOrder(
        tester,
        buyer: buyerWithAddress('12 Test St'),
        checkoutOrders: [
          sellerOrder(
            sellerId: 's1',
            items: [
              orderItem(productId: 'p1', price: 100.0, quantity: 1),
              feeLine(10.0),
            ],
          ),
        ],
        secureHandler: (payload) async {
          secureCalled = true;
          return ['srv-should-never-happen'];
        },
      );

      expect(ok, isTrue);
      expect(secureCalled, isFalse);
      final docs = await docsOf('orders');
      expect(docs, hasLength(1));
      final data = docs.single.data();
      expect(data['total'], 100.0);
      final items = data['items'] as List;
      expect(items, hasLength(1));
      expect(items.single['productId'], 'p1');
    });

    testWidgets('multi-seller fees stay with their own seller',
        (tester) async {
      await fake
          .collection('deliverySupermarkets')
          .doc('sm1')
          .set({'phone': '02220000000'});
      await fake
          .collection('deliverySupermarkets')
          .doc('sm2')
          .set({'phone': '03330000000'});
      await fake.collection('consumers').doc('c1').set({'cashbackBalance': 0.0});

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
              feeLine(10.0),
            ],
          ),
          sellerOrder(
            sellerId: 'sm2',
            sellerName: 'Fresh Market',
            items: [
              orderItem(productId: 'p2', price: 50.0, quantity: 2),
              feeLine(20.0),
            ],
          ),
        ],
      );

      expect(ok, isTrue);
      final docs = await docsOf('consumerorders');
      expect(docs, hasLength(2));
      final bySeller = {
        for (final d in docs) d.data()['supermarketId']: d.data()
      };
      expect(bySeller['sm1']!['subtotalPrice'], 110.0);
      expect(bySeller['sm1']!['finalAmount'], 110.0);
      expect(bySeller['sm2']!['subtotalPrice'], 120.0);
      expect(bySeller['sm2']!['finalAmount'], 120.0);
      // كل رسوم مع بائعها وبقيمتها: لا تسرّب ولا اختلاط.
      List itemsOf(String id) =>
          (bySeller[id]!['items'] as List).cast<Map<String, dynamic>>();
      final fee1 = itemsOf('sm1')
          .where((i) => i['productId'] == 'DELIVERY_FEE')
          .toList();
      final fee2 = itemsOf('sm2')
          .where((i) => i['productId'] == 'DELIVERY_FEE')
          .toList();
      expect(fee1, hasLength(1));
      expect(fee2, hasLength(1));
      expect(fee1.single['price'], 10.0);
      expect(fee2.single['price'], 20.0);
    });

    testWidgets('zero-price fee is not a gift: productId decides the class',
        (tester) async {
      await fake
          .collection('deliverySupermarkets')
          .doc('sm1')
          .set({'phone': '02220000000'});
      await fake.collection('consumers').doc('c1').set({'cashbackBalance': 0.0});

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
              feeLine(0.0),
            ],
          ),
        ],
      );

      expect(ok, isTrue);
      final docs = await docsOf('consumerorders');
      final items =
          (docs.single.data()['items'] as List).cast<Map<String, dynamic>>();
      expect(items, hasLength(3));
      final gift = items.singleWhere((i) => i['productId'] == 'gift-1');
      final fee = items.singleWhere((i) => i['productId'] == 'DELIVERY_FEE');
      // المنتج الصفري gift، وسطر الرسوم الصفري ليس gift رغم السعر.
      expect(gift['isGift'], isTrue);
      expect(fee['isGift'] == true, isFalse);
      expect(docs.single.data()['subtotalPrice'], 60.0);
      expect(docs.single.data()['finalAmount'], 60.0);
    });

    testWidgets(
        'CHARACTERIZATION (not desired): duplicate manual fee lines are '
        'summed without dedup', (tester) async {
      await fake
          .collection('deliverySupermarkets')
          .doc('sm1')
          .set({'phone': '02220000000'});
      await fake.collection('consumers').doc('c1').set({'cashbackBalance': 0.0});

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
              feeLine(10.0),
              feeLine(10.0),
            ],
          ),
        ],
      );

      expect(ok, isTrue);
      final docs = await docsOf('consumerorders');
      // السلوك الحالي: لا إزالة تكرار — 100 + 10 + 10.
      expect(docs.single.data()['subtotalPrice'], 120.0);
      expect(docs.single.data()['finalAmount'], 120.0);
    });

    testWidgets(
        'CHARACTERIZATION (not desired): negative fee price reduces the total',
        (tester) async {
      await fake
          .collection('deliverySupermarkets')
          .doc('sm1')
          .set({'phone': '02220000000'});
      await fake.collection('consumers').doc('c1').set({'cashbackBalance': 0.0});

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
              feeLine(-5.0),
            ],
          ),
        ],
      );

      expect(ok, isTrue);
      final docs = await docsOf('consumerorders');
      // السلوك الحالي: لا تحقق من الأسعار client-side — 100 − 5.
      expect(docs.single.data()['subtotalPrice'], 95.0);
      expect(docs.single.data()['finalAmount'], 95.0);
    });

    test('model extracts the fee from the productId line (production shape)',
        () async {
      final feeItem = {
        'productId': 'DELIVERY_FEE',
        'name': 'رسوم التوصيل',
        'price': 10.0,
        'quantity': 1,
      };
      final paidItem = {
        'productId': 'p1',
        'name': 'Item p1',
        'price': 100.0,
        'quantity': 1,
      };

      final refNoScalar = await fake.collection('consumerorders').add({
        'items': [paidItem, feeItem],
        'finalAmount': 110.0,
      });
      final modelNoScalar = ConsumerOrderModel.fromFirestore(
        await refNoScalar.get(),
      );
      // لا سكالر → fallback مسح الأصناف بـproductId.
      expect(modelNoScalar.deliveryFee, 10.0);

      final refScalar = await fake.collection('consumerorders').add({
        'deliveryFee': 7.0,
        'items': [paidItem, feeItem],
        'finalAmount': 110.0,
      });
      final modelScalar = ConsumerOrderModel.fromFirestore(
        await refScalar.get(),
      );
      // السكالر له الأولوية عند وجوده.
      expect(modelScalar.deliveryFee, 7.0);
    });
  });
}
