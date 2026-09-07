import 'package:cloud_firestore/cloud_firestore.dart';

// نموذج يمثل فئة رئيسية (Main Category)
class CategoryModel {
  final String id;
  final String name;
  final String imageUrl;
  final bool status;
  final int order;

  CategoryModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.status,
    required this.order,
  });

  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    
    // قيمة الحالة من Firestore
    final statusString = data?['status'] as String?;
    
    return CategoryModel(
      id: doc.id,
      name: data?['name'] as String? ?? 'قسم غير معروف',
      imageUrl: data?['imageUrl'] as String? ?? 'https://placehold.co/150x120/43b97f/ffffff?text=Category',
      // ✅ التصحيح: ضمان أن القيمة المعادة هي bool.
      // نتحقق مما إذا كانت السلسلة موجودة وتساوي 'active'.
      status: statusString != null && statusString == 'active', 
      order: (data?['order'] as num?)?.toInt() ?? 999,
    );
  }
}

