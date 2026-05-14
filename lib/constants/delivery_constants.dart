// lib/constants/delivery_constants.dart

// 🔥🔥🔥 Firebase Cloud Function Endpoint (تم التحديث للجزيرة المستقلة) 🔥🔥🔥
const String API_GATEWAY_ENDPOINT = 
    'https://us-central1-aksab-erp.cloudfunctions.net/updateLocation';

// مسار ملف GeoJSON الذي يحتوي على حدود المناطق الإدارية
// في Flutter، يجب أن يكون الملف داخل مجلد assets ويتم الإعلان عنه في pubspec.yaml
const String GEOJSON_FILE_PATH = 
    'assets/OSMB-bc319d822a17aa9ad1089fc05e7d4e752460f877.geojson'; 

// الثابتة المستخدمة لتحديد حقل مناطق التوصيل في Firestore
const String FIRESTORE_DELIVERY_AREAS_FIELD = 'deliveryAreas';