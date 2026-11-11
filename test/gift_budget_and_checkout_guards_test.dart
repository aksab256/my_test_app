import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_test_app/models/banner_model.dart';
import 'package:my_test_app/models/category_model.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:my_test_app/services/marketplace_data_service.dart';

// Gift budget, liveness and AND guards at the cart-preview level.
//
// القاعدة: معاينة السلة تحترم المتبقي (max-used) والصلاحية (status/expiry)
// لحظة كل حساب. العروض القديمة بلا maxQuantity تبقى غير محدودة (legacy compat).
//
// ملاحظة: التحقق عند إتمام الطلب (CheckoutController._dropStaleGiftItems)
// مغطى منطقياً بنفس القواعد، لكن اختبارات placeOrder الـwidget تعلّق في
// هذه البيئة (10 دقائق) بنفس الطريقة لاختبارات checkout المثبتة أصلاً
// (مثل checkout_secure_routing_test) — مشكلة بيئة سابقة على هذا التغيير،
// لذا لا تُشحن هنا اختبارات widget معلقة كـ«إثبات».

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

CartProvider makeCart(FakeFirebaseFirestore fake) {
  return CartProvider(db: fake, dataService: _StubMarketplaceDataService());
}

Future<void> addTrigger(
  CartProvider provider, {
  String offerId = 'offer-1',
  int quantity = 1,
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

Future<void> seedPromo(
  FakeFirebaseFirestore fake, {
  Map<String, dynamic>? trigger,
  List<Map<String, dynamic>>? triggers,
  String status = 'active',
  Object? expiry = '2099-12-31T00:00:00.000',
  int? maxQuantity = 5,
  int usedQuantity = 0,
  int perBase = 1,
}) {
  return fake.collection('giftPromos').add({
    'sellerId': 's1',
    'status': status,
    if (expiry != null) 'expiryDate': expiry,
    if (maxQuantity != null) 'maxQuantity': maxQuantity,
    'usedQuantity': usedQuantity,
    'giftQuantityPerBase': perBase,
    if (trigger != null) 'trigger': trigger,
    if (triggers != null) 'triggers': triggers,
    'giftOfferId': 'gift-1',
    'giftProductId': 'gift-prod-1',
    'giftProductName': 'Free sample',
    'giftUnitName': 'piece',
    'giftProductImage': '',
  });
}

Map<String, dynamic> specificTrigger(String offerId, int base) => {
      'type': 'specific_item',
      'offerId': offerId,
      'triggerQuantityBase': base,
      'unitName': 'piece',
    };

void main() {
  group('cart gift budget + liveness guards', () {
    late FakeFirebaseFirestore fake;
    late CartProvider provider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      fake = FakeFirebaseFirestore();
      provider = makeCart(fake);
    });

    test('remaining budget caps the grant (max-used respected)', () async {
      await seedPromo(fake,
          trigger: specificTrigger('offer-1', 2),
          maxQuantity: 5,
          usedQuantity: 3,
          perBase: 1);
      await addTrigger(provider, quantity: 5);
      await settle(provider);

      // floor(5/2) = 2 خام، لكن المتبقي 2 فقط.
      expect(provider.sellersOrders['s1']!.giftedItems.single.quantity, 2);

      await addTrigger(provider, quantity: 4);
      await settle(provider);

      // floor(9/2) = 4 خام، يُقص للمتبقي 2 — لا يتجاوز الميزانية أبداً.
      expect(provider.sellersOrders['s1']!.giftedItems.single.quantity, 2);
    });

    test('exhausted budget yields no gift', () async {
      await seedPromo(fake,
          trigger: specificTrigger('offer-1', 1),
          maxQuantity: 5,
          usedQuantity: 5);
      await addTrigger(provider, quantity: 3);
      await settle(provider);

      expect(provider.sellersOrders['s1']!.giftedItems, isEmpty);
    });

    test('expired promo yields no gift', () async {
      await seedPromo(fake,
          trigger: specificTrigger('offer-1', 1),
          expiry: '2020-01-01T00:00:00.000');
      await addTrigger(provider, quantity: 3);
      await settle(provider);

      expect(provider.sellersOrders['s1']!.giftedItems, isEmpty);
    });

    test('disabled promo yields no gift', () async {
      await seedPromo(fake,
          trigger: specificTrigger('offer-1', 1), status: 'disabled');
      await addTrigger(provider, quantity: 3);
      await settle(provider);

      expect(provider.sellersOrders['s1']!.giftedItems, isEmpty);
    });

    test('legacy promo without maxQuantity keeps granting', () async {
      await seedPromo(fake,
          trigger: specificTrigger('offer-1', 2), maxQuantity: null);
      await addTrigger(provider, quantity: 5);
      await settle(provider);

      expect(provider.sellersOrders['s1']!.giftedItems.single.quantity, 2);
    });

    test('min_order grant respects remaining budget', () async {
      await seedPromo(fake,
          trigger: {'type': 'min_order', 'value': 50.0},
          maxQuantity: 2,
          usedQuantity: 1,
          perBase: 3);
      await addTrigger(provider, quantity: 4); // total 100 >= 50
      await settle(provider);

      // 3 خام تُقص للمتبقي 1.
      expect(provider.sellersOrders['s1']!.giftedItems.single.quantity, 1);
    });

    test('AND requires every trigger line', () async {
      await seedPromo(fake, triggers: [
        specificTrigger('offer-A', 1),
        specificTrigger('offer-B', 1),
      ]);
      await addTrigger(provider, offerId: 'offer-A', quantity: 1);
      await settle(provider);
      expect(provider.sellersOrders['s1']!.giftedItems, isEmpty);

      await addTrigger(provider, offerId: 'offer-B', quantity: 1);
      await settle(provider);
      expect(provider.sellersOrders['s1']!.giftedItems.single.quantity, 1);
    });
  });
}
