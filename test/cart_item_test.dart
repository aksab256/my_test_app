import 'package:flutter_test/flutter_test.dart';
import 'package:my_test_app/providers/cart_provider.dart';

CartItem testItem({
  String offerId = 'offer-1',
  String productId = 'prod-1',
  double price = 25.5,
  int quantity = 2,
  bool isGift = false,
}) {
  return CartItem(
    offerId: offerId,
    productId: productId,
    sellerId: 'seller-1',
    sellerName: 'Test Seller',
    name: 'Test Product',
    price: price,
    unit: 'piece',
    unitIndex: 0,
    quantity: quantity,
    isGift: isGift,
    imageUrl: 'https://example.com/img.png',
  );
}

void main() {
  group('CartItem toJson', () {
    test('serializes every field', () {
      final json = testItem().toJson();

      expect(json['offerId'], 'offer-1');
      expect(json['productId'], 'prod-1');
      expect(json['sellerId'], 'seller-1');
      expect(json['sellerName'], 'Test Seller');
      expect(json['name'], 'Test Product');
      expect(json['price'], 25.5);
      expect(json['unit'], 'piece');
      expect(json['unitIndex'], 0);
      expect(json['quantity'], 2);
      expect(json['isGift'], false);
      expect(json['imageUrl'], 'https://example.com/img.png');
    });
  });

  group('CartItem fromJson', () {
    test('round trip preserves all fields', () {
      final original = testItem(price: 10.0, quantity: 3, isGift: true);
      final restored = CartItem.fromJson(original.toJson());

      expect(restored.offerId, original.offerId);
      expect(restored.productId, original.productId);
      expect(restored.sellerId, original.sellerId);
      expect(restored.sellerName, original.sellerName);
      expect(restored.name, original.name);
      expect(restored.price, original.price);
      expect(restored.unit, original.unit);
      expect(restored.unitIndex, original.unitIndex);
      expect(restored.quantity, original.quantity);
      expect(restored.isGift, original.isGift);
      expect(restored.imageUrl, original.imageUrl);
    });

    test('empty map yields safe defaults, never throws', () {
      final item = CartItem.fromJson({});

      expect(item.offerId, '');
      expect(item.productId, '');
      expect(item.sellerId, '');
      expect(item.price, 0.0);
      expect(item.quantity, 1);
      expect(item.isGift, false);
      expect(item.unitIndex, -1);
      expect(item.mainId, isNull);
      expect(item.subId, isNull);
    });

    test('integer price is coerced to double', () {
      final item = CartItem.fromJson({'price': 25, 'quantity': 1});

      expect(item.price, 25.0);
      expect(item.price, isA<double>());
    });

    test('productId falls back to offerId when missing', () {
      final item = CartItem.fromJson({'offerId': 'offer-9'});

      expect(item.productId, 'offer-9');
    });

    test('explicit productId wins over the offerId fallback', () {
      final item =
          CartItem.fromJson({'offerId': 'offer-9', 'productId': 'prod-9'});

      expect(item.productId, 'prod-9');
    });

    test('line total math uses coerced values', () {
      final item = CartItem.fromJson({'price': 10, 'quantity': 3});

      expect(item.price * item.quantity, 30.0);
    });
  });
}
