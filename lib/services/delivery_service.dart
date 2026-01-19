import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class DeliveryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// دالة حساب التكلفة التفصيلية بناءً على إعدادات كل مركبة
  /// ترفع خطأ (Exception) في حال عدم وجود المستند لضمان دقة البيانات
  Future<Map<String, double>> calculateDetailedTripCost({
    required double distanceInKm,
    required String vehicleType
  }) async {
    try {
      // 1. تحديد اسم المستند بناءً على نوع المركبة
      String configDocName = "${vehicleType}Config";
      
      debugPrint("🚕 جاري جلب الإعدادات لمركبة: $configDocName");

      // 2. جلب الإعدادات من كولكشن appSettings
      var settingsDoc = await _db.collection('appSettings').doc(configDocName).get();

      // 🛑 فحص وجود المستند: إذا لم يوجد يرمي خطأ فوراً ولا يكمل الحسبة
      if (!settingsDoc.exists || settingsDoc.data() == null) {
        throw Exception("خطأ حرج: مستند الإعدادات ($configDocName) غير موجود في Firebase. يرجى مراجعة لوحة التحكم.");
      }

      final data = settingsDoc.data()!;

      // 3. استخراج البيانات (مع التأكد من وجود الحقول الأساسية)
      // ملاحظة: نستخدم ?? لرمي خطأ إذا كان الحقل نفسه مفقوداً داخل المستند
      double baseFare = (data['baseFare'] as num).toDouble();
      double kmRate = (data['kmRate'] as num).toDouble();
      double minFare = (data['minFare'] as num).toDouble();
      double serviceFeeFixed = (data['serviceFee'] ?? 0.0).toDouble(); // رسوم ثابتة إضافية (اختياري)
      
      // جلب نسبة العمولة (مثلاً 15.0 تعني 15%)
      double serviceFeePercentage = (data['serviceFeePercentage'] as num).toDouble() / 100;

      // 4. منطق الحسبة المالية
      // أ- حساب صافي الرحلة الأساسي (العداد + المسافة)
      double tripSubtotal = baseFare + (distanceInKm * kmRate);
      
      // ب- تطبيق الحد الأدنى للرحلة
      if (tripSubtotal < minFare) {
        tripSubtotal = minFare;
      }

      // ج- حساب قيمة عمولة المنصة من صافي الرحلة
      double commissionAmount = tripSubtotal * serviceFeePercentage;

      // د- السعر الإجمالي الذي سيدفعه المستخدم
      double totalForUser = tripSubtotal + commissionAmount + serviceFeeFixed;

      debugPrint("✅ تم الحساب بنجاح: إجمالي العميل: $totalForUser | عمولة المنصة: $commissionAmount");

      return {
        'totalPrice': double.parse(totalForUser.toStringAsFixed(2)),      // السعر الشامل للعميل
        'commissionAmount': double.parse(commissionAmount.toStringAsFixed(2)), // ما سيخصم من محفظة المندوب
        'driverNet': double.parse(tripSubtotal.toStringAsFixed(2)),       // ما سيتبقى للمندوب في جيبه
      };

    } catch (e) {
      debugPrint("❌ فشل حساب التكلفة: $e");
      // نعيد رمي الخطأ ليتم التعامل معه في الواجهة (إظهار رسالة خطأ للعميل)
      rethrow;
    }
  }

  /// دالة حساب المسافة بين نقطتين بالكيلومتر
  double calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    double distanceInMeters = Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
    return distanceInMeters / 1000;
  }
}
