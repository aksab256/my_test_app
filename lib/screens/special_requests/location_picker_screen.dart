import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // المكتبة الرسمية
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import 'package:sizer/sizer.dart';
import '../../services/bubble_service.dart';
import '../../services/delivery_service.dart';

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
  GoogleMapController? _mapController;
  final DeliveryService _deliveryService = DeliveryService();
  final TextEditingController _detailsController = TextEditingController();

  PickerStep _currentStep = PickerStep.pickup;
  late LatLng _currentMapCenter;

  LatLng? _pickupLocation;
  String _pickupAddress = "جاري جلب العنوان...";
  LatLng? _dropoffLocation;
  String _dropoffAddress = "";

  double _estimatedPrice = 0.0;
  Map<String, double> _pricingDetails = {'totalPrice': 0.0, 'commissionAmount': 0.0, 'driverNet': 0.0};

  String _tempAddress = "جاري تحديد الموقع...";
  String _loadingStatus = "جاري تشغيل نظام GPS...";
  bool _isLoading = false;
  bool _isMapLoading = true;
  MapType _currentMapType = MapType.normal;

  String _selectedVehicle = "motorcycle";
  final List<Map<String, dynamic>> _vehicles = [
    {"id": "motorcycle", "name": "موتوسيكل", "icon": Icons.directions_bike},
    {"id": "pickup", "name": "ربع نقل", "icon": Icons.local_shipping},
    {"id": "jumbo", "name": "جامبو", "icon": Icons.fire_truck},
  ];

  @override
  void initState() {
    super.initState();
    // إحداثيات افتراضية (الإسكندرية/القاهرة)
    _currentMapCenter = widget.initialLocation ?? LatLng(30.0444, 31.2357);
    _determinePosition();
  }

  @override
  void dispose() {
    _detailsController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // تحديد الموقع الحالي للمستخدم
  Future<void> _determinePosition() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isMapLoading = false);
        return;
      }
    }
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      LatLng myLocation = LatLng(position.latitude, position.longitude);

      _moveCamera(myLocation);
      await _getAddress(myLocation);

      setState(() {
        _currentMapCenter = myLocation;
        _isMapLoading = false;
      });
    } catch (e) {
      setState(() => _isMapLoading = false);
    }
  }

  // تحريك الكاميرا بسلاسة
  void _moveCamera(LatLng target) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 15));
  }

  // تحويل الإحداثيات لعنوان نصي (Geocoding)
  Future<void> _getAddress(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _tempAddress = "${place.street ?? ''} ${place.subLocality ?? ''} ${place.locality ?? ''}".trim();
          if (_tempAddress.isEmpty) _tempAddress = "موقع مخصص";
        });
      }
    } catch (e) {
      setState(() => _tempAddress = "نقطة على الخريطة");
    }
  }

  void _handleNextStep() async {
    if (_currentStep == PickerStep.pickup) {
      _pickupLocation = _currentMapCenter;
      _pickupAddress = _tempAddress;
      setState(() {
        _currentStep = PickerStep.dropoff;
        _tempAddress = "حدد وجهة التوصيل...";
      });
    } else if (_currentStep == PickerStep.dropoff) {
      _dropoffLocation = _currentMapCenter;
      _dropoffAddress = _tempAddress;
      await _updatePricing(_selectedVehicle);
      _showFinalConfirmation();
    }
  }

  Future<void> _updatePricing(String vehicleType) async {
    if (_pickupLocation == null || _dropoffLocation == null) return;
    double distance = Geolocator.distanceBetween(
            _pickupLocation!.latitude, _pickupLocation!.longitude,
            _dropoffLocation!.latitude, _dropoffLocation!.longitude) /
        1000;

    final results = await _deliveryService.calculateDetailedTripCost(
        distanceInKm: distance, vehicleType: vehicleType);
    setState(() {
      _pricingDetails = results;
      _estimatedPrice = results['totalPrice']!;
    });
  }

  Future<void> _finalizeAndUpload() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final docRef = await FirebaseFirestore.instance.collection('specialRequests').add({
        'userId': user?.uid ?? 'anonymous',
        'pickupLocation': GeoPoint(_pickupLocation!.latitude, _pickupLocation!.longitude),
        'pickupAddress': _pickupAddress,
        'dropoffLocation': GeoPoint(_dropoffLocation!.latitude, _dropoffLocation!.longitude),
        'dropoffAddress': _dropoffAddress,
        'totalPrice': _pricingDetails['totalPrice'],
        'vehicleType': _selectedVehicle,
        'details': _detailsController.text,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      BubbleService.show(docRef.id);
      Navigator.pop(context);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: Colors.green, content: Text("🚀 طلبك قيد التنفيذ")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: _currentMapCenter, zoom: 14),
              mapType: _currentMapType,
              myLocationEnabled: true,
              myLocationButtonEnabled: false, // سنصنع زر مخصص
              zoomControlsEnabled: false,
              onMapCreated: (controller) => _mapController = controller,
              onCameraMove: (position) => _currentMapCenter = position.target,
              onCameraIdle: () => _getAddress(_currentMapCenter),
            ),

            // مؤشر السنتر (Pin)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 35),
                child: Icon(
                  Icons.location_on,
                  size: 45,
                  color: _currentStep == PickerStep.pickup ? Colors.green : Colors.red,
                ),
              ),
            ),

            // الأزرار الجانبية (تبديل الخريطة + موقعي)
            Positioned(
              right: 15,
              bottom: 220,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: "type",
                    backgroundColor: Colors.white,
                    onPressed: () => setState(() => _currentMapType =
                        _currentMapType == MapType.normal ? MapType.satellite : MapType.normal),
                    child: Icon(Icons.layers, color: Colors.blue[900]),
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton.small(
                    heroTag: "my_loc",
                    backgroundColor: Colors.white,
                    onPressed: _determinePosition,
                    child: Icon(Icons.gps_fixed, color: Colors.blue[900]),
                  ),
                ],
              ),
            ),

            // زر الرجوع
            Positioned(
              top: 50,
              right: 15,
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                    icon: const Icon(Icons.arrow_forward, color: Colors.black),
                    onPressed: () => Navigator.pop(context)),
              ),
            ),

            _buildActionCard(),

            if (_isMapLoading)
              Container(color: Colors.white, child: const Center(child: CircularProgressIndicator())),
            if (_isLoading)
              Container(
                  color: Colors.black45,
                  child: const Center(child: CircularProgressIndicator(color: Colors.white))),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard() {
    // 🚀 حساب مساحة الأمان السفلية لضمان عدم اختفاء الكارت تحت شريط التنقل
    double safeBottom = MediaQuery.of(context).padding.bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        // استخدام مسافة الأمان السفلية في المارجن
        margin: EdgeInsets.fromLTRB(15, 0, 15, safeBottom > 0 ? safeBottom : 15),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.location_searching, color: Colors.blue[900]),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(_tempAddress,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo'))),
              ],
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _handleNextStep,
                style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _currentStep == PickerStep.pickup ? Colors.green[700] : Colors.red[700],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: Text(
                    _currentStep == PickerStep.pickup ? "تحديد مكان الاستلام" : "تحديد وجهة التوصيل",
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              ),
            )
          ],
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
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          padding: EdgeInsets.fromLTRB(25, 20, 25, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("تفاصيل طلب التوصيل",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Cairo')),
              const Divider(height: 30),
              // اختيار المركبة
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _vehicles.map((v) {
                  bool isSelected = _selectedVehicle == v['id'];
                  return GestureDetector(
                    onTap: () {
                      setModalState(() => _selectedVehicle = v['id']);
                      _updatePricing(v['id']);
                    },
                    child: Column(
                      children: [
                        CircleAvatar(
                            backgroundColor: isSelected ? Colors.blue : Colors.grey[200],
                            child: Icon(v['icon'], color: isSelected ? Colors.white : Colors.grey)),
                        Text(v['name'], style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              TextField(
                  controller: _detailsController,
                  decoration: InputDecoration(
                      hintText: "ملاحظات إضافية...",
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text("التكلفة:", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("${_estimatedPrice.toStringAsFixed(0)} ج.م",
                    style: const TextStyle(
                        fontSize: 20, color: Colors.blue, fontWeight: FontWeight.bold))
              ]),
              const SizedBox(height: 20),
              SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                      onPressed: _finalizeAndUpload,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900]),
                      child: const Text("تأكيد الطلب", style: TextStyle(color: Colors.white)))),
            ],
          ),
        ),
      ),
    );
  }
}
