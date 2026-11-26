import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_test_app/models/banner_model.dart';
import 'package:my_test_app/models/category_model.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:my_test_app/screens/product_details_screen.dart';
import 'package:my_test_app/services/marketplace_data_service.dart';

// انحدار صفحة التفاصيل: `type 'int' is not a subtype of type 'double'`
// Firestore يعيد الأعداد الصحيحة كـ int، ووسيط السعر double —
// resolveDetailsPrice يوحّد int/double عبر num.toDouble.

class _StubMarketplaceDataService implements MarketplaceDataService {
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

void main() {
  group('resolveDetailsPrice', () {
    test('int offerPrice normalizes to double', () {
      expect(resolveDetailsPrice(45, 60), 45.0);
    });

    test('double offerPrice passes through', () {
      expect(resolveDetailsPrice(45.5, 60), 45.5);
    });

    test('null offerPrice falls back to int price', () {
      expect(resolveDetailsPrice(null, 60), 60.0);
    });

    test('null offerPrice falls back to double price', () {
      expect(resolveDetailsPrice(null, 60.25), 60.25);
    });

    test('non-positive offerPrice falls back to price', () {
      expect(resolveDetailsPrice(0, 60), 60.0);
      expect(resolveDetailsPrice(-5, 60), 60.0);
    });

    test('non-numeric values resolve to 0.0, never a false price', () {
      expect(resolveDetailsPrice('45', '60'), 0.0);
      expect(resolveDetailsPrice(null, null), 0.0);
      expect(resolveDetailsPrice(null, '?'), 0.0);
    });

    test('result is assignable to a double parameter', () {
      double takeDouble(double v) => v;
      expect(takeDouble(resolveDetailsPrice(45, 60)), 45.0);
      expect(takeDouble(resolveDetailsPrice(45.5, 60)), 45.5);
    });
  });

  group('details add-to-cart with int Firestore prices', () {
    late FakeFirebaseFirestore fake;
    late CartProvider provider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      fake = FakeFirebaseFirestore();
      provider =
          CartProvider(db: fake, dataService: _StubMarketplaceDataService());
    });

    test('int offerPrice adds successfully at normalized price', () async {
      await fake.collection('productOffers').doc('offer-1').set({
        'productId': 'prod-1',
        'sellerId': 's1',
        'sellerName': 'Seller s1',
        'status': 'active',
        'minOrder': 1,
        'offerPrice': 45,
        'units': [
          {'unitName': 'piece', 'price': 60, 'availableStock': 50},
        ],
      });

      // نفس ما تمرره شاشة التفاصيل الآن بعد الإصلاح.
      final double price = resolveDetailsPrice(45, 60);

      await provider.addItemToCart(
        offerId: 'offer-1',
        productId: 'prod-1',
        sellerId: 's1',
        sellerName: 'Seller s1',
        name: 'Item 1',
        price: price,
        unit: 'piece',
        unitIndex: 0,
        quantityToAdd: 1,
        imageUrl: '',
        userRole: 'buyer',
      );
      await provider.loadCartAndRecalculate('buyer');

      final item = provider.sellersOrders['s1']!.items.single;
      expect(item.price, 45.0);
    });
  });
}
