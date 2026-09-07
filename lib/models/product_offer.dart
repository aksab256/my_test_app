// lib/models/product_offer.dart

// يجب استيراد هذه الحزمة لمعالجة حقل Timestamp من Firestore
import 'package:cloud_firestore/cloud_firestore.dart';

// -----------------------------------------------------------------------------
// 💡 UnitOffer Model
// يمثل هذا الوحدة والسعر المقابل لها داخل العرض (من مصفوفة 'units')
// -----------------------------------------------------------------------------
class UnitOffer {
  final String unitName;
  final double price;

  UnitOffer({
    required this.unitName,
    required this.price,
  });

  // بناء الكائن من بيانات JSON/Map (كما في Firestore)
  factory UnitOffer.fromJson(Map<String, dynamic> json) {
    return UnitOffer(
      unitName: json['unitName'] as String? ?? 'وحدة غير معرفة',
      // يجب التأكد من تحويل القيمة الرقمية (قد تكون int أو double) إلى double
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // تحويل الكائن إلى Map لإرساله أو تحديثه في Firestore
  Map<String, dynamic> toMap() {
    return {
      'unitName': unitName,
      'price': price,
    };
  }
}

// -----------------------------------------------------------------------------
// 💡 Product Placeholder Model
// هذا يمثل جزء تفاصيل المنتج (productDetails) الذي يتم جلبه من مجموعة 'products'
// -----------------------------------------------------------------------------
class Product {
  final String id;
  final String name;
  final List<String> imageUrls;

  Product({
    required this.id,
    required this.name,
    required this.imageUrls,
  });

  // دالة لبناء المنتج من مستند Firestore في مجموعة 'products'
  factory Product.fromJson(String id, Map<String, dynamic> json) {
    return Product(
      id: id,
      name: json['name'] as String? ?? 'منتج غير متوفر',
      imageUrls: (json['imageUrls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

// -----------------------------------------------------------------------------
// 🔑 ProductOffer Model (marketOffer Document)
// يمثل مستند العرض الكامل من مجموعة marketOffer
// -----------------------------------------------------------------------------
class ProductOffer {
  final String id;
  final String ownerId;
  final String productId;
  final String supermarketName;
  final DateTime createdAt;
  final List<UnitOffer> units;
  final Product productDetails; // تفاصيل المنتج المدمجة

  ProductOffer({
    required this.id,
    required this.ownerId,
    required this.productId,
    required this.supermarketName,
    required this.createdAt,
    required this.units,
    required this.productDetails,
  });

  // Constructor لإنشاء الكائن من بيانات Firestore (DocumentSnapshot)
  // يتطلب تمرير تفاصيل المنتج (productDetails) التي تم جلبها مسبقاً من مسار آخر
  factory ProductOffer.fromFirestore({
    required DocumentSnapshot doc,
    required Product productDetails, 
  }) {
    final data = doc.data() as Map<String, dynamic>?;

    if (data == null) {
      throw Exception('Firestore document data is null');
    }

    // معالجة مصفوفة الوحدات (units)
    final List<UnitOffer> unitsList = (data['units'] as List<dynamic>?)
            ?.map((unitJson) => UnitOffer.fromJson(unitJson as Map<String, dynamic>))
            .toList() ??
        [];

    // معالجة حقل تاريخ الإنشاء (createdAt) - من Timestamp إلى DateTime
    final Timestamp? timestamp = data['createdAt'] as Timestamp?;
    final DateTime createdAtDate = timestamp?.toDate() ?? DateTime.now();

    return ProductOffer(
      id: doc.id,
      ownerId: data['ownerId'] as String? ?? '',
      productId: data['productId'] as String? ?? '',
      supermarketName: data['supermarketName'] as String? ?? 'غير معروف',
      createdAt: createdAtDate,
      units: unitsList,
      productDetails: productDetails, // دمج تفاصيل المنتج المجلوبة
    );
  }
}


