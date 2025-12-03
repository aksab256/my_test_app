// المسار: lib/screens/buyer/traders_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle; // لاستيراد GeoJSON

// استيراد الـ Widgets الفرعية
import '../../widgets/traders_header_widget.dart';
import '../../widgets/traders_list_widget.dart';
import '../../widgets/traders_filter_widget.dart';

// تعريفات Firebase
final FirebaseFirestore _db = FirebaseFirestore.instance;

// 💡 تعريف GeoPoint أو نقطة (بسبب عدم وجود GeoPoint في Flutter مباشرة)
class Coordinates {
  final double lat;
  final double lng;
  Coordinates({required this.lat, required this.lng});

  @override
  String toString() => '($lat, $lng)';
}

// ----------------------------------------------------------------------
// 🔥 LOGIC: POINT IN POLYGON (تم تحويله من كود JS)
// ----------------------------------------------------------------------

bool isPointInPolygon(Coordinates point, List<Coordinates> polygon) {
  final x = point.lng;
  final y = point.lat;
  bool inside = false;

  if (polygon.length < 3) {
    return false;
  }

  for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final xi = polygon[i].lng;
    final yi = polygon[i].lat;
    final xj = polygon[j].lng;
    final yj = polygon[j].lat;

    final intersect = ((yi > y) != (yj > y)) &&
        (x < (xj - xi) * (y - yi) / (yj - yi) + xi);
    if (intersect) inside = !inside;
  }
  return inside;
}

class TradersScreen extends StatefulWidget {
  static const String routeName = '/traders';
  const TradersScreen({super.key});

  @override
  State<TradersScreen> createState() => _TradersScreenState();
}

class _TradersScreenState extends State<TradersScreen> {
  // --- متغيرات الحالة والبيانات ---
  String _searchQuery = '';
  String _currentFilter = 'all';
  List<DocumentSnapshot> _activeSellers = []; // جميع التجار الذين يخدمون المنطقة
  List<DocumentSnapshot> _filteredTraders = []; // القائمة المعروضة بعد البحث والفلترة
  List<String> _categories = []; // أنواع الأنشطة الفريدة
  
  // بيانات جغرافية
  Coordinates? _userCoordinates;
  Map<String, List<Coordinates>> _areaCoordinatesMap = {};

  bool _isLoading = true;
  String _loadingMessage = 'جاري تحميل المناطق والتجار...';
  
  // ----------------------------------------------------------------------
  // 🔥 FUNCTION: FETCH GEOJSON (تم تحويله من كود JS)
  // ----------------------------------------------------------------------
  Future<bool> _fetchAndProcessAdministrativeAreas() async {
    const String geoJsonFilePath = 'assets/OSMB-bc319d822a17aa9ad1089fc05e7d4e752460f877.geojson';
    try {
      final String jsonString = await rootBundle.loadString(geoJsonFilePath);
      final geoJsonData = json.decode(jsonString);

      final Map<String, List<Coordinates>> map = {};
      
      if (geoJsonData['features'] is List) {
        for (final feature in geoJsonData['features']) {
          final properties = feature['properties'];
          final geometry = feature['geometry'];
          final areaName = properties?['name'];
          final coordinates = geometry?['coordinates'];

          if (areaName != null && coordinates != null) {
            List<dynamic> polygonCoords = [];

            if (geometry['type'] == 'MultiPolygon' && coordinates.isNotEmpty) {
              polygonCoords = coordinates[0][0] ?? [];
            } else if (geometry['type'] == 'Polygon') {
              polygonCoords = coordinates[0] ?? [];
            }
            
            if (polygonCoords.length >= 3) {
              // تحويل [lng, lat] إلى {lat, lng}
              map[areaName] = polygonCoords.map<Coordinates>((coord) {
                return Coordinates(lat: coord[1].toDouble(), lng: coord[0].toDouble());
              }).toList();
            }
          }
        }
      }
      
      _areaCoordinatesMap = map;
      print('✅ تم تحميل ${_areaCoordinatesMap.length} منطقة بنجاح من GeoJSON.');
      return true;
    } catch (error) {
      print('❌ فشل تحميل أو معالجة ملف GeoJSON: $error');
      return false;
    }
  }


  // ----------------------------------------------------------------------
  // 🔥 FUNCTION: INITIALIZATION (يجمع كل المنطق)
  // ----------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _loadTradersAndFilter();
  }

  // 1. جلب إحداثيات المشترى
  Future<Coordinates?> _getBuyerCoordinates() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('loggedUser');
    if (userJson == null) return null;

    try {
      final user = json.decode(userJson);
      final loc = user['location'];
      if (loc == null) return null;

      double? lat;
      double? lng;

      if (loc['lat'] is num) {
        lat = loc['lat'].toDouble();
      } else if (loc['latitude'] is num) {
        lat = loc['latitude'].toDouble();
      }

      if (loc['lng'] is num) {
        lng = loc['lng'].toDouble();
      } else if (loc['longitude'] is num) {
        lng = loc['longitude'].toDouble();
      }

      if (lat != null && lng != null) {
        return Coordinates(lat: lat, lng: lng);
      }
    } catch (e) {
      print('Error parsing user location: $e');
    }
    return null;
  }

  // 2. تطبيق منطق التحميل والتصفية الرئيسي
  Future<void> _loadTradersAndFilter() async {
    setState(() { _isLoading = true; _loadingMessage = 'جاري تحميل المناطق والتجار...'; });
    
    _userCoordinates = await _getBuyerCoordinates();
    final isBuyerLocationKnown = _userCoordinates != null;

    if (!isBuyerLocationKnown) {
        print("إحداثيات المشترى (المستهلك) غير متوفرة. سيتم عرض التجار ذوي التوصيل الشامل فقط.");
    }

    final isAreasLoaded = await _fetchAndProcessAdministrativeAreas();

    if (!isAreasLoaded) {
      setState(() {
        _loadingMessage = 'لا يمكن عرض التجار حالياً لعدم توفر بيانات المناطق.';
        _isLoading = false;
      });
      return;
    }
    
    try {
      final sellersCollectionRef = _db.collection("sellers");
      final q = sellersCollectionRef.where("status", isEqualTo: "active");
      final snapshot = await q.get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _loadingMessage = 'لا يوجد تجار معتمدون حاليًا.';
          _isLoading = false;
        });
        return;
      }

      final List<DocumentSnapshot> sellersServingArea = [];

      // 3. منطق التصفية الجغرافية (نفس منطق JavaScript)
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final List<dynamic>? deliveryAreas = data['deliveryAreas'] as List<dynamic>?;
        
        final bool hasDeliveryAreas = deliveryAreas != null && deliveryAreas.isNotEmpty;

        // الحالة 1: موقع المشتري غير معروف (عرض الشامل فقط)
        if (!isBuyerLocationKnown) {
          if (!hasDeliveryAreas) {
            sellersServingArea.add(doc); // توصيل شامل
          }
          continue; // لا حاجة للتحقق من المناطق
        }
        
        // الحالة 2: موقع المشتري معروف
        
        // 2.1 التاجر يوصل توصيل شامل
        if (!hasDeliveryAreas) {
          sellersServingArea.add(doc);
          continue;
        }
        
        // 2.2 التاجر لديه مناطق توصيل محددة (مصفوفة نصية)
        if (hasDeliveryAreas) {
          final isAreaMatch = deliveryAreas.any((areaName) {
            final areaPolygon = _areaCoordinatesMap[areaName.toString()];

            if (areaPolygon != null && areaPolygon.length >= 3) {
              // تطبيق المطابقة الجغرافية (نقطة المشترى داخل المضلع)
              return isPointInPolygon(_userCoordinates!, areaPolygon);
            }
            return false;
          });

          if (isAreaMatch) {
            sellersServingArea.add(doc);
            continue;
          }
        }
      }

      _activeSellers = sellersServingArea;
      
      if (_activeSellers.isEmpty) {
        setState(() {
          _loadingMessage = 'عفواً، لا يوجد تجار معتمدون يخدمون منطقة التوصيل الخاصة بك حالياً.';
          _isLoading = false;
        });
        return;
      }
      
      // تحديث الفلاتر والقائمة المعروضة
      _categories = _getUniqueCategories(_activeSellers);
      _applyFilters(); 
      
      setState(() {
        _isLoading = false;
      });

    } catch (error) {
      print("خطأ أثناء تحميل التجار: $error");
      setState(() {
        _loadingMessage = 'حدث خطأ أثناء تحميل التجار. يرجى المحاولة لاحقًا.';
        _isLoading = false;
      });
    }
  }

  // ----------------------------------------------------------------------
  // 4. منطق الفلترة والبحث (مماثل لكود JS)
  // ----------------------------------------------------------------------
  
  List<String> _getUniqueCategories(List<DocumentSnapshot> sData) {
    final categories = <String>{};
    for (final doc in sData) {
      final data = doc.data() as Map<String, dynamic>;
      final businessType = data['businessType'];
      if (businessType != null && businessType is String && businessType.trim().isNotEmpty) {
        categories.add(businessType.trim());
      } else {
        categories.add("أخرى");
      }
    }
    final list = categories.toList();
    list.sort();
    return list;
  }

  void _updateSearchQuery(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _updateFilter(String filter) {
    setState(() {
      _currentFilter = filter;
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<DocumentSnapshot> results = _activeSellers.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final merchantName = data['merchantName']?.toString() ?? '';
      final businessType = data['businessType']?.toString() ?? 'أخرى';

      // 1. تطبيق البحث
      final matchesSearch = merchantName
          .toLowerCase()
          .contains(_searchQuery.toLowerCase());

      // 2. تطبيق الفلتر
      final matchesFilter = _currentFilter == 'all' || businessType == _currentFilter;

      return matchesSearch && matchesFilter;
    }).toList();

    setState(() {
      _filteredTraders = results;
    });
  }

  // ----------------------------------------------------------------------
  // 5. البناء (Build)
  // ----------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFf5f7fa),
        appBar: AppBar(
          automaticallyImplyLeading: false, // لا يوجد زر رجوع افتراضي
          title: const Text('التجار والسوبر ماركت', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF2c3e50),
          // محاكاة لـ Top Header HTML (مدمجة في AppBar)
          actions: [
            // محاكاة لـ Theme Toggle
            IconButton(
              icon: const Icon(Icons.brightness_2_rounded, color: Colors.white),
              onPressed: () {
                // منطق تغيير الثيم
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم محاكاة تبديل الثيم.')),
                );
              },
            ),
          ],
        ),
        body: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF4CAF50)),
                    const SizedBox(height: 15),
                    Text(_loadingMessage, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                  ],
                ),
              )
            : Column(
                children: <Widget>[
                  // 1. شريط البحث
                  TradersHeaderWidget(
                    onSearch: _updateSearchQuery,
                    currentQuery: _searchQuery,
                  ),
                  
                  // 2. شريط الفلاتر
                  TradersFilterWidget(
                    categories: _categories,
                    currentFilter: _currentFilter,
                    onFilterSelected: _updateFilter,
                  ),
                  
                  // 3. قائمة النتائج
                  Expanded(
                    child: TradersListWidget(
                      traders: _filteredTraders,
                      onTraderTap: (doc) {
                         // توجيه لصفحة العروض، تماماً مثل card.href في HTML
                        final sellerId = doc.id;
                        Navigator.of(context).pushNamed('/traderOffers', arguments: sellerId);
                      },
                    ),
                  ),
                ],
              ),
        
        // 4. محاكاة Bottom Navigation Bar (لأن الصفحة لا تظهر شريط التنقل السفلي في الكود القديم)
        bottomNavigationBar: const BottomAppBar(
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // ... أيقونات الشريط السفلي ...
            ],
          ),
        ),
      ),
    );
  }
}
