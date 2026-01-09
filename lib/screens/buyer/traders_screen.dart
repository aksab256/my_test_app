// المسار: lib/screens/buyer/traders_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

// استيراد الـ Widgets الفرعية
import '../../widgets/traders_header_widget.dart';
import '../../widgets/traders_list_widget.dart';
import '../../widgets/traders_filter_widget.dart';
import '../../widgets/chat_support_widget.dart';
// 🚀 استيراد الشريط السفلي لضمان ظهوره
import '../../widgets/buyer_mobile_nav_widget.dart';

final FirebaseFirestore _db = FirebaseFirestore.instance;

class Coordinates {
  final double lat;
  final double lng;
  Coordinates({required this.lat, required this.lng});
}

bool isPointInPolygon(Coordinates point, List<Coordinates> polygon) {
  final x = point.lng;
  final y = point.lat;
  bool inside = false;
  if (polygon.length < 3) return false;
  for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final xi = polygon[i].lng;
    final yi = polygon[i].lat;
    final xj = polygon[j].lng;
    final yj = polygon[j].lat;
    final intersect = ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi);
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
  String _searchQuery = '';
  String _currentFilter = 'all';
  List<DocumentSnapshot> _activeSellers = [];
  List<DocumentSnapshot> _filteredTraders = [];
  List<String> _categories = [];
  
  Coordinates? _userCoordinates;
  Map<String, List<Coordinates>> _areaCoordinatesMap = {};

  bool _isLoading = true;
  String _loadingMessage = 'جاري تحميل التجار...';
  int _cartCount = 0; // لعداد السلة في الشريط السفلي

  @override
  void initState() {
    super.initState();
    _loadTradersAndFilter();
    _loadCartCount();
  }

  // تحميل عدد عناصر السلة للشريط السفلي
  Future<void> _loadCartCount() async {
    final prefs = await SharedPreferences.getInstance();
    String? cartData = prefs.getString('cart_items');
    if (cartData != null) {
      List<dynamic> items = jsonDecode(cartData);
      if (mounted) setState(() => _cartCount = items.length);
    }
  }

  // --- منطق الجغرافيا (كما هو لضمان الفلترة) ---
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
              map[areaName] = polygonCoords.map<Coordinates>((coord) {
                return Coordinates(lat: coord[1].toDouble(), lng: coord[0].toDouble());
              }).toList();
            }
          }
        }
      }
      _areaCoordinatesMap = map;
      return true;
    } catch (e) { return false; }
  }

  Future<Coordinates?> _getBuyerCoordinates() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('loggedUser');
    if (userJson == null) return null;
    try {
      final user = json.decode(userJson);
      final loc = user['location'];
      if (loc == null) return null;
      double? lat = loc['lat']?.toDouble() ?? loc['latitude']?.toDouble();
      double? lng = loc['lng']?.toDouble() ?? loc['longitude']?.toDouble();
      if (lat != null && lng != null) return Coordinates(lat: lat, lng: lng);
    } catch (e) { return null; }
    return null;
  }

  Future<void> _loadTradersAndFilter() async {
    setState(() { _isLoading = true; });
    _userCoordinates = await _getBuyerCoordinates();
    final isBuyerLocationKnown = _userCoordinates != null;
    await _fetchAndProcessAdministrativeAreas();
    
    try {
      final snapshot = await _db.collection("sellers").where("status", isEqualTo: "active").get();
      final List<DocumentSnapshot> sellersServingArea = [];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final List<dynamic>? deliveryAreas = data['deliveryAreas'] as List<dynamic>?;
        final bool hasDeliveryAreas = deliveryAreas != null && deliveryAreas.isNotEmpty;

        if (!isBuyerLocationKnown || !hasDeliveryAreas) {
          sellersServingArea.add(doc);
          continue;
        }
        
        final isAreaMatch = deliveryAreas.any((areaName) {
          final areaPolygon = _areaCoordinatesMap[areaName.toString()];
          if (areaPolygon != null && areaPolygon.length >= 3) {
            return isPointInPolygon(_userCoordinates!, areaPolygon);
          }
          return false;
        });
        if (isAreaMatch) sellersServingArea.add(doc);
      }
      _activeSellers = sellersServingArea;
      _categories = _getUniqueCategories(_activeSellers);
      _applyFilters(); 
      if (mounted) setState(() => _isLoading = false);
    } catch (e) { if (mounted) setState(() => _isLoading = false); }
  }

  List<String> _getUniqueCategories(List<DocumentSnapshot> sData) {
    final categories = <String>{};
    for (final doc in sData) {
      final data = doc.data() as Map<String, dynamic>;
      final bType = data['businessType']?.toString().trim() ?? "أخرى";
      categories.add(bType.isNotEmpty ? bType : "أخرى");
    }
    return categories.toList()..sort();
  }

  void _applyFilters() {
    setState(() {
      _filteredTraders = _activeSellers.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = data['merchantName']?.toString().toLowerCase() ?? '';
        final type = data['businessType']?.toString() ?? 'أخرى';
        return name.contains(_searchQuery.toLowerCase()) && (_currentFilter == 'all' || type == _currentFilter);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFf5f7fa),
        // ✅ شريط علوي أخضر واحد بدون أيقونة الوضع الليلي
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFF4CAF50),
          centerTitle: true,
          title: const Text('التجار والسوبر ماركت', 
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
            : Column(
                children: [
                  TradersHeaderWidget(
                    onSearch: (val) { _searchQuery = val; _applyFilters(); },
                    currentQuery: _searchQuery,
                  ),
                  TradersFilterWidget(
                    categories: _categories,
                    currentFilter: _currentFilter,
                    onFilterSelected: (val) { _currentFilter = val; _applyFilters(); },
                  ),
                  Expanded(
                    child: TradersListWidget(
                      traders: _filteredTraders,
                      onTraderTap: (doc) => Navigator.of(context).pushNamed('/traderOffers', arguments: doc.id),
                    ),
                  ),
                ],
              ),

        // 🚀 إعادة المساعد الذكي كزر عائم (Floating)
        floatingActionButton: FloatingActionButton(
          heroTag: "traders_fab_chat",
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const ChatSupportWidget(),
            );
          },
          backgroundColor: const Color(0xFF4CAF50),
          child: const Icon(Icons.support_agent, color: Colors.white, size: 30),
        ),

        // 🚀 إعادة الشريط السفلي الأساسي للتطبيق
        bottomNavigationBar: BuyerMobileNavWidget(
          selectedIndex: 0, // تحديد التاجر كقسم نشط
          onItemSelected: (index) {
             if (index == 1) Navigator.of(context).pushReplacementNamed('/buyerHome');
             // أضف باقي التنقلات هنا حسب الحاجة
          },
          cartCount: _cartCount,
          ordersChanged: false,
        ),
      ),
    );
  }
}
