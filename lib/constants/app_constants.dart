// lib/constants/app_constants.dart

import 'package:flutter/material.dart';

// ----------------------------------------------------------------------
// ثوابت Firestore للمجموعات (SCREAMING_SNAKE_CASE)
// ----------------------------------------------------------------------
const String SELLERS_COLLECTION = 'sellers'; // المتاجر والبائعين
const String STORES_COLLECTION = 'users';
const String OFFERS_COLLECTION = 'productOffers';
const String REPORTS_COLLECTION = 'reports';
const String GIFT_PROMO_COLLECTION = 'giftPromos';

// ----------------------------------------------------------------------
// ثوابت Firestore للحقول
// ----------------------------------------------------------------------
const String DELIVERY_AREAS_FIELD = 'deliveryAreas'; 
const String FIRESTORE_DELIVERY_AREAS_FIELD = 'deliveryAreas'; 
const String SELLER_ID_FIELD = 'sellerId';

// ----------------------------------------------------------------------
// ثوابت واجهة برمجة التطبيقات (APIs) وخرائط المحافظات
// ----------------------------------------------------------------------
const String API_GATEWAY_ENDPOINT = 'https://updatelocation-tmfag3rhdq-uc.a.run.app';

// 🎯 المسار الافتراضي (Fallback) للإسكندرية لضمان عدم كسر أي كود قديم[cite: 6]
const String GEOJSON_FILE_PATH = 'assets/OSMB-bc319d822a17aa9ad1089fc05e7d4e752460f877.geojson';

// 🎯 خريطة مسارات ملفات GeoJSON للمحافظات المتاحة حالياً
const Map<String, String> GOVERNORATE_GEOJSON_PATHS = {
  'alexandria': 'assets/OSMB-bc319d822a17aa9ad1089fc05e7d4e752460f877.geojson',
  'buhayrah': 'assets/governorates/AlBuhayrah.json',
};

// الإحداثيات الافتراضية لمركز الخريطة[cite: 6]
const double MAP_CENTER_LAT = 28.5;
const double MAP_CENTER_LNG = 30.9;
const double MAP_ZOOM = 5.5;

// ----------------------------------------------------------------------
// ثوابت أخرى[cite: 6]
// ----------------------------------------------------------------------
const Map<String, Color> ORDER_STATUSES_MAP = {
  'new-order': Colors.blue,
  'pending': Colors.orange,
  'delivered': Colors.green,
  'cancelled': Colors.red,
};