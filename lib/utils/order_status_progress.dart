// lib/utils/order_status_progress.dart
//
// Buyer order tracker: the five approved order statuses and the buyer's
// path from a new order to delivery. Pure helpers so the tracker widget
// and tests share one contract (mirrors OrderModel statuses/labels).

/// Forward path shown on the tracker, from a new order to delivery.
const List<({String status, String label})> orderProgressSteps = [
  (status: 'new-order', label: 'طلب جديد'),
  (status: 'processing', label: 'قيد التجهيز'),
  (status: 'shipped', label: 'تم الشحن'),
  (status: 'delivered', label: 'تم التسليم'),
];

/// Terminal state outside the forward path.
const String cancelledOrderStatus = 'cancelled';

bool isOrderCancelled(String status) => status == cancelledOrderStatus;

/// Index on the forward path (0..steps-1). Unknown/off-path statuses fall
/// back to the first step, mirroring OrderModel validation.
int orderProgressIndex(String status) {
  final int i = orderProgressSteps.indexWhere((s) => s.status == status);
  return i < 0 ? 0 : i;
}

/// Fraction of the path completed (new-order = 1/4 … delivered = 1).
double orderProgressFraction(String status) =>
    (orderProgressIndex(status) + 1) / orderProgressSteps.length;

/// Arabic label for any of the five approved statuses.
String orderStatusLabel(String status) {
  switch (status) {
    case 'new-order':
      return 'طلب جديد';
    case 'processing':
      return 'قيد التجهيز';
    case 'shipped':
      return 'تم الشحن';
    case 'delivered':
      return 'تم التسليم';
    case 'cancelled':
      return 'ملغي';
    default:
      return 'طلب جديد';
  }
}
