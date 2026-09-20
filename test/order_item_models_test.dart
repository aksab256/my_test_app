import 'package:flutter_test/flutter_test.dart';
import 'package:my_test_app/models/consumer_order_model.dart';
import 'package:my_test_app/models/order_item_model.dart';

void main() {
  group('OrderItem.fromMap (consumer order lines)', () {
    test('reads canonical field names', () {
      final item = OrderItem.fromMap({
        'name': 'Sugar 1kg',
        'quantity': 4,
        'imageUrl': 'https://example.com/sugar.png',
        'price': 30.0,
        'productId': 'prod-sugar',
      });

      expect(item.name, 'Sugar 1kg');
      expect(item.quantity, 4);
      expect(item.imageUrl, 'https://example.com/sugar.png');
      expect(item.price, 30.0);
      expect(item.productId, 'prod-sugar');
    });

    test('falls back to legacy productName/productImage aliases', () {
      final item = OrderItem.fromMap({
        'productName': 'Rice 5kg',
        'quantity': 1,
        'productImage': 'https://example.com/rice.png',
        'price': 120,
      });

      expect(item.name, 'Rice 5kg');
      expect(item.imageUrl, 'https://example.com/rice.png');
      expect(item.price, 120.0);
    });

    test('tolerates a sparse map without throwing', () {
      final item = OrderItem.fromMap({});

      expect(item.name, isNull);
      expect(item.quantity, isNull);
      expect(item.price, isNull);
      expect(item.productId, isNull);
    });
  });

  group('OrderItemModel.fromMap (seller order lines)', () {
    test('maps Firestore price field onto unitPrice', () {
      final item = OrderItemModel.fromMap({
        'name': 'Oil 1.5L',
        'quantity': 2,
        'unit': 'bottle',
        'price': 95.5,
        'imageUrl': 'https://example.com/oil.png',
      });

      expect(item.name, 'Oil 1.5L');
      expect(item.quantity, 2);
      expect(item.unit, 'bottle');
      expect(item.unitPrice, 95.5);
      expect(item.imageUrl, 'https://example.com/oil.png');
    });

    test('integer quantity and price are coerced', () {
      final item = OrderItemModel.fromMap({
        'name': 'Flour',
        'quantity': 3.0,
        'unit': 'bag',
        'price': 40,
      });

      expect(item.quantity, 3);
      expect(item.quantity, isA<int>());
      expect(item.unitPrice, 40.0);
    });

    test('missing fields yield safe display defaults', () {
      final item = OrderItemModel.fromMap({});

      expect(item.name, 'صنف غير محدد');
      expect(item.quantity, 0);
      expect(item.unit, '');
      expect(item.unitPrice, 0.0);
      expect(item.imageUrl, '');
    });
  });
}
