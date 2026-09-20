import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_test_app/data_sources/order_data_source.dart';

// A7: Order filtering by role (OrderDataSource.loadOrders).
//
// يختبر العزل بين الأدوار وليس مجرد إرجاع data: كل role يرى مجموعته
// وحقله فقط، ولا يتسرب إليه ما يخص غيره. الـfallback والـstatus parsing
// المختلف موثّقان كـCHARACTERIZATION حيث يلزم.
// يستخدم الـdb seam الموجود فقط، دون أي production change.
void main() {
  late FakeFirebaseFirestore fake;
  late OrderDataSource dataSource;

  setUp(() {
    fake = FakeFirebaseFirestore();
    dataSource = OrderDataSource(db: fake);
  });

  Map<String, dynamic> b2bOrder({
    String sellerId = 'seller-1',
    String buyerId = 'buyer-1',
    String status = 'new-order',
    DateTime? orderDate,
    double total = 50.0,
    dynamic items = const [
      {'name': 'Item', 'quantity': 1, 'unit': 'pc', 'price': 50.0},
    ],
  }) =>
      {
        'sellerId': sellerId,
        'orderDate':
            Timestamp.fromDate(orderDate ?? DateTime.utc(2026, 1, 10)),
        'status': status,
        'buyer': {
          'id': buyerId,
          'name': 'Buyer $buyerId',
          'phone': '01000000000',
          'address': 'Buyer St',
        },
        'items': items,
        'total': total,
      };

  Map<String, dynamic> b2cOrder({
    String supermarketId = 'seller-1',
    String customerId = 'c1',
    String status = 'new-order',
    DateTime? orderDate,
    double subtotal = 100.0,
    double finalAmount = 90.0,
  }) =>
      {
        'supermarketId': supermarketId,
        'customerId': customerId,
        'customerName': 'Consumer $customerId',
        'customerPhone': '02000000000',
        'customerAddress': 'Consumer Ave',
        'orderDate':
            Timestamp.fromDate(orderDate ?? DateTime.utc(2026, 1, 20)),
        'status': status,
        'items': const [
          {'name': 'Milk', 'quantity': 2, 'unit': 'pc', 'price': 50.0},
        ],
        'subtotalPrice': subtotal,
        'finalAmount': finalAmount,
      };

  group('A7: role isolation', () {
    test('seller sees only their own docs in both collections', () async {
      await fake.collection('orders').doc('own-b2b').set(b2bOrder(
            sellerId: 'seller-1',
            orderDate: DateTime.utc(2026, 1, 10),
          ));
      await fake.collection('orders').doc('other-b2b').set(b2bOrder(
            sellerId: 'seller-2',
            buyerId: 'buyer-9',
            orderDate: DateTime.utc(2026, 1, 11),
          ));
      await fake.collection('consumerorders').doc('own-b2c').set(b2cOrder(
            supermarketId: 'seller-1',
            orderDate: DateTime.utc(2026, 1, 20),
          ));
      await fake.collection('consumerorders').doc('other-b2c').set(b2cOrder(
            supermarketId: 'seller-2',
            customerId: 'c9',
            orderDate: DateTime.utc(2026, 1, 21),
          ));

      final orders = await dataSource.loadOrders('seller-1', 'seller');

      expect(
        orders.map((o) => o.id).toSet(),
        {'own-b2b', 'own-b2c'},
      );
      for (final o in orders) {
        expect(o.sellerId, 'seller-1');
      }
    });

    test('buyer never surfaces consumerorders documents', () async {
      await fake.collection('orders').doc('mine').set(b2bOrder(
            buyerId: 'buyer-1',
            orderDate: DateTime.utc(2026, 1, 10),
          ));
      // Same id value, wrong collection: invisible to the buyer path.
      await fake.collection('consumerorders').doc('ghost').set(b2cOrder(
            customerId: 'buyer-1',
            orderDate: DateTime.utc(2026, 1, 11),
          ));

      final orders = await dataSource.loadOrders('buyer-1', 'buyer');

      expect(orders.map((o) => o.id).toList(), ['mine']);
    });

    test('consumer never surfaces B2B orders documents', () async {
      await fake.collection('consumerorders').doc('mine').set(b2cOrder(
            customerId: 'c1',
            orderDate: DateTime.utc(2026, 1, 10),
          ));
      // Same id value, wrong collection: invisible to the consumer path.
      await fake.collection('orders').doc('ghost').set(b2bOrder(
            buyerId: 'c1',
            orderDate: DateTime.utc(2026, 1, 11),
          ));

      final orders = await dataSource.loadOrders('c1', 'consumer');

      expect(orders.map((o) => o.id).toList(), ['mine']);
    });

    test('buyer and consumer with no orders return empty', () async {
      expect(await dataSource.loadOrders('buyer-9', 'buyer'), isEmpty);
      expect(await dataSource.loadOrders('c9', 'consumer'), isEmpty);
    });

    test('buyer orders come back newest first', () async {
      await fake.collection('orders').doc('older').set(b2bOrder(
            buyerId: 'buyer-1',
            orderDate: DateTime.utc(2026, 1, 10),
          ));
      await fake.collection('orders').doc('newer').set(b2bOrder(
            buyerId: 'buyer-1',
            orderDate: DateTime.utc(2026, 1, 11),
          ));

      final orders = await dataSource.loadOrders('buyer-1', 'buyer');

      expect(orders.map((o) => o.id).toList(), ['newer', 'older']);
    });

    test('consumer orders come back newest first', () async {
      await fake.collection('consumerorders').doc('older').set(b2cOrder(
            customerId: 'c1',
            orderDate: DateTime.utc(2026, 1, 10),
          ));
      await fake.collection('consumerorders').doc('newer').set(b2cOrder(
            customerId: 'c1',
            orderDate: DateTime.utc(2026, 1, 11),
          ));

      final orders = await dataSource.loadOrders('c1', 'consumer');

      expect(orders.map((o) => o.id).toList(), ['newer', 'older']);
    });

    test('buyer skips a corrupt doc via the null-filter branch', () async {
      await fake.collection('orders').doc('valid').set(b2bOrder());
      await fake.collection('orders').doc('broken').set(
            b2bOrder(items: ['junk']),
          );

      final orders = await dataSource.loadOrders('buyer-1', 'buyer');

      expect(orders.map((o) => o.id).toList(), ['valid']);
    });

    test('seller skips an unparseable B2C doc while valid docs load',
        () async {
      await fake.collection('orders').doc('valid-b2b').set(b2bOrder());
      await fake.collection('consumerorders').doc('valid-b2c').set(b2cOrder());
      await fake.collection('consumerorders').doc('broken-b2c').set({
        ...b2cOrder(),
        // finalAmount as String breaks the num cast in fromConsumerFirestore.
        'finalAmount': 'not-a-number',
      });

      final orders = await dataSource.loadOrders('seller-1', 'seller');

      expect(
        orders.map((o) => o.id).toSet(),
        {'valid-b2b', 'valid-b2c'},
      );
    });

    test(
        'CHARACTERIZATION: consumer status passes through without the B2B '
        'allow-list', () async {
      await fake.collection('consumerorders').doc('o1').set(
            b2cOrder(status: 'archived'),
          );

      final orders = await dataSource.loadOrders('c1', 'consumer');

      // fromFirestore coerces unknown B2B statuses to new-order, but
      // fromConsumerFirestore keeps the raw value.
      expect(orders.single.status, 'archived');
    });

    test('unknown role falls back to the buyer path without crashing',
        () async {
      await fake.collection('orders').doc('mine').set(b2bOrder(
            buyerId: 'u9',
            orderDate: DateTime.utc(2026, 1, 10),
          ));

      final orders = await dataSource.loadOrders('u9', '');

      expect(orders.map((o) => o.id).toList(), ['mine']);
    });

    test('empty userId returns empty without crashing', () async {
      await fake.collection('orders').doc('o1').set(b2bOrder());

      expect(await dataSource.loadOrders('', 'buyer'), isEmpty);
      expect(await dataSource.loadOrders('', 'seller'), isEmpty);
    });

    test(
        'CHARACTERIZATION: seller fallback drops B2C (orders-only query)',
        () async {
      await fake.collection('orders').doc('b2b').set(
            b2bOrder(orderDate: DateTime.utc(2026, 1, 10)),
          );
      await fake.collection('consumerorders').doc('b2c').set(
            b2cOrder(orderDate: DateTime.utc(2026, 1, 20)),
          );

      // First query attempt throws (simulated missing index): the fallback
      // requeries orders/sellerId only, so B2C is silently lost.
      final flaky = FailFirstFirestore(fake);
      final orders =
          await OrderDataSource(db: flaky).loadOrders('seller-1', 'seller');

      expect(orders.map((o) => o.id).toList(), ['b2b']);
    });

    test(
        'CHARACTERIZATION: consumer fallback queries the wrong '
        'collection/field', () async {
      await fake.collection('consumerorders').doc('mine').set(b2cOrder());

      // Fallback uses orders + buyer.id, where consumer docs never live.
      final flaky = FailFirstFirestore(fake);
      final orders =
          await OrderDataSource(db: flaky).loadOrders('c1', 'consumer');

      expect(orders, isEmpty);
    });

    test('total Firestore failure returns empty list', () async {
      final orders =
          await OrderDataSource(db: AlwaysFailFirestore()).loadOrders(
        'seller-1',
        'seller',
      );

      expect(orders, isEmpty);
    });
  });
}

// Fails the first collection() call (simulated missing-index failure on the
// primary query) so the loadOrders fallback path executes deterministically.
class FailFirstFirestore implements FirebaseFirestore {
  final FakeFirebaseFirestore real;
  int calls = 0;

  FailFirstFirestore(this.real);

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    calls++;
    if (calls == 1) throw Exception('index missing');
    return real.collection(path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Every Firestore access throws: pins the ultimate empty-list guarantee.
class AlwaysFailFirestore implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    throw Exception('firestore down');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
