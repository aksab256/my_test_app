// lib/utils/quantity_limits.dart
//
// القاعدة الموحدة لحدود كمية المنتج (B2B و B2C):
//   effectiveMin = productMin ?? 1
//   effectiveMax = min(availableStock, productMax) عند وجود مخزون معلوم،
//                  وإلا productMax عند وجوده، وإلا مفتوح (لا نخترع حدودًا).
// `availableStock` هو السقف الإجباري دائمًا متى كان معلومًا.
// ممنوع استخدام 9999 كقيمة وهمية: غياب المخزون = unknown (null) وليس رقمًا.
//
// ملف نقي (pure Dart) بلا Firebase/Flutter لتسهيل اختباره.

import 'dart:math';

/// سبب عدم صلاحية كمية ما.
enum QuantityInvalidReason {
  /// لا توجد كمية صالحة أصلًا: الحد الأدنى أكبر من المخزون.
  minAboveStock,

  /// الكمية أقل من الحد الأدنى الفعّال.
  belowMin,

  /// الكمية أكبر من الحد الأقصى الفعّال.
  aboveMax,
}

/// نتيجة حساب حدود كمية منتج واحد.
class QuantityLimits {
  /// الحد الأدنى الفعّال (productMin ?? 1، وبحد أدنى 1).
  final int effectiveMin;

  /// الحد الأقصى الفعّال، أو null عندما لا يوجد سقف معلوم
  /// (مخزون مجهول ولا حد أقصى للمنتج) — لا نخترع رقمًا.
  final int? effectiveMax;

  /// هل توجد أصلًا كمية تحقق الحدين معًا؟
  final bool hasValidQuantity;

  const QuantityLimits({
    required this.effectiveMin,
    required this.effectiveMax,
    required this.hasValidQuantity,
  });

  /// فحص كمية مطلوبة ضد هذه الحدود. تُرجع null عندما تكون صالحة.
  QuantityInvalidReason? validate(int qty) {
    if (!hasValidQuantity) return QuantityInvalidReason.minAboveStock;
    if (qty < effectiveMin) return QuantityInvalidReason.belowMin;
    if (effectiveMax != null && qty > effectiveMax!) {
      return QuantityInvalidReason.aboveMax;
    }
    return null;
  }
}

/// يحسب الحدود من القيم الخام. `availableStock: null` تعني مخزونًا مجهولًا
/// (وليس صفرًا ولا 9999). `productMin/Max: null` تعني حدًا مفتوحًا.
/// القيم الصفرية/السالبة للحدود تُعامل كغياب (مفتوح) عدا المخزون:
/// مخزون 0 معلوم يعني "لا يوجد متاح".
QuantityLimits resolveQuantityLimits({
  required int? availableStock,
  int? productMin,
  int? productMax,
}) {
  final int effectiveMin =
      (productMin != null && productMin > 0) ? productMin : 1;

  int? effectiveMax;
  if (availableStock != null) {
    if (productMax != null && productMax > 0) {
      effectiveMax = min(availableStock, productMax);
    } else {
      effectiveMax = availableStock;
    }
  } else if (productMax != null && productMax > 0) {
    effectiveMax = productMax;
  } else {
    effectiveMax = null;
  }

  final bool hasValidQuantity =
      effectiveMax == null || effectiveMin <= effectiveMax;

  return QuantityLimits(
    effectiveMin: effectiveMin,
    effectiveMax: effectiveMax,
    hasValidQuantity: hasValidQuantity,
  );
}

/// رسالة عربية واضحة لسبب الرفض، تتضمن الحدود الفعلية.
String quantityErrorMessage(
  QuantityInvalidReason reason,
  QuantityLimits limits, {
  int? availableStock,
}) {
  switch (reason) {
    case QuantityInvalidReason.minAboveStock:
      return 'غير متاح: الحد الأدنى (${limits.effectiveMin}) أكبر من المخزون المتاح'
          '${availableStock != null ? ' ($availableStock)' : ''}.';
    case QuantityInvalidReason.belowMin:
      return 'الكمية أقل من الحد الأدنى المسموح (${limits.effectiveMin}).';
    case QuantityInvalidReason.aboveMax:
      return 'تجاوز الحد المتاح'
          '${limits.effectiveMax != null ? ' (${limits.effectiveMax})' : ''}.';
  }
}
