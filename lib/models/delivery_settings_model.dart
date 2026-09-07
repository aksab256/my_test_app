// lib/models/delivery_settings_model.dart                                                      
import 'package:cloud_firestore/cloud_firestore.dart';                                                                                          

class LocationModel {
  final double lat;
  final double lng;

  LocationModel({required this.lat, required this.lng});

  Map<String, dynamic> toFirestore() {
    return {'lat': lat, 'lng': lng};
  }
}                                               

class DeliverySettingsModel {
  final String ownerId;
  final String supermarketName;
  final String address;                           
  final LocationModel? location;
  final bool deliveryActive;                      
  final String deliveryHours;
  final String whatsappNumber;
  final String deliveryContactPhone;
  final double deliveryFee;
  final double minimumOrderValue;                 
  final String descriptionForDelivery;

  DeliverySettingsModel({                           
    required this.ownerId,
    this.supermarketName = '',
    this.address = '',                              
    this.location,
    this.deliveryActive = false,
    this.deliveryHours = '',                        
    this.whatsappNumber = '',                       
    this.deliveryContactPhone = '',
    this.deliveryFee = 0.0,                         
    this.minimumOrderValue = 0.0,                   
    this.descriptionForDelivery = '',             
  });

  // دالة تحويل من Firestore
  factory DeliverySettingsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;                                               
    if (data == null) {
      // إنشاء نموذج فارغ إذا لم يكن المستند موجوداً                                                   
      return DeliverySettingsModel(ownerId: doc.id);
    }

    // 💡 التعديل هنا: قراءة الموقع بشكل أكثر أماناً وتسامحاً مع غياب الإحداثيات
    LocationModel? locationModel;
    
    final locationData = data['location'] as Map<String, dynamic>?;
    
    final lat = (locationData?['lat'] as num?)?.toDouble();
    final lng = (locationData?['lng'] as num?)?.toDouble();

    if (lat != null && lng != null) {
      locationModel = LocationModel(                    
        lat: lat,
        lng: lng,
      );
    }                                           
    
    return DeliverySettingsModel(
      ownerId: doc.id,
      supermarketName: data['supermarketName'] ?? '',                                                 
      address: data['address'] ?? '',
      location: locationModel,                        
      deliveryActive: data['deliveryActive'] ?? false,
      deliveryHours: data['deliveryHours'] ?? '',
      whatsappNumber: data['whatsappNumber'] ?? '',
      deliveryContactPhone: data['deliveryContactPhone'] ?? '',
      // تحويل الأرقام بأمان إلى double (تم التأكد من صحتها سابقاً)
      deliveryFee: (data['deliveryFee'] as num?)?.toDouble() ?? 0.0,                                  
      minimumOrderValue: (data['minimumOrderValue'] as num?)?.toDouble() ?? 0.0,                      
      descriptionForDelivery: data['descriptionForDelivery'] ?? '',                                 
    );
  }                                                                                               
  
  // دالة تحويل إلى Firestore
  Map<String, dynamic> toFirestore() {              
    return {                                          
      'ownerId': ownerId,
      'supermarketName': supermarketName,
      'address': address,                             
      'location': location?.toFirestore(),
      'deliveryActive': deliveryActive,               
      'deliveryHours': deliveryHours,
      'whatsappNumber': whatsappNumber,
      'deliveryContactPhone': deliveryContactPhone,
      'deliveryFee': deliveryFee,
      'minimumOrderValue': minimumOrderValue,
      'descriptionForDelivery': descriptionForDelivery,
      'lastUpdated': FieldValue.serverTimestamp(),                                                  
    };                                            
  }                                             
}


