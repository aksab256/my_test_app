import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_test_app/data_sources/order_data_source.dart';

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

  group('updateOrderStatus', () {
    test('B2B order to delivered stamps status, updatedAt and deliveryDate',
        () async {
      await fake.collection('orders').doc('o1').set(b2bOrder());

      await dataSource.updateOrderStatus('o1', 'delivered');

      final data = (await fake.collection('orders').doc('o1').get()).data()!;
      expect(data['status'], 'delivered');
      expect(data['updatedAt'], isA<Timestamp>());
      expect(data['deliveryDate'], isA<Timestamp>());
      expect(data.containsKey('cancellationDate'), isFalse);
      expect(data.containsKey('shippedDate'), isFalse);
    });

    test('B2C order to cancelled is routed to consumerorders', () async {
      await fake.collection('consumerorders').doc('c-o1').set(b2cOrder());

      await dataSource.updateOrderStatus('c-o1', 'cancelled');

      final data =
          (await fake.collection('consumerorders').doc('c-o1').get()).data()!;
      expect(data['status'], 'cancelled');
      expect(data['updatedAt'], isA<Timestamp>());
      expect(data['cancellationDate'], isA<Timestamp>());
      expect(data.containsKey('deliveryDate'), isFalse);
      expect(await fake.collection('orders').get().then((s) => s.docs),
          isEmpty);
    });

    test('order to shipped stamps shippedDate', () async {
      await fake.collection('orders').doc('o1').set(b2bOrder());

      await dataSource.updateOrderStatus('o1', 'shipped');

      final data = (await fake.collection('orders').doc('o1').get()).data()!;
      expect(data['status'], 'shipped');
      expect(data['shippedDate'], isA<Timestamp>());
      expect(data.containsKey('deliveryDate'), isFalse);
      expect(data.containsKey('cancellationDate'), isFalse);
    });

    test('processing writes status and updatedAt with no extra date stamps',
        () async {
      await fake.collection('orders').doc('o1').set(b2bOrder());

      await dataSource.updateOrderStatus('o1', 'processing');

      final data = (await fake.collection('orders').doc('o1').get()).data()!;
      expect(data['status'], 'processing');
      expect(data['updatedAt'], isA<Timestamp>());
      expect(data.containsKey('deliveryDate'), isFalse);
      expect(data.containsKey('cancellationDate'), isFalse);
      expect(data.containsKey('shippedDate'), isFalse);
    });

    test('unknown order id throws', () async {
      await expectLater(
        dataSource.updateOrderStatus('missing', 'delivered'),
        throwsA(isA<Exception>()),
      );
    });

    test('id present in both collections gives orders priority', () async {
      await fake.collection('orders').doc('shared').set(b2bOrder());
      await fake
          .collection('consumerorders')
          .doc('shared')
          .set(b2cOrder());

      await dataSource.updateOrderStatus('shared', 'shipped');

      final b2b =
          (await fake.collection('orders').doc('shared').get()).data()!;
      final b2c =
          (await fake.collection('consumerorders').doc('shared').get()).data()!;
      expect(b2b['status'], 'shipped');
      expect(b2b['shippedDate'], isA<Timestamp>());
      expect(b2c['status'], 'new-order');
      expect(b2c.containsKey('shippedDate'), isFalse);
    });

    test('unknown status string is written as-is (behavior lock)', () async {
      await fake.collection('orders').doc('o1').set(b2bOrder());

      await dataSource.updateOrderStatus('o1', 'weird-status');

      final data = (await fake.collection('orders').doc('o1').get()).data()!;
      // No transition/status validation exists: the raw value is persisted.
      expect(data['status'], 'weird-status');
    });
  });

  group('loadOrders', () {
    test('seller sees B2B and B2C combined, newest first', () async {
      await fake.collection('orders').doc('b2b').set(
            b2bOrder(orderDate: DateTime.utc(2026, 1, 10)),
          );
      await fake.collection('consumerorders').doc('b2c').set(
            b2cOrder(orderDate: DateTime.utc(2026, 1, 20)),
          );

      final orders = await dataSource.loadOrders('seller-1', 'seller');

      expect(orders.map((o) => o.id).toList(), ['b2c', 'b2b']);
      expect(orders.first.sellerId, 'seller-1');
    });

    test('seller with no orders returns empty list', () async {
      final orders = await dataSource.loadOrders('seller-9', 'seller');

      expect(orders, isEmpty);
    });

    test('buyer sees only their own orders', () async {
      await fake.collection('orders').doc('mine').set(b2bOrder(
            buyerId: 'buyer-1',
            orderDate: DateTime.utc(2026, 1, 10),
          ));
      await fake.collection('orders').doc('theirs').set(b2bOrder(
            buyerId: 'buyer-2',
            orderDate: DateTime.utc(2026, 1, 11),
          ));

      final orders = await dataSource.loadOrders('buyer-1', 'buyer');

      expect(orders.map((o) => o.id).toList(), ['mine']);
    });

    test('consumer loads from consumerorders by customerId', () async {
      await fake.collection('consumerorders').doc('mine').set(b2cOrder(
            customerId: 'c1',
            orderDate: DateTime.utc(2026, 1, 10),
          ));
      await fake.collection('consumerorders').doc('theirs').set(b2cOrder(
            customerId: 'c2',
            orderDate: DateTime.utc(2026, 1, 11),
          ));

      final orders = await dataSource.loadOrders('c1', 'consumer');

      expect(orders.map((o) => o.id).toList(), ['mine']);
      expect(orders.single.totalAmount, 90.0);
    });

    test('corrupt document is skipped while valid ones load', () async {
      await fake.collection('orders').doc('valid').set(b2bOrder());
      // An item that is not a map breaks OrderItemModel parsing.
      await fake.collection('orders').doc('broken').set(
            b2bOrder(items: ['junk']),
          );

      final orders = await dataSource.loadOrders('seller-1', 'seller');

      expect(orders.map((o) => o.id).toList(), ['valid']);
    });

    test('unknown B2B status reads back as new-order (behavior lock)',
        () async {
      await fake.collection('orders').doc('o1').set(
            b2bOrder(status: 'archived'),
          );

      final orders = await dataSource.loadOrders('seller-1', 'seller');

      // fromFirestore silently coerces unlisted statuses.
      expect(orders.single.status, 'new-order');
    });
  });
}
