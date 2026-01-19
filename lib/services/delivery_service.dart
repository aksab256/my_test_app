import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class DeliveryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<Map<String, double>> calculateDetailedTripCost({
    required double distanceInKm,
    required String vehicleType
  }) async {
    try {
      String configDocName = "${vehicleType}Config";
      var settingsDoc = await _db.collection('appSettings').doc(configDocName).get();

      if (!settingsDoc.exists || settingsDoc.data() == null) {
        throw Exception("مستند الإعدادات ($configDocName) غير موجود.");
      }

      final data = settingsDoc.data()!;

      // 1. جلب البيانات الأساسية من Firestore
      double baseFare = (data['baseFare'] as num).toDouble();
      double kmRate = (data['kmRate'] as num).toDouble();
      double minFare = (data['minFare'] as num).toDouble();
      
      // الرقم الثابت (الحد الأدنى للعمولة) - مثلاً 5 جنيه
      double serviceFeeFixed = (data['serviceFee'] as num).toDouble(); 
      
      // النسبة المئوية - مثلاً 10.0 تعني 10%
      double serviceFeePercentage = (data['serviceFeePercentage'] as num).toDouble() / 100;

      // 2. حساب تكلفة الرحلة الصافية (مسافة + فتح عداد)
      double tripSubtotal = baseFare + (distanceInKm * kmRate);
      
      // التأكد من عدم نزول السعر عن الحد الأدنى للرحلة
      if (tripSubtotal < minFare) {
        tripSubtotal = minFare;
      }

      // 3. تطبيق منطق "الأكبر بين النسبة والرقم الثابت"
      // حساب قيمة النسبة
      double calculatedByPercentage = tripSubtotal * serviceFeePercentage;
      
      // المقارنة: لو النسبة طلعت (1، 2، 3، 4) والارقم الثابت 5 -> هياخد 5
      // لو النسبة طلعت (6) والارقام الثابت 5 -> هياخد 6
      double finalCommission = (calculatedByPercentage > serviceFeeFixed) 
                                ? calculatedByPercentage 
                                : serviceFeeFixed;

      // 4. السعر الإجمالي الذي يدفعه المستخدم (الصافي + العمولة المختارة)
      double totalForUser = tripSubtotal + finalCommission;

      debugPrint("📊 الحسبة: صافي للمندوب: $tripSubtotal | عمولة مئوية: $calculatedByPercentage | الثابت: $serviceFeeFixed");
      debugPrint("✅ تم اختيار عمولة: $finalCommission");

      return {
        'totalPrice': double.parse(totalForUser.toStringAsFixed(2)),      
        'commissionAmount': double.parse(finalCommission.toStringAsFixed(2)), 
        'driverNet': double.parse(tripSubtotal.toStringAsFixed(2)),       
      };

    } catch (e) {
      debugPrint("❌ فشل حساب التكلفة: $e");
      rethrow; 
    }
  }

  double calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng) / 1000;
  }
}
