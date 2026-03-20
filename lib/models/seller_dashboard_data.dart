// lib/models/seller_dashboard_data.dart

class SellerDashboardData {                       
  final int totalOrders;
  final double completedSalesAmount;
  final int pendingOrdersCount;
  final int newOrdersCount; 
  final String sellerName; 
  // 🔵 إضافة حقل الحالة ليتوافق مع Firestore ويحل مشكلة الـ Build
  final String status; 
    
  SellerDashboardData({
    required this.totalOrders,
    required this.completedSalesAmount,             
    required this.pendingOrdersCount,
    required this.newOrdersCount,
    required this.sellerName,
    required this.status, // 🔵 مطلوب هنا
  });

  // نموذج بيانات فارغ/تحميل
  factory SellerDashboardData.loading() {
    return SellerDashboardData(                       
      totalOrders: 0,
      completedSalesAmount: 0.0,                      
      pendingOrdersCount: 0,
      newOrdersCount: 0, 
      sellerName: 'جاري التحميل...',
      status: 'active', // قيمة افتراضية حتى يتم التحميل
    );
  }

  // 🔵 تأكد من تحديث الـ factory اللي بيقرأ من الـ Map في الكنترولر (إذا كان موجوداً هناك)
  // بحيث يقرأ ['status'] ?? 'inactive'
}
