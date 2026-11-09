// lib/models/gift_promo_model.dart (النسخة النهائية والمُصححة)

import 'package:cloud_firestore/cloud_firestore.dart'; // 🆕 لاستخدام Timestamp

// Defines the structure for a Gift or Promotional Code, based on the HTML contract.
class GiftPromoModel {
  final String id;
  final String sellerId;
  final String promoName;
  final String giftOfferId;
  final String giftProductName;
  final String giftUnitName;
  final num giftOfferPriceSnapshot; // السعر وقت إنشاء العرض (لقطة)
  final int giftQuantityPerBase;
  // Phase 1 — value quote snapshot (nullable: legacy promos lack it).
  final double? triggerUnitPrice;
  final double? giftUnitPrice;
  final int? giftUnitIndex;
  final double? requiredPurchaseValue;
  final double? giftValue;
  final double? giftValuePercentage;
  final String? valueStatus; // 'ok' | 'value_unavailable' | null (legacy)

  // يمثل شرط تشغيل الهدية: قد يكون Min Order أو Specific Item.
  // يتم تخزينه كخريطة Map في Firestore (e.g., {type: 'min_order', value: 100.0})
  final Map<String, dynamic> trigger;

  final DateTime expiryDate;
  final int maxQuantity; // الحد الأقصى الكلي للهدايا المتاحة (الرصيد المحجوز)
  final int usedQuantity;
  final String status; // 'active', 'inactive', 'expired'
  final DateTime createdAt;

  GiftPromoModel({
    required this.id,
    required this.sellerId,
    required this.promoName,
    required this.giftOfferId,
    required this.giftProductName,
    required this.giftUnitName,
    required this.giftOfferPriceSnapshot,
    required this.giftQuantityPerBase,
    this.triggerUnitPrice,
    this.giftUnitPrice,
    this.giftUnitIndex,
    this.requiredPurchaseValue,
    this.giftValue,
    this.giftValuePercentage,
    this.valueStatus,
    required this.trigger,
    required this.expiryDate,
    required this.maxQuantity,
    required this.usedQuantity,
    required this.status,
    required this.createdAt,
  });

  // ----------------------------------------------------------------------------------
  // Factory constructor for creating a GiftPromoModel from a Firestore Map
  // ----------------------------------------------------------------------------------
  factory GiftPromoModel.fromMap(Map<String, dynamic> data, String documentId) {
    // 🆕 دالة مساعدة لتحويل أي تنسيق تاريخ (String, Timestamp) إلى DateTime
    DateTime _parseDate(dynamic date) {
      if (date is Timestamp) {
        return date.toDate();
      } else if (date is String) {
        return DateTime.parse(date);
      }
      return DateTime.now();
    }

    return GiftPromoModel(
      id: documentId,
      sellerId: data['sellerId'] as String? ?? '',
      promoName: data['promoName'] as String? ?? '',
      giftOfferId: data['giftOfferId'] as String? ?? '',
      giftProductName: data['giftProductName'] as String? ?? '',
      giftUnitName: data['giftUnitName'] as String? ?? '',
      giftOfferPriceSnapshot: data['giftOfferPriceSnapshot'] as num? ?? 0,
      giftQuantityPerBase: data['giftQuantityPerBase'] as int? ?? 1,
      triggerUnitPrice: (data['triggerUnitPrice'] as num?)?.toDouble(),
      giftUnitPrice: (data['giftUnitPrice'] as num?)?.toDouble(),
      giftUnitIndex: (data['giftUnitIndex'] as num?)?.toInt(),
      requiredPurchaseValue: (data['requiredPurchaseValue'] as num?)?.toDouble(),
      giftValue: (data['giftValue'] as num?)?.toDouble(),
      giftValuePercentage: (data['giftValuePercentage'] as num?)?.toDouble(),
      valueStatus: data['valueStatus'] as String?,

      // التأكد من أن حقل trigger هو Map
      trigger: (data['trigger'] is Map<String, dynamic>)
          ? data['trigger'] as Map<String, dynamic>
          : {},

      // 🆕 استخدام الدالة المساعدة لقراءة التاريخ بشكل آمن
      expiryDate: _parseDate(data['expiryDate']),
      
      maxQuantity: data['maxQuantity'] as int? ?? 0,
      usedQuantity: data['usedQuantity'] as int? ?? 0,
      status: data['status'] as String? ?? 'active',
      
      // 🆕 استخدام الدالة المساعدة لقراءة التاريخ بشكل آمن
      createdAt: _parseDate(data['createdAt']),
    );
  }

  // ----------------------------------------------------------------------------------
  // Convert the model to a Map for Firestore
  // 🛠️ تم تغيير اسم الدالة من toMap() إلى toJson() لزيادة الوضوح والتوافق
  // ----------------------------------------------------------------------------------
  Map<String, dynamic> toJson() {
    return {
      'sellerId': sellerId,
      'promoName': promoName,
      'giftOfferId': giftOfferId,
      'giftProductName': giftProductName,
      'giftUnitName': giftUnitName,
      'giftOfferPriceSnapshot': giftOfferPriceSnapshot,
      'giftQuantityPerBase': giftQuantityPerBase,
      if (triggerUnitPrice != null) 'triggerUnitPrice': triggerUnitPrice,
      if (giftUnitPrice != null) 'giftUnitPrice': giftUnitPrice,
      if (giftUnitIndex != null) 'giftUnitIndex': giftUnitIndex,
      if (requiredPurchaseValue != null) 'requiredPurchaseValue': requiredPurchaseValue,
      if (giftValue != null) 'giftValue': giftValue,
      if (giftValuePercentage != null) 'giftValuePercentage': giftValuePercentage,
      if (valueStatus != null) 'valueStatus': valueStatus,
      'trigger': trigger, // يتم تمرير الخريطة كما هي
      'maxQuantity': maxQuantity,
      'usedQuantity': usedQuantity,
      'status': status,
      
      // 🚨 نحفظ التاريخ كـ ISO String لضمان التوافق مع JS، ونفترض أن createdAt يتم تعيينه في الـ DataSource
      'expiryDate': expiryDate.toIso8601String(),
      // ❌ إزالة createdAt من هنا، يجب أن يتم تعيينه كـ FieldValue.serverTimestamp() في الـ DataSource
    };
  }
  
  // 🛠️ ترك toMap() كـ alias مؤقت لتجنب الأخطاء في الـ DataSource الذي لا يزال يستخدم toMap()
  // يجب حذفها لاحقاً وتعديل الـ DataSource لاستخدام toJson()
  Map<String, dynamic> toMap() => toJson();
}

