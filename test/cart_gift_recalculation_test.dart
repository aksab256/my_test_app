import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_test_app/models/banner_model.dart';
import 'package:my_test_app/models/category_model.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:my_test_app/services/marketplace_data_service.dart';

// A6: Gift recalculation in Cart.
//
// القاعدة: الهدايا تُعاد حسابها من الصفر في كل loadCartAndRecalculate من
// الأصناف غير الهدايا + promos البائع، فإعادة الحساب idempotent ولا تعتمد
// على ترتيب الاستدعاءات. سطور الهدايا لا تُغيَّر ولا تُحذف مباشرةً (no-op)
// وتسقط فقط بسقوط الأهلية.
// يستخدم CartProvider(db: fake) seam الموجود فقط، دون أي production change.

// _dataService is never consulted by the cart flows under test; the stub only
// satisfies construction (the real service needs a Firebase app).
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

CartProvider makeProvider(FakeFirebaseFirestore fake) {
  return CartProvider(
    db: fake,
    dataService: StubMarketplaceDataService(),
  );
}

Future<void> addItem(
  CartProvider provider, {
  String offerId = 'offer-1',
  String sellerId = 's1',
  double price = 25.0,
  int quantity = 2,
  int unitIndex = 0,
}) {
  return provider.addItemToCart(
    offerId: offerId,
    productId: 'prod-$offerId',
    sellerId: sellerId,
    sellerName: 'Seller $sellerId',
    name: 'Item $offerId',
    price: price,
    unit: 'piece',
    unitIndex: unitIndex,
    quantityToAdd: quantity,
    imageUrl: '',
    userRole: 'buyer',
  );
}

// addItemToCart persists and recalculates in unawaited background work, so
// wait until the save lands, then run one explicit recalculation for a
// deterministic cart state.
Future<void> settle(CartProvider provider) async {
  final prefs = await SharedPreferences.getInstance();
  for (var i = 0; i < 200; i++) {
    if (prefs.getString('cartItems') != null) break;
    await Future.delayed(const Duration(milliseconds: 5));
  }
  await provider.loadCartAndRecalculate('buyer');
}

Future<void> seedMinOrderPromo(
  FakeFirebaseFirestore fake, {
  String sellerId = 's1',
  double value = 50.0,
  String giftOfferId = 'gift-1',
  String status = 'active',
}) {
  return fake.collection('giftPromos').add({
    'sellerId': sellerId,
    'status': status,
    'trigger': {'type': 'min_order', 'value': value},
    'giftQuantityPerBase': 1,
    'giftOfferId': giftOfferId,
    'giftProductId': 'gift-prod-1',
    'giftProductName': 'Free sample',
    'giftUnitName': 'piece',
    'giftProductImage': '',
  });
}

Future<void> seedSpecificItemPromo(
  FakeFirebaseFirestore fake, {
  String sellerId = 's1',
  String triggerOfferId = 'offer-1',
  int triggerBase = 2,
  int perBase = 1,
  int maxQuantity = 3,
  String giftOfferId = 'gift-1',
}) {
  return fake.collection('giftPromos').add({
    'sellerId': sellerId,
    'status': 'active',
    'trigger': {
      'type': 'specific_item',
      'offerId': triggerOfferId,
      'triggerQuantityBase': triggerBase,
      'unitName': 'piece',
    },
    'giftQuantityPerBase': perBase,
    'maxQuantity': maxQuantity,
    'giftOfferId': giftOfferId,
    'giftProductId': 'gift-prod-1',
    'giftProductName': 'Free sample',
    'giftUnitName': 'piece',
    'giftProductImage': '',
  });
}

CartItem normalLine(String offerId) => CartItem(
      offerId: offerId,
      productId: 'prod-$offerId',
      sellerId: 's1',
      sellerName: 'Seller s1',
      name: 'Item $offerId',
      price: 25.0,
      unit: 'piece',
      unitIndex: 0,
      quantity: 1,
      imageUrl: '',
    );

CartItem giftLine() => CartItem(
      offerId: 'gift-1',
      productId: 'gift-prod-1',
      sellerId: 's1',
      sellerName: 'Seller s1',
      name: 'Free sample',
      price: 0.0,
      unit: 'piece',
      unitIndex: -1,
      quantity: 1,
      imageUrl: '',
      isGift: true,
    );

void main() {
  late FakeFirebaseFirestore fake;
  late CartProvider provider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fake = FakeFirebaseFirestore();
    provider = makeProvider(fake);
  });

  group('A6: gift recalculation', () {
    test('repeated recalculation yields one identical gift line', () async {
      await seedMinOrderPromo(fake);
      await addItem(provider, price: 25.0, quantity: 2);
      await settle(provider);
      await provider.loadCartAndRecalculate('buyer');

      final gifts = provider.sellersOrders['s1']!.giftedItems;
      expect(gifts, hasLength(1));
      expect(gifts.single.quantity, 1);
      expect(gifts.single.isGift, isTrue);
      expect(gifts.single.price, 0.0);
      // Payable state untouched by the second pass.
      expect(provider.cartTotalItems, 1);
      expect(provider.totalProductsAmount, 50.0);
    });

    test('dropping below the min-order value removes the gift', () async {
      await seedMinOrderPromo(fake, value: 50.0);
      await addItem(provider, price: 25.0, quantity: 2);
      await settle(provider);
      expect(provider.sellersOrders['s1']!.giftedItems, hasLength(1));

      await provider.changeQty(normalLine('offer-1'), -1, 'buyer');
      await settle(provider);

      // Total 25 < 50: gift gone, payable line kept.
      expect(provider.sellersOrders['s1']!.giftedItems, isEmpty);
      expect(provider.cartTotalQuantity, 1);
      expect(provider.totalProductsAmount, 25.0);
    });

    test('raising quantity through changeQty earns the gift', () async {
      await seedMinOrderPromo(fake, value: 50.0);
      await addItem(provider, price: 25.0, quantity: 1);
      await settle(provider);
      expect(provider.sellersOrders['s1']!.giftedItems, isEmpty);

      await provider.changeQty(normalLine('offer-1'), 1, 'buyer');
      await settle(provider);

      final gifts = provider.sellersOrders['s1']!.giftedItems;
      expect(gifts, hasLength(1));
      expect(gifts.single.quantity, 1);
    });

    test('specific-item trigger scales per base and respects maxQuantity',
        () async {
      await seedSpecificItemPromo(fake,
          triggerBase: 2, perBase: 1, maxQuantity: 3);
      await addItem(provider, quantity: 5);
      await settle(provider);

      // floor(5 / 2) * 1 = 2.
      expect(provider.sellersOrders['s1']!.giftedItems.single.quantity, 2);

      await provider.changeQty(normalLine('offer-1'), 2, 'buyer');
      await settle(provider);

      // floor(7 / 2) * 1 = 3, capped at maxQuantity 3.
      expect(provider.sellersOrders['s1']!.giftedItems.single.quantity, 3);
    });

    test('gift belongs to the promo seller only', () async {
      await seedMinOrderPromo(fake, sellerId: 's1', value: 10.0);
      await addItem(provider, offerId: 'offer-1', sellerId: 's1');
      await addItem(provider, offerId: 'offer-2', sellerId: 's2');
      await settle(provider);

      final giftsS1 = provider.sellersOrders['s1']!.giftedItems;
      expect(giftsS1, hasLength(1));
      expect(giftsS1.single.sellerId, 's1');
      expect(provider.sellersOrders['s2']!.giftedItems, isEmpty);
    });

    test(
        'CHARACTERIZATION (needs business decision): two promos on one '
        'seller produce two separate gift lines', () async {
      await seedMinOrderPromo(fake, giftOfferId: 'gift-1');
      await seedMinOrderPromo(fake, giftOfferId: 'gift-2');
      await addItem(provider, price: 25.0, quantity: 2);
      await settle(provider);

      // Current behavior: one line per promo, never merged.
      final gifts = provider.sellersOrders['s1']!.giftedItems;
      expect(gifts.map((g) => g.offerId), containsAll(['gift-1', 'gift-2']));
      expect(provider.cartTotalItems, 1);
    });

    test('gift lines ignore direct changeQty/removeItem (eligibility owns them)',
        () async {
      await seedMinOrderPromo(fake, value: 50.0);
      await addItem(provider, price: 25.0, quantity: 2);
      await settle(provider);
      expect(provider.sellersOrders['s1']!.giftedItems, hasLength(1));

      // Direct ops on the gift line are no-ops.
      await provider.changeQty(giftLine(), 5, 'buyer');
      await provider.removeItem(giftLine(), 'buyer');
      await settle(provider);

      final gifts = provider.sellersOrders['s1']!.giftedItems;
      expect(gifts, hasLength(1));
      expect(gifts.single.quantity, 1);
      expect(provider.cartTotalQuantity, 2);
    });

    test('inactive promo yields no gift', () async {
      await seedMinOrderPromo(fake, status: 'paused');
      await addItem(provider, price: 25.0, quantity: 2);
      await settle(provider);

      expect(provider.sellersOrders['s1']!.giftedItems, isEmpty);
      expect(provider.cartTotalItems, 1);
    });

    test('gift sharing the trigger offerId does not self-trigger growth',
        () async {
      await seedSpecificItemPromo(fake,
          triggerOfferId: 'offer-1',
          triggerBase: 1,
          perBase: 1,
          maxQuantity: 9999,
          giftOfferId: 'offer-1');
      await addItem(provider, quantity: 2);
      await settle(provider);
      await provider.loadCartAndRecalculate('buyer');

      // Still exactly one gift line with qty 2 after two full passes:
      // persisted gift entries never re-enter the trigger base.
      final gifts = provider.sellersOrders['s1']!.giftedItems;
      expect(gifts, hasLength(1));
      expect(gifts.single.quantity, 2);
    });

    test('gift sharing productId with a normal product stays a separate line',
        () async {
      await fake.collection('giftPromos').add({
        'sellerId': 's1',
        'status': 'active',
        'trigger': {'type': 'min_order', 'value': 10.0},
        'giftQuantityPerBase': 1,
        'giftOfferId': 'gift-1',
        // Same productId as the purchasable line below.
        'giftProductId': 'prod-offer-1',
        'giftProductName': 'Free sample',
        'giftUnitName': 'piece',
        'giftProductImage': '',
      });
      await addItem(provider, offerId: 'offer-1', quantity: 1);
      await settle(provider);

      final gifts = provider.sellersOrders['s1']!.giftedItems;
      expect(gifts, hasLength(1));
      expect(gifts.single.productId, 'prod-offer-1');
      expect(gifts.single.isGift, isTrue);
      // Payable identity untouched: one paid line, gift excluded everywhere.
      expect(provider.cartTotalItems, 1);
      expect(provider.cartTotalQuantity, 1);
      expect(provider.totalProductsAmount, 25.0);
    });
  });
}
