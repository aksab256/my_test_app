// المسار: lib/models/manufacturer_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class ManufacturerModel {
  final String id;
  final String name;
  final String description;
  final String imageUrl;      // الرابط المباشر للصورة
  final String? imagePublicId; // معرف الصورة (إذا وجد) لزيادة الأمان في العرض
  final bool isActive;
  final List<String> subCategoryIds; // قائمة الأقسام الفرعية المرتبطة
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ManufacturerModel({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    this.imagePublicId,
    required this.isActive,
    this.subCategoryIds = const [],
    this.createdAt,
    this.updatedAt,
  });

  // 💡 دالة لإنشاء نموذج من DocumentSnapshot (لقراءة وثيقة واحدة)
  factory ManufacturerModel.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    
    if (data == null) {
      throw StateError('Manufacturer document data is null for ID: ${doc.id}');
    }
    
    return ManufacturerModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '', 
      imagePublicId: data['imagePublicId'], // قراءة الـ Public ID إن وجد
      isActive: data['isActive'] ?? true,
      // تحويل البيانات القادمة من Firestore إلى قائمة نصوص (List of Strings) بشكل آمن
      subCategoryIds: data['subCategoryIds'] is List 
          ? List<String>.from(data['subCategoryIds']) 
          : [],
      // معالجة التواريخ القادمة من Firebase (Timestamp)
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : null,
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
    );
  }

  // 💡 دالة لإنشاء قائمة من QuerySnapshot (لقراءة مجموعة وثائق)
  static List<ManufacturerModel> fromQuerySnapshot(QuerySnapshot query) {
    return query.docs.map((doc) => ManufacturerModel.fromDocumentSnapshot(doc)).toList();
  }

  // 💡 دالة اختيارية لتحويل الكائن إلى Map (مفيد في عمليات التحديث أو الإضافة)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'imagePublicId': imagePublicId,
      'isActive': isActive,
      'subCategoryIds': subCategoryIds,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
