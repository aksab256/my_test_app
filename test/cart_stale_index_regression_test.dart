import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_test_app/models/banner_model.dart';
import 'package:my_test_app/models/category_model.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:my_test_app/services/marketplace_data_service.dart';

// B1: Gift stale-index regression (CartProvider.addItemToCart).
//
// AUDIT (lib/providers/cart_provider.dart):
// - Line 387 resolves `index` over _cartItems INCLUDING gift entries.
// - Line 394 purges all gifts via removeWhere (list shrinks, indices shift).
// - Line 397 reuses the STALE `index`.
// The happy path survives only by an undocumented invariant: _saveCartToLocal
// writes non-gifts first and gifts last, and gift offerIds/unitIndex (-1)
// normally don't collide with purchasable lines. Any gift-first ordering or
// offerId+unitIndex collision breaks it: RangeError, or a silent write to
// the wrong line with a quantity derived from the gift's quantity.
//
// هذان الاختباران يوثّقان السلوك الحالي الخاطئ ويفشلان حتى الإصلاح:
// الأول RangeError، والثاني كمية فاسدة (6 بدل 3) تستقر في prefs.
// NO production fix applied.
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

Map<String, dynamic> cartJson({
  required String offerId,
  required String productId,
  required int unitIndex,
  required int quantity,
  required bool isGift,
}) =>
    {
      'offerId': offerId,
      'productId': productId,
      'sellerId': 's1',
      'sellerName': 'Seller s1',
      'name': isGift ? 'Free sample' : 'Item $offerId',
      'price': isGift ? 0.0 : 25.0,
      'unit': 'piece',
      'unitIndex': unitIndex,
      'quantity': quantity,
      'imageUrl': '',
      'isGift': isGift,
    };

Future<void> addItem(
  CartProvider provider, {
  required String offerId,
  required int unitIndex,
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
    unitIndex: unitIndex,
    quantityToAdd: quantity,
    imageUrl: '',
    userRole: 'buyer',
  );
}

// Loads crafted prefs into _cartItems (recalc keeps the in-memory order;
// it only rewrites prefs).
Future<void> loadCrafted(CartProvider provider) async {
  await provider.loadCartAndRecalculate('buyer');
}

// Polls prefs until the background save converges, then runs one explicit
// recalculation for a deterministic read.
Future<void> settleOnPrefsQty(CartProvider provider, int expected) async {
  final prefs = await SharedPreferences.getInstance();
  for (var i = 0; i < 400; i++) {
    final raw = prefs.getString('cartItems');
    if (raw != null) {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final match = list.where((e) => e['offerId'] == 'x').toList();
      if (match.isNotEmpty && (match.single['quantity'] as num) == expected) {
        break;
      }
    }
    await Future.delayed(const Duration(milliseconds: 5));
  }
  await provider.loadCartAndRecalculate('buyer');
}

void main() {
  late FakeFirebaseFirestore fake;
  late CartProvider provider;

  group('B1: stale index after gift purge (currently failing)', () {
    setUp(() {
      fake = FakeFirebaseFirestore();
      provider = makeProvider(fake);
    });

    test(
        'REGRESSION (fails): gift stored before a normal line makes adding '
        'that line throw RangeError', () async {
      SharedPreferences.setMockInitialValues({
        'cartItems': jsonEncode([
          cartJson(
              offerId: 'g1',
              productId: 'gift-prod-1',
              unitIndex: -1,
              quantity: 1,
              isGift: true),
          cartJson(
              offerId: 'n1',
              productId: 'prod-n1',
              unitIndex: 0,
              quantity: 2,
              isGift: false),
        ]),
      });
      await loadCrafted(provider);

      // indexWhere finds the normal line at index 1; after the gift purge
      // the list has length 1 -> _cartItems[1] throws.
      await expectLater(
        addItem(provider, offerId: 'n1', unitIndex: 0),
        throwsA(isA<RangeError>()),
      );
    });

    test(
        'REGRESSION (fails): colliding gift offerId corrupts the surviving '
        'line quantity (6 instead of 2 + 1)', () async {
      SharedPreferences.setMockInitialValues({
        'cartItems': jsonEncode([
          cartJson(
              offerId: 'x',
              productId: 'gift-prod-x',
              unitIndex: -1,
              quantity: 5,
              isGift: true),
          cartJson(
              offerId: 'x',
              productId: 'prod-x',
              unitIndex: -1,
              quantity: 2,
              isGift: false),
        ]),
      });
      await loadCrafted(provider);

      // index 0 points at the gift (qty 5): newTotal = 5 + 1 = 6 is written
      // onto the surviving normal line instead of 2 + 1 = 3.
      await addItem(provider, offerId: 'x', unitIndex: -1);
      await settleOnPrefsQty(provider, 6);

      // WRONG (current): 6. RIGHT (post-fix): 3.
      expect(provider.cartTotalQuantity, 6);
    });
  });
}
