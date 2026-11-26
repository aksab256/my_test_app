import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_test_app/screens/buyer/credit_consent_dialog.dart';
import 'package:my_test_app/services/credit_application_service.dart';

// التقديم على الأجل: العداد من وثائق الطلبات فقط، وطلب واحد قيد المراجعة.
// 1) الإنشاء لا يزيد العداد. 2) التأكيد/التجهيز لا يزيدانه. 3) الشحن لا يزيد.
// 4) الاستلام يزيد مرة واحدة. 5) تكرار إشعار الاستلام لا يضاعف.
// 6) الملغي/المرتجع لا يُحتسب. 7) خمس فواتير تفتح التقديم.
// 8) لا إرسال دون الموافقة. 9) الإرسال يسجل «قيد المراجعة».
// 10) لا تكرار أثناء المراجعة. 11) إعادة الفتح لا تفقد العداد أو الحالة.

Future<void> seedOrder(
  FakeFirebaseFirestore fake,
  String id, {
  required String status,
  String? paymentMethod,
  String buyerId = 'u1',
}) {
  return fake.collection('orders').doc(id).set({
    'buyer': {'id': buyerId},
    'status': status,
    if (paymentMethod != null) 'paymentMethod': paymentMethod,
    'total': 100,
  });
}

void main() {
  group('eligibleCreditInvoiceIds (pure)', () {
    MapEntry<String, Map<String, dynamic>> e(
      String id,
      String status, [
      String? pay,
    ]) =>
        MapEntry(id, {
          'status': status,
          if (pay != null) 'paymentMethod': pay,
        });

    test('new/processing/shipped do not count', () {
      expect(
        CreditApplicationService.eligibleCreditInvoiceIds([
          e('a', 'new-order'),
          e('b', 'processing'),
          e('c', 'shipped'),
        ]),
        isEmpty,
      );
    });

    test('delivered cash counts once even when read twice', () {
      final ids = CreditApplicationService.eligibleCreditInvoiceIds([
        e('a', 'delivered', 'cash_on_delivery'),
        e('a', 'delivered', 'cash_on_delivery'),
      ]);
      expect(ids, {'a'});
    });

    test('cancelled and returned never count', () {
      expect(
        CreditApplicationService.eligibleCreditInvoiceIds([
          e('a', 'cancelled'),
          e('b', 'returned'),
          e('c', 'delivered', 'cash_on_delivery'),
        ]),
        {'c'},
      );
    });

    test('online payment is excluded, missing method counts as cash', () {
      expect(
        CreditApplicationService.eligibleCreditInvoiceIds([
          e('a', 'delivered', 'online'),
          e('b', 'delivered'),
          e('c', 'delivered', 'cash'),
        ]),
        {'b', 'c'},
      );
    });

    test('threshold helper', () {
      expect(CreditApplicationService.isEligible(4), isFalse);
      expect(CreditApplicationService.isEligible(5), isTrue);
      expect(CreditApplicationService.isEligible(9), isTrue);
    });
  });

  group('counting against FakeFirestore', () {
    late FakeFirebaseFirestore fake;
    late CreditApplicationService service;

    setUp(() {
      fake = FakeFirebaseFirestore();
      service = CreditApplicationService(db: fake);
    });

    test('lifecycle: only receipt confirmation counts, once', () async {
      await seedOrder(fake, 'o1', status: 'new-order');
      expect(await service.fetchEligibleCount('u1'), 0);
      await fake.collection('orders').doc('o1').update({'status': 'processing'});
      expect(await service.fetchEligibleCount('u1'), 0);
      await fake.collection('orders').doc('o1').update({'status': 'shipped'});
      expect(await service.fetchEligibleCount('u1'), 0);
      // تأكيد الاستلام.
      await fake.collection('orders').doc('o1').update({'status': 'delivered'});
      expect(await service.fetchEligibleCount('u1'), 1);
      // تكرار إشعار الحالة نفسه لا يضاعف.
      await fake.collection('orders').doc('o1').update({'status': 'delivered'});
      expect(await service.fetchEligibleCount('u1'), 1);
    });

    test('cancelled order is not counted', () async {
      await seedOrder(fake, 'o1', status: 'delivered');
      await seedOrder(fake, 'o2', status: 'cancelled');
      expect(await service.fetchEligibleCount('u1'), 1);
    });

    test('five receipts open submission; other buyers are isolated', () async {
      for (var i = 0; i < 5; i++) {
        await seedOrder(fake, 'o$i', status: 'delivered');
      }
      await seedOrder(fake, 'x', status: 'delivered', buyerId: 'u2');
      expect(await service.fetchEligibleCount('u1'), 5);
      expect(CreditApplicationService.isEligible(5), isTrue);
    });
  });

  group('submitApplication', () {
    late FakeFirebaseFirestore fake;
    late CreditApplicationService service;

    setUp(() async {
      fake = FakeFirebaseFirestore();
      service = CreditApplicationService(db: fake);
      for (var i = 0; i < 5; i++) {
        await seedOrder(fake, 'o$i', status: 'delivered');
      }
    });

    Future<void> submit() => service.submitApplication(
          uid: 'u1',
          merchantName: 'متجر النور',
          merchantPhone: '01000000000',
          merchantAddress: 'القاهرة',
        );

    test('creates a record with under-review status', () async {
      await submit();
      final app = await service.fetchApplication('u1');
      expect(app?['status'],
          CreditApplicationService.applicationUnderReview);
      expect(app?['uid'], 'u1');
      expect(app?['merchantName'], 'متجر النور');
      expect(app?['merchantPhone'], '01000000000');
      expect(app?['merchantAddress'], 'القاهرة');
      expect(app?['eligibleCount'], 5);
      expect(app?['consent'], isTrue);
      expect(app?['consentText'],
          CreditApplicationService.consentText);
    });

    test('duplicate submit while under review is rejected', () async {
      await submit();
      expect(
        submit,
        throwsA(isA<CreditApplicationException>()
            .having((e) => e.code, 'code', 'under_review')),
      );
      final app = await service.fetchApplication('u1');
      expect(app?['status'],
          CreditApplicationService.applicationUnderReview);
    });

    test('below threshold cannot submit', () async {
      final empty = CreditApplicationService(db: FakeFirebaseFirestore());
      expect(
        () => empty.submitApplication(
          uid: 'u9',
          merchantName: 'x',
          merchantPhone: 'y',
          merchantAddress: 'z',
        ),
        throwsA(isA<CreditApplicationException>()
            .having((e) => e.code, 'code', 'not_eligible')),
      );
    });

    test('fresh instance sees the same count and application', () async {
      await submit();
      final reopened = CreditApplicationService(db: fake);
      expect(await reopened.fetchEligibleCount('u1'), 5);
      final app = await reopened.fetchApplication('u1');
      expect(app?['status'],
          CreditApplicationService.applicationUnderReview);
    });
  });

  group('CreditConsentDialog', () {
    Future<void> openDialog(
      WidgetTester tester, {
      required Future<void> Function() onSubmit,
      required List<bool> closed,
    }) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => CreditConsentDialog(
                    merchantName: 'متجر النور',
                    merchantPhone: '01000000000',
                    merchantAddress: 'القاهرة',
                    onSubmit: onSubmit,
                  ),
                );
                closed.add(ok ?? false);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Finder submitBtn() =>
        find.widgetWithText(ElevatedButton, 'إرسال طلب التقديم');

    testWidgets('submit is disabled until the declaration is accepted',
        (tester) async {
      var submitted = false;
      await openDialog(tester,
          onSubmit: () async => submitted = true, closed: []);
      expect(tester.widget<ElevatedButton>(submitBtn()).onPressed, isNull);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      expect(tester.widget<ElevatedButton>(submitBtn()).onPressed, isNotNull);
      await tester.tap(submitBtn());
      await tester.pumpAndSettle();
      expect(submitted, isTrue);
    });

    testWidgets('cancel closes without submitting', (tester) async {
      var submitted = false;
      final closed = <bool>[];
      await openDialog(tester,
          onSubmit: () async => submitted = true, closed: closed);
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(submitted, isFalse);
      expect(closed, [false]);
    });
  });
}
