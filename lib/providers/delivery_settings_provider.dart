// lib/providers/delivery_settings_provider.dart

import 'package:flutter/material.dart';         
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/delivery_settings_model.dart';
import 'buyer_data_provider.dart'; // 💡 تم الإبقاء على هذا الاستيراد
                       
// نموذج مبسط لبيانات التاجر من مجموعة users    
class DealerProfile {                             
  final String name;                              
  final String address;
  final LocationModel? location;                  
  final String phone;
                                                  
  DealerProfile({required this.name, required this.address, this.location, required this.phone});                                               
}
                                                
class DeliverySettingsProvider with ChangeNotifier {                                              
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
                                                  
  // 💡 متغير BuyerDataProvider الحقيقي           
  final BuyerDataProvider _buyerData;                                                             
  // 1. تعريف المتغيرات التي ستحمل القيمة الحقيقية
  late final String _currentDealerId;             
  late final String _currentDealerOriginalPhone;                                                                                                  
  static const DELIVERY_COLLECTION = 'deliverySupermarkets';
  static const USERS_COLLECTION = 'users';                                                        
  // حالة التحميل والرسائل                        
  bool _isLoading = false;
  String? _message;                               
  bool _isSuccess = true;                                                                         
  // البيانات                                     
  DealerProfile? _dealerProfile;                  
  DeliverySettingsModel? _settings;
                                                  
  // الحقول القابلة للتعديل
  bool _deliveryActive = false;                   
  String _deliveryHours = '';                     
  String _whatsappNumber = '';                    
  String _deliveryPhone = '';                     
  String _deliveryFee = '0.0';
  String _minimumOrderValue = '0.0';
  String _descriptionForDelivery = '';                                                            
  // Getters                                      
  bool get isLoading => _isLoading;
  String? get message => _message;                
  bool get isSuccess => _isSuccess;               
  DealerProfile? get dealerProfile => _dealerProfile;                                             
  DeliverySettingsModel? get settings => _settings;                                                                                               
  // Getters لحالة الفورم                         
  bool get deliveryActive => _deliveryActive;
  String get deliveryHours => _deliveryHours;     
  String get whatsappNumber => _whatsappNumber;   
  String get deliveryPhone => _deliveryPhone;     
  String get deliveryFee => _deliveryFee;
  String get minimumOrderValue => _minimumOrderValue;                                             
  String get descriptionForDelivery => _descriptionForDelivery;
                                                  
  // 2. تحديث Constructor ليتلقى BuyerDataProvider                                                
  DeliverySettingsProvider(this._buyerData) {       
    // 3. تعيين القيم الحقيقية من BuyerDataProvider
    _currentDealerId = _buyerData.loggedInUser?.id ?? '';
    _currentDealerOriginalPhone = _buyerData.loggedInUser?.phone ?? '';                         
    loadDeliveryData();                           
  }                                                                                               
  // ------------------------------------
  // وظائف إدارة الحالة                           
  // ------------------------------------
  void showNotification(String msg, bool success) {                                                 
    _message = msg;                                 
    _isSuccess = success;
    notifyListeners();                            
  }                                               
  void clearNotification() {                        
    _message = null;
    notifyListeners();                            
  }                                                                                               
  void setIsLoading(bool value) {
    _isLoading = value;
    notifyListeners();                            
  }                                                                                               
  void setDeliveryActive(bool value) {              
    _deliveryActive = value;
    notifyListeners();                            
  }                                                                                               
  // ------------------------------------         
  // وظائف تحميل البيانات                         
  // ------------------------------------       
  Future<void> loadDeliveryData() async {           
    setIsLoading(true);                             
    clearNotification();                        
    
    // 💡 استخدام المتغير الحقيقي (مطابق لـ JS في الحصول على ID)
    if (_currentDealerId.isEmpty) {                    
        showNotification('يجب أن تكون مسجلاً كتاجر.', false);                                                                                            
        setIsLoading(false);                            
        return;                                      
    }                                                                                                                                               
    try {                                               
        // 1. جلب بيانات التاجر الأساسية (مطابق لـ JS في طريقة البحث doc(ID))
        final dealerDocSnap = await _firestore.collection(USERS_COLLECTION).doc(_currentDealerId).get();                                                
        if (dealerDocSnap.exists) {
            final data = dealerDocSnap.data()!;                                                             
            LocationModel? locationModel;                   
            if (data['location'] is Map && data['location']!['lat'] != null) {                                
                locationModel = LocationModel(
                    lat: (data['location']['lat'] as num).toDouble(),
                    lng: (data['location']['lng'] as num).toDouble(),                                             
                );                                            
            }
                                                            
            _dealerProfile = DealerProfile(
                name: data['fullname'] ?? data['name'] ?? 'غير معروف',                                          
                address: data['address'] ?? 'غير متوفر',                                                        
                location: locationModel,                        
                phone: data['phone'] ?? '' // جلب الهاتف من ملف التاجر الأساسي
            );                                                                                              
            
            _currentDealerOriginalPhone = _dealerProfile!.phone;                                                                                        
        } else {
             // إذا فشل الجلب، هذا هو مصدر الرسالة الأولى
             showNotification('لم يتم العثور على ملف التاجر الأساسي.', false);                               
             setIsLoading(false);                            
             return;
        }                                                                                                                                               
        // 2. جلب إعدادات الدليفري الفعلية (مطابق لـ JS في طريقة البحث doc(ID))
        final deliveryDocSnap = await _firestore.collection(DELIVERY_COLLECTION).doc(_currentDealerId).get();                                   
        
        if (deliveryDocSnap.exists) {                                                                       
            _settings = DeliverySettingsModel.fromFirestore(deliveryDocSnap); // 🚨 هذا قد ينهار هنا إذا كانت البيانات غير نظيفة 🚨
            
            // تهيئة حقول الفورم بالقيم الموجودة
            _deliveryActive = _settings!.deliveryActive;                                                    
            _deliveryHours = _settings!.deliveryHours;                                                      
            _whatsappNumber = _settings!.whatsappNumber;                                        
            
            // منطق الـ JS: لو رقم الدليفري المتسجل هو نفسه رقم حساب التاجر الأصلي، نتركه فارغاً
            _deliveryPhone = (_settings!.deliveryContactPhone == _currentDealerOriginalPhone) ? '' : _settings!.deliveryContactPhone;                                                                       
            
            _deliveryFee = _settings!.deliveryFee.toStringAsFixed(2);                           
            _minimumOrderValue = _settings!.minimumOrderValue.toStringAsFixed(2);                                                                           
            _descriptionForDelivery = _settings!.descriptionForDelivery;
                                                                                                        
        } else {                                            
            // إذا لم يتم العثور على مستند الدليفري                                                         
            _settings = DeliverySettingsModel(ownerId: _currentDealerId); // إنشاء نموذج فارغ               
            _deliveryActive = false;                    
        }
                                                    
    } catch (e) {                                       
        // إذا ظهرت رسالة الخطأ الحمراء، فهذا هو مصدرها الوحيد المتبقي (مشاكل تحويل أو شبكة)
        showNotification('حدث خطأ أثناء تحميل إعدادات الدليفري.', false);                                                                               
        debugPrint('Error loading delivery data: $e'); // يجب مراجعة هذا السجل
    }                                                                                               
    setIsLoading(false);                          
  }
  
  // ------------------------------------       
  // وظائف الإرسال (Submit)                       
  // ------------------------------------         
  Future<void> submitSettings({                                                                     
    required String hours,
    required String whatsapp,                                                                       
    required String phone,
    required String fee,
    required String minOrder,                   
    required String description,
  }) async {                                    
    setIsLoading(true);                             
    clearNotification();
                                                                                                    
    if (_dealerProfile?.location == null) {           
      showNotification('موقع السوبر ماركت غير متوفر. لا يمكن الحفظ.', false);
      setIsLoading(false);                            
      return;                                                                                       
    }
                                                    
    if (_currentDealerId.isEmpty) {
        showNotification('هوية التاجر مفقودة.', false);
        setIsLoading(false);                            
        return;
    }
                                                    
    try {
        final double parsedFee = double.tryParse(fee) ?? 0.0;
        final double parsedMinOrder = double.tryParse(minOrder) ?? 0.0;                         
        
        // منطق تحديد رقم الهاتف للتواصل
        final contactPhone = phone.isEmpty ? _currentDealerOriginalPhone : phone;               
                                                        
        final DeliverySettingsModel dataToSave = DeliverySettingsModel(
            ownerId: _currentDealerId,
            supermarketName: _dealerProfile!.name,                                                                                                          
            address: _dealerProfile!.address,
            location: _dealerProfile!.location,
            // الحقول القابلة للتحديث           
            deliveryActive: _deliveryActive,
            deliveryHours: hours,
            whatsappNumber: whatsapp,                                                                       
            deliveryContactPhone: contactPhone,             
            deliveryFee: parsedFee,
            minimumOrderValue: parsedMinOrder,
            descriptionForDelivery: description,        
        );                                                                                              
        
        final deliveryDocRef = _firestore.collection(DELIVERY_COLLECTION).doc(_currentDealerId);
                                                
        if (!_deliveryActive) {                             
            // حالة: إيقاف الدليفري
            await deliveryDocRef.update({                       
                'deliveryActive': false,
                'lastUpdated': FieldValue.serverTimestamp()                                                 
            });                                             
            showNotification('تم إيقاف خدمة الدليفري بنجاح.', true);                                    
        } else {                                            
            // حالة: حفظ التعديلات وتفعيل الدليفري - (مطابق لـ JS set with merge: true)                                                          
            await deliveryDocRef.set(dataToSave.toFirestore(), SetOptions(merge: true));        
            showNotification('تم حفظ وتحديث إعدادات الدليفري بنجاح!', true);                                                                            
        }
                                                        
        // إعادة تحميل البيانات لتعكس التغييرات في الواجهة                                              
        await loadDeliveryData();

    } catch (e) {                               
        showNotification('حدث خطأ أثناء حفظ التعديلات. يرجى المحاولة لاحقاً.', false);                   
        debugPrint('Error submitting delivery settings: $e');
    }
                                                    
    setIsLoading(false);                          
  }                                             
}
