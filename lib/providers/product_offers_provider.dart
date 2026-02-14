import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/utils/offer_data_model.dart'; 

class ProductOffersProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final String productId; 
  // 🎯 إضافة قائمة المناطق المكتشفة للمشتري بناءً على الـ GPS والـ GeoJSON
  final List<String> userDetectedAreas;

  // 💡 تحديث المُنشئ لاستقبال المنتج والمناطق المكتشفة
  ProductOffersProvider({
    required this.productId, 
    required this.userDetectedAreas,
  }) {
    // جلب العروض مع تمرير المناطق لفلترتها
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
  
  // 💥 دالة جلب العروض مع منطق الفلترة الجغرافية
  Future<void> fetchOffers(String productId, List<String> detectedAreas) async {
    _isLoading = true;                              
    _availableOffers = [];                          
    _selectedOffer = null;
    notifyListeners(); 

    try {                                             
      // 1. جلب كل العروض النشطة للمنتج من Firestore
      final offersQuery = _db.collection('productOffers')
        .where('productId', isEqualTo: productId)                                                       
        .where('status', isEqualTo: 'active');
                                                      
      final offersSnap = await offersQuery.get();                                                     
      List<OfferModel> filteredOffers = [];
                                                      
      for (var doc in offersSnap.docs) {
        // نستخدم الوظيفة الحالية لتحويل البيانات لنموذج OfferModel
        List<OfferModel> offersFromDoc = OfferModel.fromFirestore(doc);

        for (var offer in offersFromDoc) {
          // 🎯 منطق الفلترة الجغرافي (مطابق لكود الـ HTML الخاص بك):
          // الحالة أ: التاجر لم يحدد مناطق (العرض متاح للجميع)
          // الحالة ب: إحداثيات المشتري تقع ضمن إحدى المناطق التي يغطيها التاجر
          
          bool isGlobal = offer.deliveryAreas == null || offer.deliveryAreas!.isEmpty;
          
          bool isAreaMatch = offer.deliveryAreas?.any((area) => 
            detectedAreas.contains(area)) ?? false;

          if (isGlobal || isAreaMatch) {
            filteredOffers.add(offer);
          }
        }
      }                                         

      // 2. تحديث الحالة بالعروض المفلترة فقط
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
