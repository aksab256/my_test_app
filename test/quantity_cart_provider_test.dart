// test/quantity_cart_provider_test.dart
//
// اختبارات تكامل المزود لحدود الكمية (FakeFirestore + SharedPreferences mock):
// - addItemToCart يرفض فوق السقف وتحت الحد الأدنى.
// - changeQty لا يتجاوز effectiveMax.
// - loadCartAndRecalculate يعلّم الأصناف التي سقط مخزونها.
// - validateCheckoutQuantities بوابة الإرسال الأخيرة.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_test_app/models/banner_model.dart';
import 'package:my_test_app/models/category_model.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:my_test_app/services/marketplace_data_service.dart';

class StubMarketplaceDataService implements MarketplaceDataService {
  @override
  Future<List<BannerModel>> fetchBanners(String ownerId) async => [];

  @override
  Future<List<CategoryModel>> fetchCategoriesByOffers(String ownerId) async =>
      [];

  @override
  Future<List<CategoryModel>> fetchSubCategoriesByOffers(
          String mainCategoryId, String ownerId) async =>
      [];

  @override
  Future<List<Map<String, dynamic>>> fetchProductsAndOffersBySubCategory({
    required String ownerId,
    required String mainId,
    required String subId,
  }) async =>
      [];

  @override
  Future<String> fetchSupermarketNameById(String ownerId) async => '';
}

Future<void> seedOffer(
  FakeFirebaseFirestore fake, {
  String offerId = 'offer-1',
  int stock = 5,
  int? minOrder,
  int? maxOrder,
}) async {
  final data = <String, dynamic>{
    'units': [
      {'unitName': 'piece', 'price': 25.0, 'availableStock': stock},
    ],
    'status': 'active',
  };
  if (minOrder != null) data['minOrder'] = minOrder;
  if (maxOrder != null) data['maxOrder'] = maxOrder;
  await fake.collection('productOffers').doc(offerId).set(data);
}

Future<void> addSeeded(
  CartProvider provider, {
  String offerId = 'offer-1',
  int quantity = 1,
  int? minOrderQuantity,
  int? availableStock,
  int? maxOrderQuantity,
}) {
  return provider.addItemToCart(
    offerId: offerId,
    productId: 'prod-$offerId',
    sellerId: 's1',
    sellerName: 'Seller s1',
    name: 'Item $offerId',
    price: 25.0,
    unit: 'piece',
    unitIndex: 0,
    quantityToAdd: quantity,
    imageUrl: '',
    userRole: 'buyer',
    minOrderQuantity: minOrderQuantity ?? 1,
    availableStock: availableStock,
    maxOrderQuantity: maxOrderQuantity,
  );
}

Future<void> settle(CartProvider provider) async {
  final prefs = await SharedPreferences.getInstance();
  for (var i = 0; i < 200; i++) {
    if (prefs.getString('cartItems') != null) break;
    await Future.delayed(const Duration(milliseconds: 5));
  }
  await provider.loadCartAndRecalculate('buyer');
}

void main() {
  late FakeFirebaseFirestore fake;
  late CartProvider provider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fake = FakeFirebaseFirestore();
    provider = CartProvider(
      db: fake,
      dataService: StubMarketplaceDataService(),
    );
  });

  group('addItemToCart: السقف الإجباري', () {
    test('available 5 / request 6 مرفوضة', () async {
      await expectLater(
        addSeeded(provider, quantity: 6, availableStock: 5),
        throwsA(predicate((e) => '$e'.contains('تجاوز الحد المتاح'))),
      );
    });

    test('available 5 / request 5 مقبولة', () async {
      await addSeeded(provider, quantity: 5, availableStock: 5);
      await settle(provider);
      expect(provider.sellersOrders['s1']!.items.single.quantity, equals(5));
    });

    test('تحت الحد الأدنى مرفوضة', () async {
      await expectLater(
        addSeeded(provider,
            quantity: 1, minOrderQuantity: 3, availableStock: 10),
        throwsA(predicate((e) => '$e'.contains('أقل من الحد الأدنى'))),
      );
    });

    test('min أكبر من المخزون: لا كمية صالحة', () async {
      await expectLater(
        addSeeded(provider,
            quantity: 5, minOrderQuantity: 5, availableStock: 3),
        throwsA(predicate((e) => '$e'.contains('الحد الأدنى'))),
      );
    });
  });

  group('changeQty: زر + محكوم بالسقف', () {
    test('لا يتجاوز effectiveMax رغم تكرار الضغط', () async {
      await seedOffer(fake, stock: 10, maxOrder: 10);
      await addSeeded(provider,
          quantity: 5, minOrderQuantity: 1, availableStock: 10,
          maxOrderQuantity: 10);
      await settle(provider);
      final item = provider.sellersOrders['s1']!.items.single;
      for (var i = 0; i < 8; i++) {
        await provider.changeQty(item, 1, 'buyer');
      }
      final qty = provider.sellersOrders['s1']!.items.single.quantity;
      expect(qty, equals(10));
    });
  });

  group('loadCartAndRecalculate: تعليم الأصناف الساقطة', () {
    test('مخزون سقط تحت كمية السلة يمنع الانتقال', () async {
      await seedOffer(fake, stock: 5);
      await addSeeded(provider, quantity: 5, availableStock: 5);
      await settle(provider);
      expect(provider.hasQuantityErrors, isFalse);

      await seedOffer(fake, stock: 2);
      await provider.loadCartAndRecalculate('buyer');
      expect(provider.hasQuantityErrors, isTrue);
      expect(provider.quantityErrorFor('offer-1', 0), isNotNull);
    });
  });

  group('validateCheckoutQuantities: بوابة الإرسال', () {
    test('كمية صالحة تمر بدون أخطاء', () async {
      await seedOffer(fake, stock: 5, minOrder: 1, maxOrder: 5);
      await addSeeded(provider,
          quantity: 5,
          minOrderQuantity: 1,
          availableStock: 5,
          maxOrderQuantity: 5);
      await settle(provider);
      final items = provider.sellersOrders['s1']!.items
          .map((e) => e.toJson())
          .toList();
      final errors = await provider.validateCheckoutQuantities([
        {'sellerId': 's1', 'sellerName': 'Seller s1', 'items': items},
      ], 'buyer');
      expect(errors, isEmpty);
    });

    test('كمية زائدة بعد تغير المخزون تُرفض قبل placeOrder', () async {
      await seedOffer(fake, stock: 5);
      await addSeeded(provider, quantity: 5, availableStock: 5);
      await settle(provider);
      await seedOffer(fake, stock: 2);
      final items = provider.sellersOrders['s1']!.items
          .map((e) => e.toJson())
          .toList();
      final errors = await provider.validateCheckoutQuantities([
        {'sellerId': 's1', 'sellerName': 'Seller s1', 'items': items},
      ], 'buyer');
      expect(errors, isNotEmpty);
    });

    test('حد التاجر الإجمالي يُفحص ولا يمنع زر + لمنتج', () async {
      await seedOffer(fake, stock: 10);
      await fake.collection('sellers').doc('s1').set({
        'minOrderTotal': 500.0,
        'deliveryFee': 0.0,
      });
      await addSeeded(provider, quantity: 2, availableStock: 10);
      await settle(provider);
      final items = provider.sellersOrders['s1']!.items
          .map((e) => e.toJson())
          .toList();
      final errors = await provider.validateCheckoutQuantities([
        {'sellerId': 's1', 'sellerName': 'Seller s1', 'items': items},
      ], 'buyer');
      expect(errors.any((e) => e.contains('الحد الأدنى')), isTrue);
    });
  });
}
