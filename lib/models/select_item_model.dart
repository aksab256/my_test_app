import 'package:cloud_firestore/cloud_firestore.dart';

// نموذج مبسط يمثل عنصراً يمكن اختياره في قائمة منسدلة (Selectable Item)
// يستخدم لتمثيل الأقسام، المنتجات، الوحدات، إلخ.
class SelectItemModel {
  final String id;
  final String name;
  final List<dynamic>? units; // قائمة الوحدات المتاحة للمنتج (اختياري)
  final String? imageUrl;
  final String? description;

  SelectItemModel({
    required this.id,
    required this.name,
    this.units,
    this.imageUrl,
    this.description,
  });

  // ⭐️ تم إضافة دالة التحويل من Firestore هنا لحل مشكلة 'undefined_method' ⭐️
  factory SelectItemModel.fromFirestore(DocumentSnapshot doc) {
    final dataMap = doc.data() as Map<String, dynamic>?;

    // محاولة جلب الاسم من حقل 'name' (للأقسام/الفئات) أو 'productName' (للمنتجات)
    final String nameField = dataMap?['name']?.toString() ?? dataMap?['productName']?.toString() ?? '';

    return SelectItemModel(
      id: doc.id,
      name: nameField,
      // التأكد من أن 'units' عبارة عن قائمة قبل استخدامها
      units: dataMap?['units'] is List ? dataMap!['units'] : null,
      imageUrl: dataMap?['imageUrl']?.toString(),
      description: dataMap?['description']?.toString(),
    );
  }

  // التحويل إلى JSON/Map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'units': units,
      'imageUrl': imageUrl,
      'description': description,
    };
  }
}

