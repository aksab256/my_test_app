// lib/screens/consumer/consumer_store_search_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng, Distance;
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';
import 'package:my_test_app/screens/consumer/MarketplaceHomeScreen.dart';
import 'package:my_test_app/screens/special_requests/location_picker_screen.dart';

class ConsumerStoreSearchScreen extends StatefulWidget {
  static const routeName = '/consumerStoreSearch';
  const ConsumerStoreSearchScreen({super.key});

  @override
  State<ConsumerStoreSearchScreen> createState() => _ConsumerStoreSearchScreenState();
}

class _ConsumerStoreSearchScreenState extends State<ConsumerStoreSearchScreen> {
  LatLng? _currentSearchLocation;
  bool _isLoading = false;
  String _loadingMessage = 'جاري المسح الجغرافي...';
  List<Map<String, dynamic>> _nearbySupermarkets = [];
  List<Marker> _mapMarkers = [];
  final MapController _mapController = MapController();
  final double _searchRadiusKm = 5.0;
  final Distance distance = const Distance();

  // 🎨 الألوان الهادئة المعتمدة
  final Color brandGreen = const Color(0xFF66BB6A); 
  final Color darkText = const Color(0xFF212121);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptLocationSelection());
  }

  // ... (دوال Logic الموقع تظل كما هي لسلامة الوظيفة) ...

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.white.withOpacity(0.95),
          elevation: 2,
          toolbarHeight: 70,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: brandGreen, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'رادار المحلات', 
            style: TextStyle(fontWeight: FontWeight.w900, color: darkText, fontSize: 20), // 🎯 خط كبير وواضح
          ),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentSearchLocation ?? const LatLng(31.2001, 29.9187),
                initialZoom: 14.0,
              ),
              children: [
                TileLayer(urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png'),
                MarkerLayer(markers: _mapMarkers),
              ],
            ),

            // 📍 شريط معلومات الرادار العلوي
            Positioned(
              top: 110,
              left: 15,
              right: 15,
              child: _buildModernRadarHeader(),
            ),

            // 🛒 قائمة المتاجر السفلية بخطوط عريضة
            Positioned(bottom: 0, left: 0, right: 0, child: _buildStoresPreviewArea()),

            if (_isLoading) _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildModernRadarHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          Icon(Icons.radar, color: brandGreen, size: 32),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "نطاق البحث الذكي",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: darkText), // 🎯 حجم 19
                ),
                Text(
                  "دائرة قطرها $_searchRadiusKm كم",
                  style: TextStyle(fontSize: 15, color: Colors.grey[600], fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _promptLocationSelection,
            icon: Icon(Icons.my_location, color: brandGreen, size: 30),
          )
        ],
      ),
    );
  }

  Widget _buildStoresPreviewArea() {
    if (_nearbySupermarkets.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 200,
      margin: const EdgeInsets.only(bottom: 25),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: _nearbySupermarkets.length,
        itemBuilder: (context, index) {
          final store = _nearbySupermarkets[index];
          return Container(
            width: MediaQuery.of(context).size.width * 0.85,
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
            ),
            child: InkWell(
              onTap: () => _showStoreDetails(store),
              borderRadius: BorderRadius.circular(30),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 70, height: 70,
                      decoration: BoxDecoration(color: brandGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                      child: Icon(Icons.storefront, color: brandGreen, size: 35),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            store['supermarketName'] ?? 'متجر غير معروف',
                            maxLines: 1,
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: darkText), // 🎯 حجم 19
                          ),
                          const SizedBox(height: 5),
                          Text(
                            "يبعد ${store['distance']} كم عنك",
                            style: TextStyle(color: brandGreen, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, color: brandGreen, size: 22),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.white.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: brandGreen, strokeWidth: 4),
            const SizedBox(height: 25),
            Text(
              _loadingMessage, 
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: brandGreen), // 🎯 حجم 19
            ),
          ],
        ),
      ),
    );
  }

  // --- بقية الدوال المساعدة مع تحسين حجم خط الـ BottomSheet ---
  void _showStoreDetails(Map<String, dynamic> store) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(30),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(store['supermarketName'], style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), // 🎯 حجم كبير جداً للعنوان
            const SizedBox(height: 15),
            Text(store['address'] ?? "العنوان متاح داخل المتجر", 
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 65,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, MarketplaceHomeScreen.routeName, arguments: {
                    'storeId': store['id'], 'storeName': store['supermarketName']
                  });
                },
                child: const Text("دخول المتجر الآن", 
                  style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)), // 🎯 حجم 19
              ),
            )
          ],
        ),
      ),
    );
  }
  
  // دالة اختيار الموقع (Sheet)
  Widget _buildLocationSelectionSheet(bool hasRegistered) {
    return Container(
      padding: const EdgeInsets.fromLTRB(25, 20, 25, 40),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(35))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 25),
          const Text("حدد موقع البحث", style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 25),
          _buildOptionTile(Icons.my_location, "موقعي الحالي", "بحث عبر الـ GPS", () => Navigator.pop(context, 'current')),
          if (hasRegistered) ...[
            const SizedBox(height: 15),
            _buildOptionTile(Icons.home, "عنواني المسجل", "استخدام موقعك المحفوظ", () => Navigator.pop(context, 'registered')),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionTile(IconData icon, String title, String sub, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: brandGreen, size: 30),
      title: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey[200]!)),
    );
  }
  
  // (دوال الأيقونات تظل كما هي)
  Widget _buildUserLocationMarker() => Icon(Icons.person_pin_circle, color: Colors.blue[800], size: 45);
  Widget _buildStoreMarker(Map<String, dynamic> store) => Icon(Icons.location_on, color: brandGreen, size: 40);
}

