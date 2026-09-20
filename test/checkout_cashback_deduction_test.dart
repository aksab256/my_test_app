import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_test_app/controllers/checkout_controller.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';

// A4: خصم رصيد الـCashback بعد الطلب المباشر.
//
// يغطي محاسبة الخصم فقط (القيمة المخصومة والباقي وعدم اللمس)،
// دون تغيير snapshot semantics أو atomicity الحالية.
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

  group('A4: cashback deduction after direct order', () {
    testWidgets('consumer discount deducts currentCashback - discountUsed',
        (tester) async {
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
            items: [orderItem(productId: 'p1', price: 100.0, quantity: 1)],
          ),
        ],
        // الإجمالي 100 والرصيد 50 → الخصم 50 والباقي 50 − 50 = 0.
        currentCashback: 50.0,
        useCashback: true,
      );

      expect(ok, isTrue);
      final docs = await docsOf('consumerorders');
      expect(docs, hasLength(1));
      expect(docs.single.data()['finalAmount'], closeTo(50.0, 1e-9));
      // الخصم مكتوب على consumers/{id}.cashbackBalance.
      final consumer =
          (await fake.collection('consumers').doc('c1').get()).data()!;
      expect(consumer['cashbackBalance'], closeTo(0.0, 1e-9));
    });

    testWidgets(
        'consumer balance above the total deducts only the allowed amount '
        'across sellers', (tester) async {
      await fake
          .collection('deliverySupermarkets')
          .doc('sm1')
          .set({'phone': '02220000000'});
      await fake
          .collection('deliverySupermarkets')
          .doc('sm2')
          .set({'phone': '03330000000'});
      await fake
          .collection('consumers')
          .doc('c1')
          .set({'cashbackBalance': 300.0});

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
          sellerOrder(
            sellerId: 'sm2',
            sellerName: 'Fresh Market',
            items: [orderItem(productId: 'p2', price: 50.0, quantity: 2)],
          ),
        ],
        // الإجمالي 200 والرصيد 300 → الخصم 200 فقط، والباقي 100.
        // (الهدف هنا محاسبة الخصم متعدد البائعين، لا finalAmount وحده.)
        currentCashback: 300.0,
        useCashback: true,
      );

      expect(ok, isTrue);
      final docs = await docsOf('consumerorders');
      expect(docs, hasLength(2));
      for (final d in docs) {
        expect(d.data()['finalAmount'], closeTo(0.0, 1e-9));
      }
      final consumer =
          (await fake.collection('consumers').doc('c1').get()).data()!;
      expect(consumer['cashbackBalance'], closeTo(100.0, 1e-9));
      expect(consumer['cashbackBalance'], greaterThanOrEqualTo(0.0));
    });

    testWidgets('useCashback=false leaves the consumer document untouched',
        (tester) async {
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
            items: [orderItem(productId: 'p1', price: 100.0, quantity: 1)],
          ),
        ],
        currentCashback: 50.0,
        useCashback: false,
      );

      expect(ok, isTrue);
      final docs = await docsOf('consumerorders');
      expect(docs, hasLength(1));
      expect(docs.single.data()['finalAmount'], 100.0);
      final consumer =
          (await fake.collection('consumers').doc('c1').get()).data()!;
      expect(consumer['cashbackBalance'], 50.0);
    });

    testWidgets('plain B2B direct order performs no deduction (dead guard)',
        (tester) async {
      await fake.collection('sellers').doc('s1').set({'phone': '0111'});
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
      expect(await docsOf('orders'), hasLength(1));
      // لا خصم هنا لأن discountUsed == 0 حتمًا على هذا المسار للـB2B.
      final user =
          (await fake.collection('users').doc('buyer-1').get()).data()!;
      expect(user['cashback'], 40.0);
    });

    testWidgets(
        'REGRESSION (characterization, not desired behavior): failed '
        'cashback update still leaves created orders while reporting failure',
        (tester) async {
      await fake
          .collection('deliverySupermarkets')
          .doc('sm1')
          .set({'phone': '02220000000'});
      // لا مستند consumers/c1: كتابة الطلب تنجح ثم update الخصم يرمي.

      final ok = await runPlaceOrder(
        tester,
        buyer: buyerWithAddress('Consumer Ave'),
        loggedUser: buyerUser(id: 'c1', role: 'consumer'),
        checkoutOrders: [
          sellerOrder(
            sellerId: 'sm1',
            sellerName: 'Corner Supermarket',
            items: [orderItem(productId: 'p1', price: 60.0, quantity: 1)],
          ),
        ],
        currentCashback: 20.0,
        useCashback: true,
      );

      // السلوك الحالي: فشل مُبلَّغ رغم وجود طلب منشأ.
      expect(ok, isFalse);
      expect(await docsOf('consumerorders'), hasLength(1));
      // وفشل الـupdate لا ينشئ المستند.
      expect((await fake.collection('consumers').doc('c1').get()).exists,
          isFalse);
    });
  });
}
