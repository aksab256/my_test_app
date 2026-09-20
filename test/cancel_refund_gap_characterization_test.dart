import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_test_app/controllers/checkout_controller.dart';
import 'package:my_test_app/data_sources/order_data_source.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';

// B3: Cancellation refund characterization (tripwire, NOT a bug proof).
//
// AUDIT коллектива (frontend فقط):
// - وعد الاسترداد موجود كنص في orders_screen.dart:301 فقط.
// - لا توجد أي كتابة استرداد في updateOrderStatus (status + طوابع فقط).
// - لا توجد أي كتابة دائنة للرصيد في كامل lib (الكتابة الوحيدة على الرصيد
//   هي خصم placeOrder).
// - لا يوجد أي Cloud Function/Hook للإلغاء/الاسترداد داخل الـrepo
//   (الـFunction الوحيدة المشار إليها createOrdersWithPromos للإنشاء).
// - إلغاء المندوب (retailer_tracking) يفك ارتباط specialRequestId فقط.
// النتيجة: الاسترداد غائب من كل الكود المتاح؛ وجود trigger خلفي
// (onUpdate) غير قابل للحسم من هنا -> unresolved backend dependency.
// هذان الاختباران يوثّقان الوضع الحالي، وأي آلية استرداد مستقبلية
// ستقلبهما أحمر عمدًا. دون أي production change أو seam جديد.
void main() {
  late FakeFirebaseFirestore fake;
  late OrderDataSource dataSource;

  setUp(() {
    fake = FakeFirebaseFirestore();
    dataSource = OrderDataSource(db: fake);
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
  }) =>
      {
        'productId': productId,
        'price': price,
        'quantity': quantity,
        'mainId': 'm1',
        'subId': 's1',
        'name': 'Item $productId',
      };

  BuyerDataProvider buyerWithAddress(String address) {
    final buyer = BuyerDataProvider(firestore: fake);
    buyer.setSessionLocation(lat: 30.0, lng: 31.0, address: address);
    return buyer;
  }

  Future<bool> runPlaceOrder(
    WidgetTester tester, {
    required BuyerDataProvider buyer,
    required List<Map<String, dynamic>> checkoutOrders,
    required Map<String, dynamic> loggedUser,
    double currentCashback = 0,
    bool useCashback = false,
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
      loggedUser: loggedUser,
      originalOrderTotal: 0,
      currentCashback: currentCashback,
      finalTotalAmount: 0,
      useCashback: useCashback,
      selectedPaymentMethod: 'cash',
      firestore: fake,
    );
    await tester.pump(const Duration(seconds: 5));
    return result;
  }

  group('B3: cancellation refund gap (characterization)', () {
    testWidgets(
        'CHARACTERIZATION: cancelling a discounted consumer order does not '
        'restore the balance in reachable code', (tester) async {
      await fake
          .collection('deliverySupermarkets')
          .doc('sm1')
          .set({'phone': '02220000000'});
      await fake
          .collection('consumers')
          .doc('c1')
          .set({'cashbackBalance': 50.0});

      final placed = await runPlaceOrder(
        tester,
        buyer: buyerWithAddress('Consumer Ave'),
        checkoutOrders: [
          {
            'sellerId': 'sm1',
            'sellerName': 'Corner Supermarket',
            'items': [orderItem(productId: 'p1', price: 100.0, quantity: 1)],
          },
        ],
        loggedUser: buyerUser(id: 'c1', role: 'consumer'),
        // الخصم 50 والباقي 0 قبل الإلغاء.
        currentCashback: 50.0,
        useCashback: true,
      );
      expect(placed, isTrue);

      final orderId =
          (await fake.collection('consumerorders').get()).docs.single.id;
      await dataSource.updateOrderStatus(orderId, 'cancelled');

      final order =
          (await fake.collection('consumerorders').doc(orderId).get()).data()!;
      expect(order['status'], 'cancelled');
      expect(order['cancellationDate'], isA<Timestamp>());

      // لا استرداد في أي كود متاح: الرصيد ما زال 0.
      // (إن وُجد trigger خلفي فهو خارج هذا الـrepo.)
      final consumer =
          (await fake.collection('consumers').doc('c1').get()).data()!;
      expect(consumer['cashbackBalance'], closeTo(0.0, 1e-9));
    });

    testWidgets(
        'CHARACTERIZATION: cancelling a B2B direct order touches no balance',
        (tester) async {
      await fake.collection('sellers').doc('s1').set({'phone': '0111'});
      await fake.collection('users').doc('buyer-1').set({'cashback': 40.0});

      final placed = await runPlaceOrder(
        tester,
        buyer: buyerWithAddress('12 Test St'),
        checkoutOrders: [
          {
            'sellerId': 's1',
            'sellerName': 'Seller',
            'items': [orderItem(productId: 'p1', price: 100.0, quantity: 1)],
          },
        ],
        loggedUser: buyerUser(),
        currentCashback: 40.0,
        useCashback: false,
      );
      expect(placed, isTrue);

      final orderId =
          (await fake.collection('orders').get()).docs.single.id;
      await dataSource.updateOrderStatus(orderId, 'cancelled');

      final order =
          (await fake.collection('orders').doc(orderId).get()).data()!;
      expect(order['status'], 'cancelled');
      final user =
          (await fake.collection('users').doc('buyer-1').get()).data()!;
      expect(user['cashback'], 40.0);
    });
  });
}
