import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_test_app/repositories/product_repository.dart';

// يثبت أن شاشات المتجر (عبر ProductRepository) لا تعرض الأقسام غير النشطة:
// القسم الرئيسي أو الفرعي الذي تتحول حالته إلى inactive يختفي دون حذفه.
void main() {
  group('category status filtering', () {
    late FakeFirebaseFirestore fake;
    late ProductRepository repo;

    setUp(() async {
      fake = FakeFirebaseFirestore();
      repo = ProductRepository(firestore: fake);
      await fake.collection('mainCategory').doc('m1').set({
        'name': 'نشط أول',
        'imageUrl': '',
        'status': 'active',
        'order': 1,
      });
      await fake.collection('mainCategory').doc('m2').set({
        'name': 'مخفي',
        'imageUrl': '',
        'status': 'inactive',
        'order': 0,
      });
      await fake.collection('mainCategory').doc('m3').set({
        'name': 'بدون حالة',
        'imageUrl': '',
        'order': 2,
      });
      await fake.collection('subCategory').doc('s1').set({
        'name': 'فرعي نشط',
        'mainId': 'm1',
        'imageUrl': '',
        'status': 'active',
        'order': 1,
      });
      await fake.collection('subCategory').doc('s2').set({
        'name': 'فرعي مخفي',
        'mainId': 'm1',
        'imageUrl': '',
        'status': 'inactive',
        'order': 0,
      });
      await fake.collection('subCategory').doc('s3').set({
        'name': 'فرعي بدون حالة',
        'mainId': 'm1',
        'imageUrl': '',
        'order': 2,
      });
    });

    test('fetchMainCategories returns only active categories in order', () async {
      final result = await repo.fetchMainCategories();
      expect(result.map((c) => c.id).toList(), ['m1']);
      expect(result.first.status, isTrue);
    });

    test('fetchSubCategories returns only active subcategories', () async {
      final result = await repo.fetchSubCategories('m1');
      expect(result.map((c) => c.id).toList(), ['s1']);
      expect(result.first.status, isTrue);
    });

    test('reactivating a category makes it visible again', () async {
      await fake.collection('mainCategory').doc('m2').update({'status': 'active'});
      final result = await repo.fetchMainCategories();
      expect(result.map((c) => c.id).toList(), ['m2', 'm1']);
    });
  });
}
