// lib/constants/delivery_constants.dart

// 🔥🔥🔥 Firebase Cloud Function Endpoint 🔥🔥🔥
const String API_GATEWAY_ENDPOINT = 
    'https://us-central1-aksab-erp.cloudfunctions.net/updateLocation';

// 🎯 المسار الافتراضي (Fallback) للإسكندرية لضمان عدم كسر الأكواد القديمة
const String GEOJSON_FILE_PATH = 
    'assets/OSMB-bc319d822a17aa9ad1089fc05e7d4e752460f877.geojson'; 

// 🎯 خريطة مسارات ملفات GeoJSON للمحافظات المتاحة
const Map<String, String> GOVERNORATE_GEOJSON_PATHS = {
  'alexandria': 'assets/OSMB-bc319d822a17aa9ad1089fc05e7d4e752460f877.geojson',
  'buhayrah': 'assets/governorates/AlBuhayrah.json',
};

// الثابتة المستخدمة لتحديد حقل مناطق التوصيل في Firestore
const String FIRESTORE_DELIVERY_AREAS_FIELD = 'deliveryAreas';