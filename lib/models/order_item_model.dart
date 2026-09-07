// lib/models/order_item_model.dart (النسخة النهائية والمصححة)

class OrderItemModel {
  final String name; // اسم المنتج
  final int quantity; // الكمية المطلوبة
  final String unit; // وحدة القياس (مثل 'علبة', 'كجم')
  // ⭐️ تم تغيير الاسم من 'price' إلى 'unitPrice' ليتوافق مع باقي الكود ⭐️
  final double unitPrice; 
  final String imageUrl; 

  OrderItemModel({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.unitPrice, 
    this.imageUrl = '',
  });

  factory OrderItemModel.fromMap(Map<String, dynamic> data) {
    return OrderItemModel(
      name: data['name'] ?? 'صنف غير محدد',
      // تحويل إلى رقم صحيح
      quantity: (data['quantity'] as num?)?.toInt() ?? 0, 
      unit: data['unit'] ?? '', 
      // ⭐️ القراءة من حقل 'price' في Firestore وتخزينه كـ 'unitPrice' ⭐️
      // يجب أن يكون السعر رقمًا عشريًا
      unitPrice: (data['price'] as num?)?.toDouble() ?? 0.0, 
      imageUrl: data['imageUrl'] ?? '',
    );
  }
}

