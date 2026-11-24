// test/create_bundle_screen_test.dart
//
// Seller create-bundle screen: dropdown details, requested-count gate,
// success clearing, and cover-failure consistency. No Firebase, no network:
// a fake BundleServiceGateway and a fake Cloudinary HTTP client.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sizer/sizer.dart';

import 'package:my_test_app/data_sources/bundle_cover_service.dart';
import 'package:my_test_app/data_sources/bundle_data_source.dart';
import 'package:my_test_app/screens/seller/create_bundle_screen.dart';

BundleCatalogRow _row(String offer, String name, int avail) =>
    BundleCatalogRow(
      offerId: offer,
      productId: 'prod-$offer',
      productName: name,
      imageUrl: null, // imageless: fallback tiles, zero network
      unitIndex: 0,
      unitName: 'علبة',
      price: 100.0,
      physicalStock: avail,
      giftReserved: 0,
      bundleReserved: 0,
    );

class _FakeGateway implements BundleServiceGateway {
  final List<BundleCatalogRow> rows;
  Map<String, dynamic>? lastCreate;
  Map<String, dynamic>? lastUpdate;

  _FakeGateway(this.rows);

  @override
  Future<List<BundleCatalogRow>> loadSellerCatalog(String sellerId,
          {bool activeOnly = true}) async =>
      rows;

  @override
  Future<List<BundleCatalogRow>> refetchRows(
          List<Map<String, dynamic>> items) async =>
      rows;

  @override
  Future<Map<String, dynamic>> loadSellerProfile(String sellerId) async => {
        'sellerName': 'متجر',
        'sellerPhone': '010',
        'deliveryAreas': ['A'],
        'deliveryZonesSource': 'sellers/s1.deliveryAreas',
      };

  @override
  Future<Map<String, dynamic>> createBundle({
    required String bundleName,
    required List<Map<String, dynamic>> items,
    required double totalPrice,
    required String idempotencyKey,
    int bundleCount = 1,
    String description = '',
    String currency = 'EGP',
    String sellerName = '',
    String sellerPhone = '',
    List<String> deliveryZones = const [],
    String? deliveryZonesSource,
    String? coverImagePath,
    String? coverImageUrl,
    String? coverUpdatedAt,
    int coverVersion = 0,
    String coverStatus = 'missing',
  }) async {
    lastCreate = {
      'bundleName': bundleName,
      'items': items,
      'totalPrice': totalPrice,
      'bundleCount': bundleCount,
    };
    return {
      'bundleId': 'b1',
      'bundleCount': bundleCount,
      'remainingCount': bundleCount
    };
  }

  @override
  Future<Map<String, dynamic>> updateBundleItems({
    required String bundleId,
    required List<Map<String, dynamic>> items,
    int? bundleCount,
    double? totalPrice,
    String? description,
    List<String>? deliveryZones,
    String? deliveryZonesSource,
    String? coverImagePath,
    String? coverImageUrl,
    String? coverUpdatedAt,
    int? coverVersion,
    String? coverStatus,
  }) async {
    lastUpdate = {'bundleId': bundleId, 'coverStatus': coverStatus};
    return {'success': true};
  }
}

class _FakeCloudinary extends http.BaseClient {
  final int status;
  int calls = 0;

  _FakeCloudinary({this.status = 200});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls++;
    if (status != 200) {
      return http.StreamedResponse(
          Stream.value(utf8.encode('{"error":"boom"}')), status);
    }
    return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({
          'public_id': 'bundle_covers/t1',
          'secure_url':
              'https://res.cloudinary.com/dgmmx6jbu/image/upload/v1/bundle_covers/t1.jpg',
        }))),
        200);
  }
}

List<BundleCatalogRow> _catalog() => [
      _row('p1', 'الأول', 20),
      _row('p2', 'الثاني', 5),
      _row('p3', 'الثالث', 100),
    ];

Future<void> _pump(WidgetTester tester,
    {required _FakeGateway gateway,
    required _FakeCloudinary cloud}) async {
  await tester.pumpWidget(
    Sizer(
      builder: (context, orientation, screenType) => MaterialApp(
        home: CreateBundleScreen(
          sellerId: 's1',
          gateway: gateway,
          coverService: BundleCoverService(httpClient: cloud),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Scrolls inside the form's SingleChildScrollView before tapping:
///
/// the dropdown title and the submit button sit below the fold.
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _fillForm(WidgetTester tester,
    {required String count,
    required String name,
    required String price}) async {
  await tester.enterText(
      find.widgetWithText(TextFormField, 'عدد البندلات المتاحة للبيع'),
      count);
  await tester.enterText(
      find.widgetWithText(TextFormField, 'اسم البندل'), name);
  await tester.enterText(
      find.widgetWithText(TextFormField, 'السعر الإجمالي للبندل (ج.م)'),
      price);
  await tester.pump();
}

void main() {
  group('create_bundle_screen', () {
    testWidgets('product details live in a dropdown, summary stays outside',
        (tester) async {
      final gateway = _FakeGateway(_catalog());
      await _pump(tester, gateway: gateway, cloud: _FakeCloudinary());

      expect(find.text('تفاصيل المنتجات (3)'), findsOneWidget);
      // Summary prices appear once the bundle price is entered.
      await tester.enterText(
          find.widgetWithText(
              TextFormField, 'السعر الإجمالي للبندل (ج.م)'),
          '400');
      await tester.pump();
      // Collapsed: details are offstage.
      expect(find.text('الأول (علبة)', skipOffstage: true), findsNothing);

      await _tapVisible(tester, find.text('تفاصيل المنتجات (3)'));

      expect(find.text('الأول (علبة)', skipOffstage: false), findsWidgets);
      expect(find.textContaining('الكمية داخل البندل الواحد: 1'),
          findsWidgets);
      expect(find.textContaining('سعر الوحدة: 100.00'), findsWidgets);
      expect(find.textContaining('إجمالي الكمية:'), findsWidgets);
      // Summary (price/saving/max) is visible without opening the dropdown.
      expect(find.textContaining('سعر البندل الواحد:'), findsOneWidget);
      expect(find.textContaining('يمكن إتاحة 1 بندل للبيع'),
          findsOneWidget);
    });

    testWidgets('request above max is blocked and names the limiter',
        (tester) async {
      final gateway = _FakeGateway(_catalog());
      await _pump(tester, gateway: gateway, cloud: _FakeCloudinary());

      await _fillForm(tester, count: '6', name: 'بندل', price: '400');
      await _tapVisible(tester,
          find.widgetWithText(ElevatedButton, 'إنشاء البندل وحجز المخزون'));

      expect(gateway.lastCreate, isNull);
      // Shown twice: the submit message and the live count summary.
      expect(find.textContaining('الحد الأقصى 5'), findsWidgets);
      expect(find.textContaining('الثاني'), findsWidgets);
    });

    testWidgets('valid request creates N bundles and clears the form',
        (tester) async {
      final gateway = _FakeGateway(_catalog());
      await _pump(tester, gateway: gateway, cloud: _FakeCloudinary());

      await _fillForm(tester, count: '5', name: 'بندل الاختبار', price: '400');
      await _tapVisible(tester,
          find.widgetWithText(ElevatedButton, 'إنشاء البندل وحجز المخزون'));

      expect(gateway.lastCreate, isNotNull);
      expect(gateway.lastCreate!['bundleCount'], 5);
      expect(gateway.lastCreate!['bundleName'], 'بندل الاختبار');
      expect(find.textContaining('تم إنشاء البندل بنجاح'), findsOneWidget);
      expect(
          find.textContaining('عدد البندلات المتاحة للبيع: 5'), findsOneWidget);
      // Form cleared: name empty, count reset, selection cleared.
      expect(
          find.widgetWithText(
              TextFormField, 'عدد البندلات المتاحة للبيع'),
          findsOneWidget);
      final countField = tester.widget<TextFormField>(find
          .widgetWithText(TextFormField, 'عدد البندلات المتاحة للبيع'));
      expect(countField.controller!.text, '1');
      expect(find.text('تفاصيل المنتجات (0)'), findsOneWidget);
    });

    testWidgets('cover failure keeps the reservation and the selections',
        (tester) async {
      final gateway = _FakeGateway(_catalog());
      await _pump(
          tester, gateway: gateway, cloud: _FakeCloudinary(status: 500));

      await _fillForm(tester, count: '5', name: 'بندل الاختبار', price: '400');
      await _tapVisible(tester,
          find.widgetWithText(ElevatedButton, 'إنشاء البندل وحجز المخزون'));

      // Step 1 succeeded (reservation exists), step 2 failed: no success
      // styling, selections kept for retry.
      expect(gateway.lastCreate, isNotNull);
      expect(find.textContaining('تعذر رفع الغلاف'), findsOneWidget);
      expect(find.textContaining('اختياراتك محفوظة'), findsOneWidget);
      expect(find.text('تفاصيل المنتجات (3)'), findsOneWidget);
    });
  });
}
