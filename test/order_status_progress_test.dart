import 'package:flutter_test/flutter_test.dart';
import 'package:my_test_app/utils/order_status_progress.dart';

// Locks the buyer order tracker contract: five approved statuses, forward
// path order from new-order to delivery, and progress reflecting the
// order's current stage.
void main() {
  group('orderProgressSteps', () {
    test('holds the four forward stages in path order', () {
      expect(
        orderProgressSteps.map((s) => s.status).toList(),
        ['new-order', 'processing', 'shipped', 'delivered'],
      );
    });
  });

  group('orderProgressIndex', () {
    test('maps each forward status to its stage', () {
      expect(orderProgressIndex('new-order'), 0);
      expect(orderProgressIndex('processing'), 1);
      expect(orderProgressIndex('shipped'), 2);
      expect(orderProgressIndex('delivered'), 3);
    });

    test('falls back to the first stage for unknown statuses', () {
      expect(orderProgressIndex('cancelled'), 0);
      expect(orderProgressIndex('whatever'), 0);
    });
  });

  group('orderProgressFraction', () {
    test('grows along the path and completes at delivery', () {
      expect(orderProgressFraction('new-order'), 0.25);
      expect(orderProgressFraction('processing'), 0.5);
      expect(orderProgressFraction('shipped'), 0.75);
      expect(orderProgressFraction('delivered'), 1.0);
    });
  });

  group('isOrderCancelled', () {
    test('true only for the cancelled terminal status', () {
      expect(isOrderCancelled('cancelled'), isTrue);
      expect(isOrderCancelled('delivered'), isFalse);
      expect(isOrderCancelled('new-order'), isFalse);
    });
  });

  group('orderStatusLabel', () {
    test('covers all five approved statuses in Arabic', () {
      expect(orderStatusLabel('new-order'), 'طلب جديد');
      expect(orderStatusLabel('processing'), 'قيد التجهيز');
      expect(orderStatusLabel('shipped'), 'تم الشحن');
      expect(orderStatusLabel('delivered'), 'تم التسليم');
      expect(orderStatusLabel('cancelled'), 'ملغي');
    });
  });
}
