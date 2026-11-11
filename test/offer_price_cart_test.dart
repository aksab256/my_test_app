import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_test_app/models/banner_model.dart';
import 'package:my_test_app/models/category_model.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:my_test_app/services/marketplace_data_service.dart';

// انحدار عرض السعر: سعر العرض (offerPrice) يجب أن ينجو من إعادة حساب
// السلة حتى الفاتورة — لا يُعاد كتابته بالسعر الأساسي.
// القاعدة: offerPrice (وحدة ثم جذر) أولاً، ثم السعر الأساسي.
// originalPrice يُختم للعرض المشطوب "سعر كذا بدل كذا" في الطلب/الفاتورة.

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

Future<void> settle(CartProvider provider) async {
  final prefs = await SharedPreferences.getInstance();
  for (var i = 0; i < 200; i++) {
    if (prefs.getString('cartItems') != null) break;
    await Future.delayed(const Duration(milliseconds: 5));
  }
  await provider.loadCartAndRecalculate('buyer');
}

Future<void> seedOffer(
  FakeFirebaseFirestore fake, {
  required Map<String, dynamic> unit,
  Object? Function()? rootOfferPrice,
}) {
  final data = <String, dynamic>{
    'units': [unit],
    'status': 'active',
    'minOrder': 1,
  };
  final root = rootOfferPrice?.call();
  if (root != null) data['offerPrice'] = root;
  return fake.collection('productOffers').doc('offer-1').set(data);
}

Future<void> addAtOfferPrice(CartProvider provider, double price) {
  return provider.addItemToCart(
    offerId: 'offer-1',
    productId: 'prod-1',
    sellerId: 's1',
    sellerName: 'Seller s1',
    name: 'Item 1',
    price: price,
    unit: 'piece',
    unitIndex: 0,
    quantityToAdd: 2,
    imageUrl: '',
    userRole: 'buyer',
  );
}

void main() {
  group('offer price survives cart recalculation', () {
    late FakeFirebaseFirestore fake;
    late CartProvider provider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      fake = FakeFirebaseFirestore();
      provider = CartProvider(
          db: fake, dataService: _StubMarketplaceDataService());
    });

    test('root offerPrice wins and originalPrice is stamped', () async {
      await seedOffer(fake,
          unit: {'unitName': 'piece', 'price': 100.0, 'availableStock': 50},
          rootOfferPrice: () => 80.0);
      await addAtOfferPrice(provider, 80.0);
      await settle(provider);

      final item = provider.sellersOrders['s1']!.items.single;
      expect(item.price, 80.0);
      expect(item.originalPrice, 100.0);
      expect(provider.sellersOrders['s1']!.total, 160.0);
      // يصل الطلب/الفاتورة عبر toJson.
      expect(item.toJson()['originalPrice'], 100.0);
    });

    test('unit-level offerPrice wins over root and base', () async {
      await seedOffer(fake,
          unit: {
            'unitName': 'piece',
            'price': 100.0,
            'offerPrice': 70.0,
            'availableStock': 50
          },
          rootOfferPrice: () => 90.0);
      await addAtOfferPrice(provider, 70.0);
      await settle(provider);

      final item = provider.sellersOrders['s1']!.items.single;
      expect(item.price, 70.0);
      expect(item.originalPrice, 100.0);
    });

    test('no offerPrice keeps base price without stamp', () async {
      await seedOffer(fake,
          unit: {'unitName': 'piece', 'price': 100.0, 'availableStock': 50});
      await addAtOfferPrice(provider, 100.0);
      await settle(provider);

      final item = provider.sellersOrders['s1']!.items.single;
      expect(item.price, 100.0);
      expect(item.originalPrice, isNull);
    });

    test('recalculate does not resurrect a removed discount', () async {
      await seedOffer(fake,
          unit: {'unitName': 'piece', 'price': 100.0, 'availableStock': 50},
          rootOfferPrice: () => 80.0);
      await addAtOfferPrice(provider, 80.0);
      await settle(provider);
      expect(provider.sellersOrders['s1']!.items.single.price, 80.0);

      // التاجر يسحب الخصم: يعاد الحساب بالأساسي ويمسح الختم.
      await seedOffer(fake,
          unit: {'unitName': 'piece', 'price': 100.0, 'availableStock': 50});
      await provider.loadCartAndRecalculate('buyer');

      final item = provider.sellersOrders['s1']!.items.single;
      expect(item.price, 100.0);
      expect(item.originalPrice, isNull);
    });
  });
}
