// lib/services/delivery_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class DeliveryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// دالة حساب تكلفة الرحلة بناءً على المسافة بالكيلومتر
  /// [distanceInKm] المسافة المقطوعة
  Future<double> calculateTripCost({required double distanceInKm}) async {
    try {
      // 1. جلب الإعدادات من Firestore (لوحة التحكم)
      // المسار: appSettings -> deliveryConfig
      var settingsDoc = await _db.collection('appSettings').doc('deliveryConfig').get();
      
      // قيم افتراضية في حالة عدم وجود المستند في Firestore (لحماية التطبيق من الانهيار)
      double baseFare = 10.0; // فتحة العداد
      double kmRate = 5.0;   // سعر الكيلو
      double minFare = 15.0;  // الحد الأدنى للرحلة

      if (settingsDoc.exists && settingsDoc.data() != null) {
        final data = settingsDoc.data()!;
        baseFare = (data['baseFare'] ?? 10.0).toDouble();
        kmRate = (data['kmRate'] ?? 5.0).toDouble();
        minFare = (data['minFare'] ?? 15.0).toDouble();
      }

      // 2. تطبيق المعادلة (فتحة العداد + المسافة * سعر الكيلو)
      double total = baseFare + (distanceInKm * kmRate);

      // 3. التأكد من أن السعر لا يقل عن الحد الأدنى
      if (total < minFare) {
        total = minFare;
      }

      // تقريب الرقم لأقرب قرشين (اختياري)
      return double.parse(total.toStringAsFixed(2));
    } catch (e) {
      print("Error in DeliveryService: $e");
      return 15.0; // سعر أمان في حالة حدوث أي خطأ تقني
    }
  }

  /// دالة مساعدة لحساب المسافة بين نقطتين جغرافيتين بالكيلومتر
  double calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    double distanceInMeters = Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
    return distanceInMeters / 1000;
  }
}

