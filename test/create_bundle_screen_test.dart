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
      _row('p4', 'الرابع', 50),
      _row('p5', 'الخامس', 8),
      _row('p6', 'السادس', 30),
    ];

/// Opens the picker sheet and waits for its entrance animation.
Future<void> _openPicker(WidgetTester tester) async {
  await _tapVisible(tester, find.byKey(const Key('open-product-picker')));
}

/// Searches inside the open sheet, then taps the matching result tile.
Future<void> _searchAndPick(WidgetTester tester, String query, String offer,
    {int unit = 0}) async {
  await tester.enterText(
      find.byKey(const Key('product-search-field')), query);
  await tester.pump();
  final tile = find.byKey(Key('picker-result-$offer-$unit'));
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

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
      // Collapsed: per-product detail rows are offstage (the selected
      // list in step 3 intentionally keeps showing names + stock).
      expect(
          find.textContaining('الكمية داخل البندل الواحد',
              skipOffstage: true),
          findsNothing);

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

  group('product_picker', () {
    testWidgets('main screen never renders the full catalog', (tester) async {
      final gateway = _FakeGateway(_catalog());
      await _pump(tester, gateway: gateway, cloud: _FakeCloudinary());

      // 6 catalog rows, but none of the unpicked ones is on screen.
      expect(find.text('الرابع (علبة)'), findsNothing);
      expect(find.text('السادس (علبة)'), findsNothing);
      expect(
          find.byKey(const Key('open-product-picker')), findsOneWidget);
    });

    testWidgets('search by name filters and adds the product', (tester) async {
      final gateway = _FakeGateway(_catalog());
      await _pump(tester, gateway: gateway, cloud: _FakeCloudinary());

      await _openPicker(tester);
      await _searchAndPick(tester, 'الرابع', 'p4');

      // Sheet closed, selection grew 3 -> 4 with full detail in step 3.
      expect(find.text('تفاصيل المنتجات (4)'), findsOneWidget);
      expect(find.textContaining('المختارة:'), findsOneWidget);
      expect(find.textContaining('الرابع'), findsWidgets);
      expect(find.textContaining('كود العرض: p4'), findsWidgets);
      expect(find.textContaining('متاح 50'), findsOneWidget);
    });

    testWidgets('search by offer and product codes finds the product',
        (tester) async {
      final gateway = _FakeGateway(_catalog());
      await _pump(tester, gateway: gateway, cloud: _FakeCloudinary());

      // By offer code.
      await _openPicker(tester);
      await tester.enterText(
          find.byKey(const Key('product-search-field')), 'p5');
      await tester.pump();
      expect(find.byKey(const Key('picker-result-p5-0')), findsOneWidget);
      expect(find.byKey(const Key('picker-result-p6-0')), findsNothing);
      await tester.ensureVisible(
          find.byKey(const Key('picker-result-p5-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('picker-result-p5-0')));
      await tester.pumpAndSettle();
      expect(find.text('تفاصيل المنتجات (4)'), findsOneWidget);

      // By product code (prod-p6) for the next one.
      await _openPicker(tester);
      await tester.enterText(
          find.byKey(const Key('product-search-field')), 'prod-p6');
      await tester.pump();
      expect(find.byKey(const Key('picker-result-p6-0')), findsOneWidget);
      await tester.ensureVisible(
          find.byKey(const Key('picker-result-p6-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('picker-result-p6-0')));
      await tester.pumpAndSettle();
      expect(find.text('تفاصيل المنتجات (5)'), findsOneWidget);
    });

    testWidgets('empty query shows all, gibberish shows empty state',
        (tester) async {
      final gateway = _FakeGateway(_catalog());
      await _pump(tester, gateway: gateway, cloud: _FakeCloudinary());

      await _openPicker(tester);
      expect(find.textContaining('النتائج: 6'), findsOneWidget);
      await tester.enterText(
          find.byKey(const Key('product-search-field')), 'zzzلا-يوجد');
      await tester.pump();
      expect(find.textContaining('لا توجد نتائج مطابقة'), findsWidgets);
      expect(find.byKey(const Key('picker-result-p1-0')), findsNothing);
    });

    testWidgets('picked product cannot duplicate, only toggles',
        (tester) async {
      final gateway = _FakeGateway(_catalog());
      await _pump(tester, gateway: gateway, cloud: _FakeCloudinary());

      // p1 is preselected: it shows as picked, tapping removes it.
      await _openPicker(tester);
      await _searchAndPick(tester, 'الأول', 'p1');
      // Tapping a picked row unpicks WITHOUT closing the sheet: the
      // summary behind it drops to 2 while the search field stays.
      expect(find.text('تفاصيل المنتجات (2)'), findsOneWidget);
      expect(
          find.byKey(const Key('product-search-field')), findsOneWidget);
      await tester.tap(find.text('تم'));
      await tester.pumpAndSettle();
      expect(find.text('تفاصيل المنتجات (2)'), findsOneWidget);

      // Re-adding restores exactly one line.
      await _openPicker(tester);
      await _searchAndPick(tester, 'الأول', 'p1');
      expect(find.text('تفاصيل المنتجات (3)'), findsOneWidget);
    });

    testWidgets('sixth product is blocked with a limit message',
        (tester) async {
      final gateway = _FakeGateway(_catalog());
      await _pump(tester, gateway: gateway, cloud: _FakeCloudinary());

      await _openPicker(tester);
      await _searchAndPick(tester, 'الرابع', 'p4');
      await _openPicker(tester);
      await _searchAndPick(tester, 'الخامس', 'p5');
      expect(find.text('تفاصيل المنتجات (5)'), findsOneWidget);

      await _openPicker(tester);
      await tester.enterText(
          find.byKey(const Key('product-search-field')), 'السادس');
      await tester.pump();
      await tester.ensureVisible(
          find.byKey(const Key('picker-result-p6-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('picker-result-p6-0')));
      await tester.pump();
      // Still 5, sheet open with the limit error.
      expect(find.textContaining('الحد الأقصى 5'), findsWidgets);
      await tester.tap(find.text('تم'));
      await tester.pumpAndSettle();
      expect(find.text('تفاصيل المنتجات (5)'), findsOneWidget);
    });

    testWidgets('qty edits and removal update the max-bundle limit',
        (tester) async {
      final gateway = _FakeGateway(_catalog());
      await _pump(tester, gateway: gateway, cloud: _FakeCloudinary());

      // Preselect: p1(20) p2(5) p3(100) -> limiter is الثاني at 5.
      expect(find.textContaining('الحد الأقصى 5'), findsOneWidget);
      await _tapVisible(tester, find.byKey(const Key('qty-inc-1')));
      expect(find.textContaining('الحد الأقصى 2'), findsOneWidget);
      await _tapVisible(tester, find.byKey(const Key('qty-del-1')));
      expect(find.text('تفاصيل المنتجات (2)'), findsOneWidget);
      expect(find.textContaining('الحد الأقصى 20'), findsOneWidget);
    });

    testWidgets('selections survive a screen rebuild', (tester) async {
      final gateway = _FakeGateway(_catalog());
      await _pump(tester, gateway: gateway, cloud: _FakeCloudinary());

      await _openPicker(tester);
      await _searchAndPick(tester, 'الرابع', 'p4');
      expect(find.text('تفاصيل المنتجات (4)'), findsOneWidget);

      // Any setState rebuild (typing the price) keeps the selection.
      await tester.enterText(
          find.widgetWithText(
              TextFormField, 'السعر الإجمالي للبندل (ج.م)'),
          '400');
      await tester.pump();
      expect(find.text('تفاصيل المنتجات (4)'), findsOneWidget);
      expect(find.textContaining('الرابع'), findsWidgets);
      expect(find.textContaining('يمكن إتاحة 1 بندل للبيع'),
          findsOneWidget);
    });

    testWidgets('large catalogs are capped inside the sheet', (tester) async {
      final big = List<BundleCatalogRow>.generate(
          40, (i) => _row('px$i', 'منتج $i', 100));
      final gateway = _FakeGateway(big);
      await _pump(tester, gateway: gateway, cloud: _FakeCloudinary());

      await _openPicker(tester);
      expect(find.textContaining('عرض أول 30'), findsOneWidget);
      expect(find.byKey(const Key('picker-result-px30-0')), findsNothing);
    });
  });
}
