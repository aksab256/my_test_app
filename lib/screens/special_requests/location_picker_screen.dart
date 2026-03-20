// lib/screens/location_picker_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/bubble_service.dart';
import '../../services/delivery_service.dart';
import 'dart:math';
import 'package:sizer/sizer.dart'; // ✅ إضافة المكتبة المفقودة لحل مشكلة الـ .sp

enum PickerStep { pickup, dropoff, confirm }

class LocationPickerScreen extends StatefulWidget {
  static const routeName = '/location-picker';
  final LatLng? initialLocation;
  final String title;

  const LocationPickerScreen({super.key, this.initialLocation, this.title = "تحديد الموقع"});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  final DeliveryService _deliveryService = DeliveryService();
  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  final String mapboxToken = "pk.eyJ1IjoiYW1yc2hpcGwiLCJhIjoiY21lajRweGdjMDB0eDJsczdiemdzdXV6biJ9.E--si9vOB93NGcAq7uVgGw";

  PickerStep _currentStep = PickerStep.pickup;
  late LatLng _currentMapCenter;
  LatLng? _pickupLocation;
  String _pickupAddress = "جاري جلب العنوان...";
  LatLng? _dropoffLocation;
  String _dropoffAddress = "";
  double _estimatedPrice = 0.0;

  Map<String, double> _pricingDetails = {
    'totalPrice': 0.0,
    'commissionAmount': 0.0,
    'driverNet': 0.0
  };

  String _tempAddress = "جاري تحديد موقعك الحالي...";
  bool _isLoading = false;
  bool _isSearching = false;
  bool _isSatelliteMode = true; 
  List _searchResults = [];
  String _selectedVehicle = "motorcycle";

  final List<Map<String, dynamic>> _vehicles = [
    {"id": "motorcycle", "name": "موتوسيكل", "icon": Icons.directions_bike},
    {"id": "pickup", "name": "ربع نقل", "icon": Icons.local_shipping},
    {"id": "jumbo", "name": "جامبو", "icon": Icons.fire_truck},
  ];

  @override
  void initState() {
    super.initState();
    _currentMapCenter = widget.initialLocation ?? const LatLng(30.0444, 31.2357); // القاهرة كافتراضي أدق
    _determinePosition();
  }

  @override
  void dispose() {
    _detailsController.dispose();
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  String _generateOTP() {
    var rng = Random();
    return (1000 + rng.nextInt(9000)).toString();
  }

  Future<void> _searchPlaces(String query) async {
    if (query.length < 3) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final url = 'https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=8&countrycodes=eg&accept-language=ar';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept-Language': 'ar', 'User-Agent': 'AksabApp/1.0'}
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _searchResults = json.decode(response.body);
            _isSearching = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _onSearchResultTap(dynamic result) {
    double lat = double.parse(result['lat']);
    double lon = double.parse(result['lon']);
    LatLng target = LatLng(lat, lon);
    
    _mapController.move(target, 16.5);
    
    setState(() {
      _currentMapCenter = target;
      _tempAddress = result['display_name'];
      _searchResults = [];
      _searchController.clear();
      FocusScope.of(context).unfocus();
    });
  }

  Future<void> _determinePosition() async {
    if (widget.initialLocation != null) {
      _getAddress(widget.initialLocation!);
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      LatLng myLocation = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _currentMapCenter = myLocation;
          _mapController.move(myLocation, 15);
          _getAddress(myLocation);
        });
      }
    } catch (e) {
      debugPrint("Location Error: $e");
    }
  }

  Future<void> _getAddress(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        if (mounted) {
          setState(() {
            _tempAddress = "${place.street ?? ''} ${place.subLocality ?? ''} ${place.locality ?? ''}".trim();
            if (_tempAddress.isEmpty) _tempAddress = "موقع مخصص";
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() { _tempAddress = "نقطة على الخريطة"; });
    }
  }

  Future<void> _updatePricing(String vehicleType) async {
    if (_pickupLocation == null || _dropoffLocation == null) return;
    try {
      double distance = _deliveryService.calculateDistance(
        _pickupLocation!.latitude, _pickupLocation!.longitude,
        _dropoffLocation!.latitude, _dropoffLocation!.longitude
      );
      final results = await _deliveryService.calculateDetailedTripCost(
        distanceInKm: distance,
        vehicleType: vehicleType
      );
      setState(() {
        _pricingDetails = results;
        _estimatedPrice = results['totalPrice']!;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("خطأ في حساب السعر")));
      }
    }
  }

  void _handleNextStep() async {
    if (_currentStep == PickerStep.pickup) {
      _pickupLocation = _currentMapCenter;
      _pickupAddress = _tempAddress;
      setState(() {
        _currentStep = PickerStep.dropoff;
        _tempAddress = "حدد وجهة التوصيل الآن...";
      });
    } else if (_currentStep == PickerStep.dropoff) {
      _dropoffLocation = _currentMapCenter;
      _dropoffAddress = _tempAddress;
      await _updatePricing(_selectedVehicle);
      _showFinalConfirmation();
    }
  }

  Future<void> _finalizeAndUpload() async {
    if (_pricingDetails['totalPrice'] == 0) return;
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      String rawEmail = user?.email ?? "";
      String derivedPhone = rawEmail.contains('@') ? rawEmail.split('@')[0] : (user?.phoneNumber ?? "0000000000");
      final String securityCode = _generateOTP();    

      final docRef = await FirebaseFirestore.instance.collection('specialRequests').add({
        'userId': user?.uid ?? 'anonymous',
        'userPhone': derivedPhone,
        'pickupLocation': GeoPoint(_pickupLocation!.latitude, _pickupLocation!.longitude),
        'pickupAddress': _pickupAddress,
        'dropoffLocation': GeoPoint(_dropoffLocation!.latitude, _dropoffLocation!.longitude),
        'dropoffAddress': _dropoffAddress,
        'totalPrice': _pricingDetails['totalPrice'],
        'commissionAmount': _pricingDetails['commissionAmount'],
        'driverNet': _pricingDetails['driverNet'],
        'vehicleType': _selectedVehicle,
        'details': _detailsController.text,
        'status': 'pending',
        'verificationCode': securityCode,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_special_order_id', docRef.id);
      BubbleService.show(docRef.id);

      if (!mounted) return;
      Navigator.pop(context);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text("🚀 طلبك وصل للمناديب!")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentMapCenter,
                initialZoom: 15.0,
                onPositionChanged: (pos, hasGesture) {
                  if (hasGesture) {
                    _currentMapCenter = pos.center;
                    _getAddress(_currentMapCenter);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: _isSatelliteMode
                      ? 'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v11/tiles/{z}/{x}/{y}?access_token=$mapboxToken'
                      : 'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token=$mapboxToken',
                  additionalOptions: {'accessToken': mapboxToken},
                  tileProvider: NetworkTileProvider(), 
                ),
              ],
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Icon(
                  Icons.location_on_sharp,
                  size: 50,
                  color: _currentStep == PickerStep.pickup ? Colors.greenAccent : Colors.redAccent,
                ),
              ),
            ),
            _buildSearchBar(),
            Positioned(
              top: 165,
              left: 20,
              child: FloatingActionButton.small(
                backgroundColor: Colors.white,
                onPressed: () => setState(() => _isSatelliteMode = !_isSatelliteMode),
                child: Icon(
                  _isSatelliteMode ? Icons.map : Icons.satellite_alt,
                  color: Colors.blue[900],
                ),
              ),
            ),
            Positioned(
              top: 50,
              right: 15,
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.arrow_forward, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            _buildActionCard(),
            if (_isLoading) Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Positioned(
      top: 100,
      left: 15,
      right: 15,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => _searchPlaces(val),
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
              decoration: InputDecoration(
                hintText: _currentStep == PickerStep.pickup ? "ابحث عن مكان الاستلام..." : "ابحث عن وجهة التوصيل...",
                prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                suffixIcon: _isSearching
                    ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                    : (_searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.close), onPressed: () { _searchController.clear(); setState(() { _searchResults = []; }); }) : null),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
          if (_searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 5),
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _searchResults.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final res = _searchResults[index];
                  return ListTile(
                    leading: const Icon(Icons.place, color: Colors.red, size: 20),
                    title: Text(
                      res['display_name'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      "اضغط للانتقال لهذا الموقع",
                      style: TextStyle(fontSize: 10, color: Colors.grey[600], fontFamily: 'Cairo'),
                    ),
                    onTap: () => _onSearchResultTap(res),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionCard() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(15, 0, 15, 15),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, -5))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.my_location, color: Colors.blue[900], size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_tempAddress,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo')),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _handleNextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentStep == PickerStep.pickup ? Colors.green[800] : Colors.red[800],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 5,
                  ),
                  child: Text(
                    _currentStep == PickerStep.pickup ? "تأكيد مكان الاستلام" : "تأكيد وجهة التوصيل",
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showFinalConfirmation() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(25, 20, 25, MediaQuery.of(context).viewInsets.bottom + 10),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                      const SizedBox(height: 15),
                      const Text("إتمام طلب التوصيل", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, fontFamily: 'Cairo')),
                      const Divider(height: 30),
                      SizedBox(
                        height: 90,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _vehicles.length,
                          itemBuilder: (context, index) {
                            final v = _vehicles[index];
                            bool isSelected = _selectedVehicle == v['id'];
                            return GestureDetector(
                              onTap: () async {
                                setModalState(() => _selectedVehicle = v['id']);
                                await _updatePricing(v['id']);
                                setModalState(() {});
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 95,
                                margin: const EdgeInsets.only(left: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.blue.withOpacity(0.08) : Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: isSelected ? Colors.blue : Colors.grey[200]!, width: 2),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(v['icon'], color: isSelected ? Colors.blue : Colors.grey, size: 28),
                                    Text(v['name'], style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontFamily: 'Cairo', fontSize: 13)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _detailsController,
                        style: const TextStyle(fontFamily: 'Cairo'),
                        decoration: InputDecoration(
                          hintText: "ملاحظات للمندوب (اختياري)...",
                          hintStyle: const TextStyle(fontSize: 14),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildSummaryItem(Icons.circle, Colors.green, "من: $_pickupAddress"),
                      const SizedBox(height: 8),
                      _buildSummaryItem(Icons.location_on, Colors.red, "إلى: $_dropoffAddress"),
                      const Divider(height: 35),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("التكلفة التقريبية:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                          Text("${_estimatedPrice.toStringAsFixed(0)} ج.م", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 22, fontFamily: 'Cairo')),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _finalizeAndUpload,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                          child: const Text("تأكيد وإرسال", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 10),
        Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontFamily: 'Cairo'))),
      ],
    );
  }
}
