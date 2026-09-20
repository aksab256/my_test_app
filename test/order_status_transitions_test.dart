import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_test_app/data_sources/order_data_source.dart';

// A8: Order Status Transitions (OrderDataSource.updateOrderStatus).
//
// توثيق دورة الحياة الحالية كما هي: لا يوجد أي تحقق من الانتقالات
// (أي حالة → أي حالة)، ولا تحقق ملكية/دور، والطوابع الزمنية تتراكم
// ولا تُمسح أبدًا. كل اختبار هنا characterization للسلوك القائم.
// B2B (orders) وB2C (consumerorders) مختبَران بشكل منفصل.
// يستخدم الـdb seam الموجود فقط، دون أي production change.
void main() {
  late FakeFirebaseFirestore fake;
  late OrderDataSource dataSource;

  setUp(() {
    fake = FakeFirebaseFirestore();
    dataSource = OrderDataSource(db: fake);
  });

  Future<void> seedB2B(String id, {String status = 'new-order'}) =>
      fake.collection('orders').doc(id).set({'status': status});

  Future<void> seedB2C(String id, {String status = 'new-order'}) =>
      fake.collection('consumerorders').doc(id).set({'status': status});

  Future<Map<String, dynamic>> readB2B(String id) async =>
      (await fake.collection('orders').doc(id).get()).data()!;

  Future<Map<String, dynamic>> readB2C(String id) async =>
      (await fake.collection('consumerorders').doc(id).get()).data()!;

  group('A8: B2B status transitions', () {
    test('forward chain accumulates date stamps, never replaces them',
        () async {
      await seedB2B('o1');

      await dataSource.updateOrderStatus('o1', 'processing');
      await dataSource.updateOrderStatus('o1', 'shipped');
      await dataSource.updateOrderStatus('o1', 'delivered');

      final data = await readB2B('o1');
      expect(data['status'], 'delivered');
      expect(data['updatedAt'], isA<Timestamp>());
      // shippedDate from the shipped step is still there next to deliveryDate.
      expect(data['shippedDate'], isA<Timestamp>());
      expect(data['deliveryDate'], isA<Timestamp>());
      expect(data.containsKey('cancellationDate'), isFalse);
    });

    test('cancel from processing stamps only cancellationDate', () async {
      await seedB2B('o1', status: 'processing');

      await dataSource.updateOrderStatus('o1', 'cancelled');

      final data = await readB2B('o1');
      expect(data['status'], 'cancelled');
      expect(data['updatedAt'], isA<Timestamp>());
      expect(data['cancellationDate'], isA<Timestamp>());
      expect(data.containsKey('deliveryDate'), isFalse);
      expect(data.containsKey('shippedDate'), isFalse);
    });

    test('delivered -> cancelled keeps the delivery stamp', () async {
      await seedB2B('o1');

      await dataSource.updateOrderStatus('o1', 'delivered');
      await dataSource.updateOrderStatus('o1', 'cancelled');

      final data = await readB2B('o1');
      expect(data['status'], 'cancelled');
      expect(data['deliveryDate'], isA<Timestamp>());
      expect(data['cancellationDate'], isA<Timestamp>());
    });

    test('cancelled -> processing reopens but retains the cancel stamp',
        () async {
      await seedB2B('o1');

      await dataSource.updateOrderStatus('o1', 'cancelled');
      await dataSource.updateOrderStatus('o1', 'processing');

      final data = await readB2B('o1');
      expect(data['status'], 'processing');
      expect(data['updatedAt'], isA<Timestamp>());
      // Stale stamp persists: nothing is ever cleared.
      expect(data['cancellationDate'], isA<Timestamp>());
    });

    test('shipped -> processing (backward) keeps the shipped stamp', () async {
      await seedB2B('o1');

      await dataSource.updateOrderStatus('o1', 'shipped');
      await dataSource.updateOrderStatus('o1', 'processing');

      final data = await readB2B('o1');
      expect(data['status'], 'processing');
      expect(data['shippedDate'], isA<Timestamp>());
    });

    test('backward move onto a stamped state keeps both stamps', () async {
      await seedB2B('o1');

      await dataSource.updateOrderStatus('o1', 'shipped');
      await dataSource.updateOrderStatus('o1', 'processing');
      await dataSource.updateOrderStatus('o1', 'shipped');

      final data = await readB2B('o1');
      expect(data['status'], 'shipped');
      expect(data['shippedDate'], isA<Timestamp>());
      expect(data['updatedAt'], isA<Timestamp>());
    });

    test('repeating the same status rewrites updatedAt without new stamps',
        () async {
      await seedB2B('o1', status: 'processing');

      await dataSource.updateOrderStatus('o1', 'processing');

      final data = await readB2B('o1');
      expect(data['status'], 'processing');
      expect(data['updatedAt'], isA<Timestamp>());
      expect(data.containsKey('deliveryDate'), isFalse);
      expect(data.containsKey('shippedDate'), isFalse);
      expect(data.containsKey('cancellationDate'), isFalse);
    });

    test('unknown status mid-life is stored, later delivered still stamps',
        () async {
      await seedB2B('o1', status: 'processing');

      await dataSource.updateOrderStatus('o1', 'archived');
      expect((await readB2B('o1'))['status'], 'archived');

      await dataSource.updateOrderStatus('o1', 'delivered');
      final data = await readB2B('o1');
      expect(data['status'], 'delivered');
      expect(data['deliveryDate'], isA<Timestamp>());
    });
  });

  group('A8: B2C status transitions', () {
    test('forward chain on consumerorders accumulates stamps', () async {
      await seedB2C('c-o1');

      await dataSource.updateOrderStatus('c-o1', 'processing');
      await dataSource.updateOrderStatus('c-o1', 'shipped');
      await dataSource.updateOrderStatus('c-o1', 'delivered');

      final data = await readB2C('c-o1');
      expect(data['status'], 'delivered');
      expect(data['updatedAt'], isA<Timestamp>());
      expect(data['shippedDate'], isA<Timestamp>());
      expect(data['deliveryDate'], isA<Timestamp>());
      expect(data.containsKey('cancellationDate'), isFalse);
      // B2C doc untouched in the B2B collection.
      expect(await fake.collection('orders').get().then((s) => s.docs),
          isEmpty);
    });

    test('B2C cancel then reopen retains the cancel stamp', () async {
      await seedB2C('c-o1');

      await dataSource.updateOrderStatus('c-o1', 'cancelled');
      await dataSource.updateOrderStatus('c-o1', 'processing');

      final data = await readB2C('c-o1');
      expect(data['status'], 'processing');
      expect(data['cancellationDate'], isA<Timestamp>());
    });

    test('B2C delivered -> cancelled keeps the delivery stamp', () async {
      await seedB2C('c-o1');

      await dataSource.updateOrderStatus('c-o1', 'delivered');
      await dataSource.updateOrderStatus('c-o1', 'cancelled');

      final data = await readB2C('c-o1');
      expect(data['status'], 'cancelled');
      expect(data['deliveryDate'], isA<Timestamp>());
      expect(data['cancellationDate'], isA<Timestamp>());
    });
  });
}
