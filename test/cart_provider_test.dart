import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_test_app/models/banner_model.dart';
import 'package:my_test_app/models/category_model.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:my_test_app/services/marketplace_data_service.dart';

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
  int minOrderQuantity = 1,
  int availableStock = 9999,
  int maxOrderQuantity = 9999,
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
    minOrderQuantity: minOrderQuantity,
    availableStock: availableStock,
    maxOrderQuantity: maxOrderQuantity,
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

CartItem lineOf(String offerId) => CartItem(
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

void main() {
  late FakeFirebaseFirestore fake;
  late CartProvider provider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fake = FakeFirebaseFirestore();
    provider = makeProvider(fake);
  });

  group('add item', () {
    test('adds a line and updates counts', () async {
      await addItem(provider);
      await settle(provider);

      expect(provider.isCartEmpty, isFalse);
      expect(provider.cartTotalItems, 1);
      expect(provider.cartTotalQuantity, 2);
    });

    test('adding the same offer and unit accumulates quantity', () async {
      await addItem(provider, quantity: 2);
      await addItem(provider, quantity: 3);
      await settle(provider);

      expect(provider.cartTotalItems, 1);
      expect(provider.cartTotalQuantity, 5);
    });

    test('same offer with a different unit is a separate line', () async {
      await addItem(provider, unitIndex: 0);
      await addItem(provider, unitIndex: 1);
      await settle(provider);

      expect(provider.cartTotalItems, 2);
      expect(provider.cartTotalQuantity, 4);
    });
  });

  group('add validation', () {
    test('quantity below the minimum is rejected and cart stays empty',
        () async {
      await expectLater(
        addItem(provider, quantity: 0, minOrderQuantity: 2),
        throwsA(isA<Exception>()),
      );

      expect(provider.isCartEmpty, isTrue);
    });

    test('quantity above available stock is rejected', () async {
      await expectLater(
        addItem(provider, quantity: 5, availableStock: 2),
        throwsA(isA<Exception>()),
      );

      expect(provider.isCartEmpty, isTrue);
    });
  });

  group('remove and change quantity', () {
    test('removeItem empties the cart and resets totals', () async {
      await addItem(provider);
      await settle(provider);
      await provider.removeItem(lineOf('offer-1'), 'buyer');
      await settle(provider);

      expect(provider.isCartEmpty, isTrue);
      expect(provider.cartTotalItems, 0);
      expect(provider.totalProductsAmount, 0.0);
      expect(provider.finalTotal, 0.0);
    });

    test('changeQty adjusts the line quantity', () async {
      await addItem(provider, quantity: 2);
      await provider.changeQty(lineOf('offer-1'), 3, 'buyer');
      await settle(provider);

      expect(provider.cartTotalQuantity, 5);
    });

    test('changeQty down to zero removes the line', () async {
      await addItem(provider, quantity: 2);
      await provider.changeQty(lineOf('offer-1'), -2, 'buyer');
      await settle(provider);

      expect(provider.isCartEmpty, isTrue);
    });
  });

  group('totals and cart state', () {
    test('final total adds the seller delivery fee', () async {
      await fake.collection('sellers').doc('s1').set({
        'minOrderTotal': 0.0,
        'deliveryFee': 15.0,
      });
      await addItem(provider, price: 25.0, quantity: 2);
      await settle(provider);

      expect(provider.totalProductsAmount, 50.0);
      expect(provider.totalDeliveryFees, 15.0);
      expect(provider.finalTotal, 65.0);
      expect(provider.sellersOrders['s1']!.isMinOrderMet, isTrue);
    });

    test('unmet minimum order excludes the delivery fee', () async {
      await fake.collection('sellers').doc('s1').set({
        'minOrderTotal': 1000.0,
        'deliveryFee': 15.0,
      });
      await addItem(provider, price: 25.0, quantity: 2);
      await settle(provider);

      final seller = provider.sellersOrders['s1']!;
      expect(seller.isMinOrderMet, isFalse);
      expect(provider.totalProductsAmount, 50.0);
      expect(provider.totalDeliveryFees, 0.0);
      expect(provider.finalTotal, 50.0);
    });

    test('items group per seller', () async {
      await addItem(provider, offerId: 'offer-1', sellerId: 's1');
      await addItem(provider, offerId: 'offer-2', sellerId: 's2');
      await settle(provider);

      expect(provider.sellersOrders.keys, containsAll(['s1', 's2']));
      expect(provider.cartTotalItems, 2);
    });

    test('min-order gift promo appends a zero-price gift line', () async {
      await fake.collection('giftPromos').add({
        'sellerId': 's1',
        'status': 'active',
        'trigger': {'type': 'min_order', 'value': 50.0},
        'giftQuantityPerBase': 1,
        'giftOfferId': 'gift-1',
        'giftProductId': 'gift-prod-1',
        'giftProductName': 'Free sample',
        'giftUnitName': 'piece',
        'giftProductImage': '',
      });
      await addItem(provider, price: 25.0, quantity: 2);
      await settle(provider);

      final gifts = provider.sellersOrders['s1']!.giftedItems;
      expect(gifts, hasLength(1));
      expect(gifts.single.isGift, isTrue);
      expect(gifts.single.price, 0.0);
      // Gift lines never inflate the payable counts.
      expect(provider.cartTotalItems, 1);
      expect(provider.cartTotalQuantity, 2);
      expect(provider.totalProductsAmount, 50.0);
    });

    test('clearCart empties everything and resets totals', () async {
      await addItem(provider);
      await settle(provider);
      await provider.clearCart();

      expect(provider.isCartEmpty, isTrue);
      expect(provider.sellersOrders, isEmpty);
      expect(provider.totalProductsAmount, 0.0);
      expect(provider.totalDeliveryFees, 0.0);
      expect(provider.finalTotal, 0.0);
    });
  });
}
