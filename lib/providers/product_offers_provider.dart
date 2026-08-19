import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/utils/offer_data_model.dart'; 

class ProductOffersProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final String productId; 
  // 🎯 قائمة المناطق المكتشفة للمشتري بناءً على الـ GPS والـ GeoJSON
  final List<String> userDetectedAreas;

  // 💡 المُنشئ لاستقبال المنتج والمناطق المكتشفة
  ProductOffersProvider({
    required this.productId, 
    required this.userDetectedAreas,
  }) {
    // جلب العروض فور إنشاء البروفايدر
    fetchOffers(productId, userDetectedAreas);
  }

  List<OfferModel> _availableOffers = [];
  OfferModel? _selectedOffer;                      
  bool _isLoading = true;                          
  int _currentQuantity = 0;
                                                   
  List<OfferModel> get availableOffers => _availableOffers;                                       
  OfferModel? get selectedOffer => _selectedOffer;                                                
  bool get isLoading => _isLoading;                
  int get currentQuantity => _currentQuantity;                                                                                                                                   
  
  // 💥 دالة جلب العروض والفلترة الجغرافية المطابقة لبيانات Firestore
  Future<void> fetchOffers(String productId, List<String> detectedAreas) async {
    _isLoading = true;                              
    _availableOffers = [];                          
    _selectedOffer = null;
    notifyListeners(); 

    try {                                             
      // 1. جلب العروض النشطة الخاصة بالمنتج من مجموعة productOffers
      final offersQuery = _db.collection('productOffers')
        .where('productId', isEqualTo: productId)                                                                
        .where('status', isEqualTo: 'active');
                                                      
      final offersSnap = await offersQuery.get();                                                              
      List<OfferModel> filteredOffers = [];
                                                      
      for (var doc in offersSnap.docs) {
        // تحويل المستند لنموذج OfferModel
        List<OfferModel> offersFromDoc = OfferModel.fromFirestore(doc);

        for (var offer in offersFromDoc) {
          // 🎯 منطق الفلترة الجغرافي بناءً على حقل deliveryZones المطابق لـ Firestore:
          // 1. حالة الـ Global: إذا كانت مناطق التوصيل فارغة أو غير محددة (العرض متاح للجميع)
          bool isGlobal = offer.deliveryZones == null || offer.deliveryZones!.isEmpty;
          
          // 2. حالة المطابقة: إذا كانت إحداثيات المشتري تقع ضمن مناطق التوصيل
          bool isAreaMatch = offer.deliveryZones?.any((zone) => 
            detectedAreas.contains(zone)) ?? false;

          if (isGlobal || isAreaMatch) {
            filteredOffers.add(offer);
          }
        }
      }                                         

      // 2. تحديث قائمة العروض المتاحة
      _availableOffers = filteredOffers;             
      
      if (_availableOffers.isNotEmpty) {
        _selectedOffer = _availableOffers.first;                
        _currentQuantity = _selectedOffer!.stock >= (_selectedOffer!.minQty ?? 1)                             
          ? (_selectedOffer!.minQty ?? 1)
          : 0;
      } else {                                          
        _currentQuantity = 0;
      }
                                                      
      _isLoading = false;                              
      notifyListeners(); 
    } catch (e) {
      _isLoading = false;
      _availableOffers = [];                          
      _selectedOffer = null;                          
      _currentQuantity = 0;
      if (kDebugMode) {
        print('Error fetching and filtering offers: $e');
      }
      notifyListeners(); 
    }
  }
                                                
  void selectOffer(OfferModel offer) {
    _selectedOffer = offer;                         
    _currentQuantity = offer.stock >= (offer.minQty ?? 1)                                                 
      ? (offer.minQty ?? 1)
      : 0;
    notifyListeners();
  }

  void updateQuantity(int newQty) {
    _currentQuantity = newQty;                      
    notifyListeners();
  }
}