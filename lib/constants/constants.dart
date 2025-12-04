// lib/constants/constants.dart

// ثوابت المجموعات
const String CONSUMER_ORDERS_COLLECTION = 'consumerorders';

// ثوابت حالات الطلب (مطابقة لـ ORDER_STATUSES في JS)
class OrderStatuses {
  static const String NEW_ORDER = 'new-order';
  static const String PROCESSING = 'processing';
  static const String SHIPPED = 'shipped';
  static const String DELIVERED = 'delivered';
  static const String CANCELLED = 'cancelled';
}

// دالة مساعدة لترجمة الحالة (مطابقة لـ getStatusDisplayName في JS)
String getStatusDisplayName(String status) {
    switch (status) {
        case OrderStatuses.NEW_ORDER: return 'طلب جديد';
        case OrderStatuses.PROCESSING: return 'قيد التجهيز';
        case OrderStatuses.SHIPPED: return 'تم الشحن';
        case OrderStatuses.DELIVERED: return 'تم التوصيل';
        case OrderStatuses.CANCELLED: return 'ملغي';
        default: return status;
    }
}

