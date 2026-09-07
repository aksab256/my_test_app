// lib/data_sources/gift_promo_data_source.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // لاستخدام debugPrint
import 'package:my_test_app/models/gift_promo_model.dart';
import 'package:my_test_app/models/offer_model.dart'; // نحتاج لنموذج OfferUnitModel

class GiftPromoDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // أسماء المجموعات (Constants)
  static const String PRODUCT_OFFERS_COLLECTION = 'productOffers';
  static const String GIFT_PROMOS_COLLECTION = 'giftPromos';

  /**
   * ينفذ معاملة Firestore لإنشاء عرض الهدية وحجز المخزون من عرض الهدية المجانية.
   *
   * @param promoModel كائن GiftPromoModel المراد حفظه.
   */
  Future<void> createPromo(GiftPromoModel promoModel) async {
    final String giftOfferId = promoModel.giftOfferId;
    final int totalPromoQuantity = promoModel.maxQuantity;

    if (totalPromoQuantity <= 0) {
      throw Exception('الكمية القصوى للحجز يجب أن تكون أكبر من صفر.');
    }

    final giftOfferRef =
        _firestore.collection(PRODUCT_OFFERS_COLLECTION).doc(giftOfferId);

    try {
      // 1. بدء المعاملة (Transaction) لضمان حجز الرصيد
      await _firestore.runTransaction((transaction) async {
        // 2. قراءة وثيقة عرض الهدية داخل المعاملة
        final giftOfferSnapshot = await transaction.get(giftOfferRef);

        if (!giftOfferSnapshot.exists) {
          throw Exception('GIFT_DOC_MISSING: وثيقة الهدية غير موجودة.');
        }

        final giftData = giftOfferSnapshot.data();
        final List<dynamic>? unitsArray = giftData?['units'];

        // 3. التحقق من بنية البيانات (كما في كود JS)
        if (unitsArray == null || unitsArray.isEmpty || unitsArray.first == null) {
          throw Exception('INVALID_UNITS_ARRAY: بنية بيانات الوحدات غير صالحة.');
        }

        // نستهدف دائمًا الوحدة الرئيسية في الفهرس 0
        final unitIndex = 0;
        final unitMap = unitsArray[unitIndex] as Map<String, dynamic>;

        // قراءة المخزون المتاح الحالي
        final currentAvailableStock =
            (unitMap['availableStock'] as num?)?.toInt() ?? 0;
        final currentReservedStock =
            (unitMap['reservedForPromos'] as num?)?.toInt() ?? 0;

        debugPrint(
            'DEBUG TRANSACTION: Current Stock: $currentAvailableStock, Required: $totalPromoQuantity');

        // 4. التحقق من الرصيد الكافي
        if (currentAvailableStock < totalPromoQuantity) {
          throw Exception(
              'INSUFFICIENT_STOCK|${currentAvailableStock}: الرصيد المتاح غير كافٍ للحجز.');
        }

        // 5. تعديل المصفوفة في الذاكرة (حجز الرصيد)
        final newAvailableStock = currentAvailableStock - totalPromoQuantity;
        final newReservedStock = currentReservedStock + totalPromoQuantity;

        // إنشاء خريطة الوحدة المحدثة (مع الحفاظ على الحقول الأخرى)
        final updatedUnit0 = {
          ...unitMap,
          'availableStock': newAvailableStock,
          'reservedForPromos': newReservedStock,
          // لا حاجة لـ updatedAt هنا، يمكن استخدام FieldValue.serverTimestamp() خارجياً
        };

        // إنشاء نسخة جديدة من المصفوفة واستبدال الوحدة 0
        final newUnitsArray = [...unitsArray];
        newUnitsArray[unitIndex] = updatedUnit0;

        // 6. إنشاء عرض الهدية (SET)
        final promoDocRef =
            _firestore.collection(GIFT_PROMOS_COLLECTION).doc();
        // 💥 تم التصحيح هنا: تغيير toJSON() إلى toMap()
        transaction.set(promoDocRef, promoModel.toMap());

        // 7. تحديث وثيقة عرض الهدية (حجز المخزون الفعلي)
        transaction.update(giftOfferRef, {
          'units': newUnitsArray, // تمرير المصفوفة الجديدة بالكامل
          'updatedAt': FieldValue.serverTimestamp(),
        });

        debugPrint('DEBUG TRANSACTION: Transaction committed successfully.');
      });
    } on Exception catch (e) {
      debugPrint('Error in createPromo transaction: $e');
      // إعادة رمي الخطأ ليتم التقاطه في شاشة العرض
      throw Exception('فشل إنشاء عرض الهدية والحجز: $e');
    }
  }
}

