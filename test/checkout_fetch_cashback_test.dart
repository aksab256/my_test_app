import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_test_app/controllers/checkout_controller.dart';

// A3: قراءة رصيد الـCashback حسب الـrole عبر CheckoutController.fetchCashback.
//
// المرجع: الدور 'consumer' يقرأ consumers/{id}.cashbackBalance،
// وأي دور آخر يقرأ users/{id}.cashback.
// القيم الـString الرقمية تُحوَّل (توحيدًا مع CashbackProvider)،
// والسالب يُثبَّت عند 0 عبر max(0.0, ...).
// يستخدم الـfirestore seam فقط، دون أي production seam جديد.
void main() {
  late FakeFirebaseFirestore fake;

  setUp(() {
    fake = FakeFirebaseFirestore();
  });

  group('A3: fetchCashback role-based balance reading', () {
    test('buyer reads users/{id}.cashback, not the consumer collection',
        () async {
      await fake.collection('users').doc('u1').set({'cashback': 25.5});
      await fake
          .collection('consumers')
          .doc('u1')
          .set({'cashbackBalance': 999.0});

      expect(
        await CheckoutController.fetchCashback('u1', 'buyer', firestore: fake),
        25.5,
      );
    });

    test('consumer reads consumers/{id}.cashbackBalance, not users',
        () async {
      await fake
          .collection('consumers')
          .doc('c1')
          .set({'cashbackBalance': 60.0});
      await fake.collection('users').doc('c1').set({'cashback': 999.0});

      expect(
        await CheckoutController.fetchCashback('c1', 'consumer',
            firestore: fake),
        60.0,
      );
    });

    test('reads int balances as double', () async {
      await fake.collection('users').doc('u2').set({'cashback': 30});

      expect(
        await CheckoutController.fetchCashback('u2', 'buyer', firestore: fake),
        30.0,
      );
    });

    test('numeric string balances are parsed on both roles', () async {
      await fake.collection('users').doc('u3').set({'cashback': '30'});
      await fake
          .collection('consumers')
          .doc('c3')
          .set({'cashbackBalance': '45.5'});

      expect(
        await CheckoutController.fetchCashback('u3', 'buyer', firestore: fake),
        30.0,
      );
      expect(
        await CheckoutController.fetchCashback('c3', 'consumer',
            firestore: fake),
        45.5,
      );
    });

    test('negative balance is clamped to zero', () async {
      await fake.collection('users').doc('u4').set({'cashback': -10.0});

      expect(
        await CheckoutController.fetchCashback('u4', 'buyer', firestore: fake),
        0.0,
      );
    });

    test('missing field and missing document read as zero', () async {
      await fake.collection('users').doc('u5').set({'phone': '01'});

      expect(
        await CheckoutController.fetchCashback('u5', 'buyer', firestore: fake),
        0.0,
      );
      expect(
        await CheckoutController.fetchCashback('ghost', 'buyer',
            firestore: fake),
        0.0,
      );
    });

    test('empty userId returns zero without touching Firestore', () async {
      final probe = ProbeFirestore(fake);

      expect(
        await CheckoutController.fetchCashback('', 'buyer', firestore: probe),
        0.0,
      );
      expect(probe.touched, isFalse);
    });

    test('firestore error returns zero (current behavior)', () async {
      await fake.collection('users').doc('u1').set({'cashback': 20.0});
      final probe = ProbeFirestore(fake)..fail = true;

      expect(
        await CheckoutController.fetchCashback('u1', 'buyer', firestore: probe),
        0.0,
      );
    });
  });
}

// Test-only Firestore wrapper: optional failure mode + touch tracking,
// بنفس نمط FlakyFirestore في cashback_provider_test.dart.
class ProbeFirestore implements FirebaseFirestore {
  final FakeFirebaseFirestore real;
  bool fail = false;
  bool touched = false;

  ProbeFirestore(this.real);

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    touched = true;
    if (fail) throw Exception('firestore down');
    return real.collection(path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
