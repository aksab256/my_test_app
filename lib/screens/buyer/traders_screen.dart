// المسار: lib/screens/buyer/traders_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

// استيراد الـ Widgets الخاصة بك
import '../../widgets/traders_header_widget.dart';
import '../../widgets/traders_list_widget.dart';
import '../../widgets/traders_filter_widget.dart';
import '../../widgets/chat_support_widget.dart';

// --- مساعدات منطق الجغرافيا (Coordinates) ---
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

// 🎯 أولاً: الـ Widget الخاص بالمحتوى فقط (بدون Scaffold)
// نستخدمه داخل الشاشة الرئيسية لمنع تكرار الـ AppBar والـ BottomNav
class TradersContent extends StatefulWidget {
  final bool showHeader; 
  const TradersContent({super.key, this.showHeader = true});

  @override
  State<TradersContent> createState() => _TradersContentState();
}

class _TradersContentState extends State<TradersContent> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String _searchQuery = '';
  String _currentFilter = 'all';
  List<DocumentSnapshot> _activeSellers = [];
  List<DocumentSnapshot> _filteredTraders = [];
  List<String> _categories = [];
  bool _isLoading = true;
  
  Coordinates? _userCoordinates;
  Map<String, List<Coordinates>> _areaCoordinatesMap = {};

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    await _fetchAndProcessGeoJson();
    _userCoordinates = await _getUserLocation();
    await _loadTraders();
    if (mounted) setState(() => _isLoading = false);
  }

  // تحميل بيانات المناطق الجغرافية
  Future<void> _fetchAndProcessGeoJson() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/OSMB-bc319d822a17aa9ad1089fc05e7d4e752460f877.geojson');
      final data = json.decode(jsonString);
      if (data['features'] != null) {
        for (var feature in data['features']) {
          final name = feature['properties']['name'];
          final geometry = feature['geometry'];
          if (name != null && geometry != null) {
            List coordsRaw = (geometry['type'] == 'Polygon') ? geometry['coordinates'][0] : geometry['coordinates'][0][0];
            _areaCoordinatesMap[name] = coordsRaw.map<Coordinates>((c) => Coordinates(lat: c[1].toDouble(), lng: c[0].toDouble())).toList();
          }
        }
      }
    } catch (e) { debugPrint("GeoJSON Error: $e"); }
  }

  Future<Coordinates?> _getUserLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('loggedUser');
    if (userJson == null) return null;
    final user = json.decode(userJson);
    final loc = user['location'];
    if (loc != null) return Coordinates(lat: loc['lat']?.toDouble(), lng: loc['lng']?.toDouble());
    return null;
  }

  Future<void> _loadTraders() async {
    try {
      // 💡 استخدام اسم الكولكشن الصحيح من إعداداتك: deliverySupermarkets
      final snapshot = await _db.collection("deliverySupermarkets").get();
      List<DocumentSnapshot> serving = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final List? areas = data['deliveryAreas'] as List?;
        
        if (_userCoordinates == null || areas == null || areas.isEmpty) {
          serving.add(doc);
          continue;
        }

        bool match = areas.any((areaName) {
          final polygon = _areaCoordinatesMap[areaName];
          return (polygon != null) ? isPointInPolygon(_userCoordinates!, polygon) : false;
        });

        if (match) serving.add(doc);
      }

      _activeSellers = serving;
      _categories = _activeSellers.map((e) => (e.data() as Map)['businessType']?.toString() ?? "أخرى").toSet().toList()..sort();
      _applyFilters();
    } catch (e) { debugPrint("Load Traders Error: $e"); }
  }

  void _applyFilters() {
    setState(() {
      _filteredTraders = _activeSellers.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        // 💡 استخدام supermarketName حسب إعداداتك
        final name = (data['supermarketName'] ?? data['merchantName'] ?? '').toString().toLowerCase();
        final type = data['businessType']?.toString() ?? 'أخرى';
        return name.contains(_searchQuery.toLowerCase()) && (_currentFilter == 'all' || type == _currentFilter);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)));

    return Column(
      children: [
        if (widget.showHeader)
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
    );
  }
}

// 🎯 ثانياً: الشاشة الكاملة (التي يتم استدعاؤها من الـ Routes)
class TradersScreen extends StatelessWidget {
  static const String routeName = '/traders';
  const TradersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFf5f7fa),
        // شريط علوي أخضر واحد بدون أيقونة الوضع الليلي
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFF4CAF50),
          centerTitle: true,
          title: const Text('التجار والسوبر ماركت', 
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
        ),
        // استخدام الـ Content هنا
        body: const TradersContent(showHeader: true),
        
        // المساعد الذكي كأيقونة عائمة واحدة
        floatingActionButton: FloatingActionButton(
          heroTag: "traders_page_chat",
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
      ),
    );
  }
}
