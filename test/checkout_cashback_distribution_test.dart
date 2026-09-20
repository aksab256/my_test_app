import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_test_app/controllers/checkout_controller.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';

// A1: توزيع خصم الـCashback على multi-seller + سقف min(total, balance).
//
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

  group('A1: cashback distribution over multi-seller + min(total, balance) cap',
      () {
    testWidgets('buyer multi-seller cashback is split pro-rata (secure path)',
        (tester) async {
      await fake.collection('sellers').doc('s1').set({
        'commissionRate': 0.05,
        'phone': '01110000000',
      });
      await fake.collection('sellers').doc('s2').set({
        'commissionRate': 0.2,
        'phone': '02220000000',
      });
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
          sellerOrder(
            sellerId: 's2',
            items: [orderItem(productId: 'p2', price: 50.0, quantity: 2)],
          ),
        ],
        // الإجمالي 200 والرصيد 30 → الخصم المتوقع min(200, 30) = 30.
        currentCashback: 30.0,
        useCashback: true,
        secureHandler: (payload) async {
          captured = payload;
          return ['srv-1', 'srv-2'];
        },
      );

      expect(ok, isTrue);
      // المسار الآمن لا يكتب طلبات مباشرة في Firestore.
      expect(await docsOf('orders'), isEmpty);
      expect(captured, isNotNull);
      // السقف: المحجوز = min(total, balance).
      expect(captured!['cashbackToReserve'], 30.0);
      expect(captured!['total_insurance_points'], 30.0);

      final ordersData = captured!['ordersData'] as List;
      expect(ordersData, hasLength(2));
      final bySeller = {
        for (final o in ordersData) (o['sellerId'] as String): o,
      };
      // التوزيع النسبي: 100/200*30 = 15 لكل بائع.
      expect(bySeller['s1']!['cashbackApplied'], closeTo(15.0, 1e-9));
      expect(bySeller['s2']!['cashbackApplied'], closeTo(15.0, 1e-9));
      expect(bySeller['s1']!['insurance_points'], closeTo(15.0, 1e-9));
      expect(bySeller['s2']!['insurance_points'], closeTo(15.0, 1e-9));
      // مجموع الموزّع يساوي الخصم الكلي تمامًا.
      final distributed = (bySeller['s1']!['cashbackApplied'] as num)
              .toDouble() +
          (bySeller['s2']!['cashbackApplied'] as num).toDouble();
      expect(distributed, closeTo(30.0, 1e-9));
      expect(bySeller['s1']!['isCashbackUsed'], isTrue);
      expect(bySeller['s2']!['isCashbackUsed'], isTrue);
      // السيرفر يملك الخصم: لا خصم مباشر من رصيد المستخدم هنا.
      final user =
          (await fake.collection('users').doc('buyer-1').get()).data()!;
      expect(user['cashback'], 30.0);
    });

    testWidgets('buyer cashback never exceeds the order total (cap)',
        (tester) async {
      await fake.collection('sellers').doc('s1').set({'phone': '0111'});
      await fake.collection('sellers').doc('s2').set({'phone': '0222'});
      await fake.collection('users').doc('buyer-1').set({'cashback': 100.0});

      Map<String, dynamic>? captured;
      final ok = await runPlaceOrder(
        tester,
        buyer: buyerWithAddress('12 Test St'),
        checkoutOrders: [
          sellerOrder(
            sellerId: 's1',
            items: [orderItem(productId: 'p1', price: 30.0, quantity: 1)],
          ),
          sellerOrder(
            sellerId: 's2',
            items: [orderItem(productId: 'p2', price: 10.0, quantity: 1)],
          ),
        ],
        // الإجمالي 40 والرصيد 100 → الخصم المتوقع min(40, 100) = 40.
        currentCashback: 100.0,
        useCashback: true,
        secureHandler: (payload) async {
          captured = payload;
          return ['srv-1', 'srv-2'];
        },
      );

      expect(ok, isTrue);
      expect(captured!['cashbackToReserve'], 40.0);
      expect(captured!['total_insurance_points'], 40.0);

      final ordersData = captured!['ordersData'] as List;
      final bySeller = {
        for (final o in ordersData) (o['sellerId'] as String): o,
      };
      // 30/40*40 = 30 و10/40*40 = 10: المجموع 40 = الإجمالي، لا يتجاوزه.
      expect(bySeller['s1']!['cashbackApplied'], closeTo(30.0, 1e-9));
      expect(bySeller['s2']!['cashbackApplied'], closeTo(10.0, 1e-9));
      final distributed = (bySeller['s1']!['cashbackApplied'] as num)
              .toDouble() +
          (bySeller['s2']!['cashbackApplied'] as num).toDouble();
      expect(distributed, closeTo(40.0, 1e-9));
      expect(distributed, lessThanOrEqualTo(40.0 + 1e-9));
    });

    testWidgets('useCashback=false ignores any balance on multi-seller',
        (tester) async {
      await fake.collection('sellers').doc('s1').set({});
      await fake.collection('sellers').doc('s2').set({});
      await fake.collection('users').doc('buyer-1').set({'cashback': 50.0});

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
        currentCashback: 50.0,
        useCashback: false,
      );

      expect(ok, isTrue);
      final docs = await docsOf('orders');
      expect(docs, hasLength(2));
      final bySeller = {for (final d in docs) d.data()['sellerId']: d.data()};
      // صفر خصم على كل بائع رغم وجود رصيد 50.
      expect(bySeller['s1']!['isCashbackUsed'], isFalse);
      expect(bySeller['s2']!['isCashbackUsed'], isFalse);
      expect(bySeller['s1']!['insurance_points'], 0.0);
      expect(bySeller['s2']!['insurance_points'], 0.0);
      expect(bySeller['s1']!['total'], 100.0);
      expect(bySeller['s2']!['total'], 100.0);
      final user =
          (await fake.collection('users').doc('buyer-1').get()).data()!;
      expect(user['cashback'], 50.0);
    });

    testWidgets('single-seller baseline: full discount on one seller',
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
        // الإجمالي 100 والرصيد 30 → الخصم 30 كاملًا على البائع الوحيد.
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
      expect(ordersData, hasLength(1));
      expect(ordersData.single['cashbackApplied'], closeTo(30.0, 1e-9));
      expect(ordersData.single['insurance_points'], closeTo(30.0, 1e-9));
      expect(ordersData.single['isCashbackUsed'], isTrue);
    });

    testWidgets('consumer multi-seller cashback splits with direct deduction',
        (tester) async {
      await fake
          .collection('deliverySupermarkets')
          .doc('sm1')
          .set({'phone': '02220000000'});
      await fake
          .collection('deliverySupermarkets')
          .doc('sm2')
          .set({'phone': '03330000000'});
      await fake.collection('consumers').doc('c1').set({'cashbackBalance': 60.0});

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
        // الإجمالي 200 والرصيد 60 → الخصم 60، موزّع 30/30.
        currentCashback: 60.0,
        useCashback: true,
      );

      expect(ok, isTrue);
      expect(await docsOf('orders'), isEmpty);
      final docs = await docsOf('consumerorders');
      expect(docs, hasLength(2));
      final bySeller = {for (final d in docs) d.data()['supermarketId']: d.data()};
      expect(bySeller['sm1']!['subtotalPrice'], 100.0);
      expect(bySeller['sm2']!['subtotalPrice'], 100.0);
      expect(bySeller['sm1']!['finalAmount'], closeTo(70.0, 1e-9));
      expect(bySeller['sm2']!['finalAmount'], closeTo(70.0, 1e-9));
      // الخصم المباشر: الرصيد المتبقي 60 − 60 = 0.
      final consumer =
          (await fake.collection('consumers').doc('c1').get()).data()!;
      expect(consumer['cashbackBalance'], closeTo(0.0, 1e-9));
    });
  });
}
