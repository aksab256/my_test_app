// lib/models/buyer_details_model.dart
class BuyerDetailsModel {
  final String name;
  final String phone;
  final String address; // يُستخدم كـ 'عنوان التوصيل' في الـ HTML

  BuyerDetailsModel({
    required this.name,
    required this.phone,
    required this.address,
  });

  factory BuyerDetailsModel.fromMap(Map<String, dynamic> data) {
    return BuyerDetailsModel(
      // ⭐️ يتم استخدام حقل 'name' في الجافاسكريبت ⭐️
      name: data['name'] ?? 'اسم غير متوفر',
      // ⭐️ يتم استخدام حقل 'phone' في الجافاسكريبت ⭐️
      phone: data['phone'] ?? 'هاتف غير متوفر',
      // ⭐️ يتم استخدام حقل 'address' في الجافاسكريبت ⭐️
      address: data['address'] ?? 'عنوان غير متوفر',
    );
  }
}

