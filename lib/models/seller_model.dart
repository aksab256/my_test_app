/// نموذج بيانات البائع / المورد (Seller Model)
/// تم تحديثه ليتوافق مع حقول مجموعة 'sellers' في Firestore
class SellerModel {
  final String id;
  final String name;    // سيمثل اسم المتجر (merchantName)
  final String phone;   // رقم الهاتف
  final String address; // العنوان الكامل

  SellerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
  });

  /// تحويل البيانات القادمة من Firestore إلى كائن SellerModel
  factory SellerModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return SellerModel(
      id: docId,
      
      // 1. جلب اسم المتجر: الأولوية لـ merchantName ثم fullname ثم التسميات القديمة
      name: data['merchantName'] ?? 
            data['fullname'] ?? 
            data['supermarketName'] ?? 
            data['name'] ?? 
            'متجر أكسب المعتمد', 

      // 2. جلب رقم الهاتف
      phone: data['phone'] ?? '---',

      // 3. جلب العنوان: الأولوية لـ fullAddress لأنه الأكثر تفصيلاً في مجموعة 'sellers'
      address: data['fullAddress'] ?? 
               data['address'] ?? 
               'العنوان غير محدد',
    );
  }

  /// كائن افتراضي يُستخدم أثناء التحميل أو في حالة عدم وجود بيانات
  factory SellerModel.defaultPlaceholder() {
    return SellerModel(
      id: '',
      name: 'جاري تحميل بيانات المتجر...',
      phone: '---',
      address: '---',
    );
  }

  /// تحويل الكائن إلى Map (إذا احتجت لتخزينه محلياً أو إرساله)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
    };
  }
}
