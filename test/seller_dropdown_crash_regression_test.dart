import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizer/sizer.dart';

import 'package:my_test_app/data_sources/order_data_source.dart';
import 'package:my_test_app/screens/orders_screen.dart';

// B2: seller status dropdown crashes on unlisted B2C statuses.
//
// CHAIN: fromConsumerFirestore keeps the raw status (no allow-list, unlike
// the B2B factory) -> _buildStatusDropdown passes it as DropdownButton value
// while offering only the 5 listed statuses -> framework assertion.
// Uses the injected OrderDataSource seam only; no business logic changed.
// The REGRESSION test fails until the crash is fixed; the control test
// proves the harness is valid (same flow, listed status -> clean render).
void main() {
  Map<String, dynamic> b2cOrder(String status) => {
        'supermarketId': 'seller-1',
        'customerId': 'c1',
        'customerName': 'Consumer c1',
        'customerPhone': '02000000000',
        'customerAddress': 'Consumer Ave',
        'orderDate': Timestamp.fromDate(DateTime.utc(2026, 1, 20)),
        'status': status,
        'items': const [
          {'name': 'Milk', 'quantity': 2, 'unit': 'pc', 'price': 50.0},
        ],
        'subtotalPrice': 100.0,
        'finalAmount': 90.0,
      };

  Future<void> pumpScreen(
    WidgetTester tester,
    OrderDataSource dataSource,
  ) async {
    await tester.pumpWidget(
      Sizer(
        builder: (context, orientation, deviceType) => MaterialApp(
          home: OrdersScreen(
            sellerId: 'seller-1',
            dataSource: dataSource,
          ),
        ),
      ),
    );
    // Resolve the loadOrders future into the list.
    await tester.pump();
  }

  Future<void> expandFirstOrder(WidgetTester tester) async {
    await tester.tap(find.byType(ExpansionTile));
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('B2: unlisted B2C status vs seller dropdown', () {
    testWidgets(
        'REGRESSION (fails): archived B2C order crashes the dropdown',
        (tester) async {
      final fake = FakeFirebaseFirestore();
      await fake
          .collection('consumerorders')
          .doc('b2c-weird')
          .set(b2cOrder('archived'));

      await pumpScreen(tester, OrderDataSource(db: fake));
      await expandFirstOrder(tester);

      // Pre-fix the DropdownButton assertion fires -> takeException != null.
      expect(tester.takeException(), isNull);
    });

    testWidgets('control: listed status renders the dropdown cleanly',
        (tester) async {
      final fake = FakeFirebaseFirestore();
      await fake
          .collection('consumerorders')
          .doc('b2c-okane')
          .set(b2cOrder('processing'));

      await pumpScreen(tester, OrderDataSource(db: fake));
      await expandFirstOrder(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(DropdownButton<String>), findsOneWidget);
    });
  });
}
