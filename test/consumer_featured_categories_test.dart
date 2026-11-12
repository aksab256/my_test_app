import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_test_app/services/consumer_data_service.dart';

// القاعدة: الأقسام المميزة للمستهلك تظهر بشرط
// offerBehavior == supermarket_offers فقط، دون اعتبار status.
void main() {
  group('consumer featured categories', () {
    late FakeFirebaseFirestore fake;
    late ConsumerDataService service;

    setUp(() async {
      fake = FakeFirebaseFirestore();
      service = ConsumerDataService(firestore: fake);
      await fake.collection('mainCategory').doc('m1').set({
        'name': 'نشط',
        'imageUrl': '',
        'status': 'active',
        'offerBehavior': 'supermarket_offers',
        'order': 1,
      });
      await fake.collection('mainCategory').doc('m2').set({
        'name': 'غير نشط لكن سلوكه للمستهلك',
        'imageUrl': '',
        'status': 'inactive',
        'offerBehavior': 'supermarket_offers',
        'order': 0,
      });
      await fake.collection('mainCategory').doc('m3').set({
        'name': 'بدون حالة',
        'imageUrl': '',
        'offerBehavior': 'supermarket_offers',
        'order': 2,
      });
      await fake.collection('mainCategory').doc('m4').set({
        'name': 'سلوك آخر',
        'imageUrl': '',
        'status': 'active',
        'offerBehavior': 'buyer_only',
        'order': 0,
      });
      await fake.collection('mainCategory').doc('m5').set({
        'name': 'بدون سلوك',
        'imageUrl': '',
        'status': 'active',
        'order': 0,
      });
    });

    test('shows supermarket_offers regardless of status, keeps offerBehavior filter', () async {
      final result = await service.fetchMainCategories();
      expect(result.map((c) => c.id).toList(), ['m2', 'm1', 'm3']);
    });
  });
}
