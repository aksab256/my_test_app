// lib/screens/special_requests/location_picker_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/delivery_service.dart';
import 'package:sizer/sizer.dart';

enum PickerStep { pickup, dropoff, confirm }

class LocationPickerScreen extends StatefulWidget {
  static const routeName = '/location-picker';
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  final DeliveryService _deliveryService = DeliveryService();
  
  PickerStep _currentStep = PickerStep.pickup;
  LatLng _currentMapCenter = const LatLng(30.0444, 31.2357); // القاهرة افتراضياً
  
  LatLng? _pickupLocation;
  String _pickupAddress = "جاري جلب العنوان...";
  
  LatLng? _dropoffLocation;
  String _dropoffAddress = "";
  
  String _tempAddress = "حرك الخريطة لتحديد الموقع";
  double _estimatedPrice = 0.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  // جلب موقع المستخدم الحالي عند الفتح
  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentMapCenter = LatLng(position.latitude, position.longitude);
      _mapController.move(_currentMapCenter, 15);
    });
  }

  // تحويل الإحداثيات لعنوان نصي
  Future<void> _getAddress(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _tempAddress = "${place.street}, ${place.subLocality}, ${place.locality}";
        });
      }
    } catch (e) {
      setState(() { _tempAddress = "موقع غير مسمى"; });
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
      
      _estimatedPrice = await _calculatePrice();
      _showFinalConfirmation();
    }
  }

  Future<double> _calculatePrice() async {
    if (_pickupLocation == null || _dropoffLocation == null) return 0.0;
    double distance = _deliveryService.calculateDistance(
      _pickupLocation!.latitude, _pickupLocation!.longitude,
      _dropoffLocation!.latitude, _dropoffLocation!.longitude
    );
    return await _deliveryService.calculateTripCost(distanceInKm: distance);
  }

  // رفع الطلب النهائي لـ Firestore
  Future<void> _finalizeAndUpload() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('specialRequests').add({
        'userId': user?.uid ?? 'anonymous',
        'pickupLocation': GeoPoint(_pickupLocation!.latitude, _pickupLocation!.longitude),
        'pickupAddress': _pickupAddress,
        'dropoffLocation': GeoPoint(_dropoffLocation!.latitude, _dropoffLocation!.longitude),
        'dropoffAddress': _dropoffAddress,
        'price': _estimatedPrice,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'delivery_only',
      });
      
      Navigator.pop(context); // إغلاق الـ BottomSheet
      Navigator.pop(context); // العودة للرئيسية
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم إرسال طلبك بنجاح!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showFinalConfirmation() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Text("ملخص الرحلة", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp)),
            const Divider(),
            _buildInfoRow(Icons.circle, Colors.green, "من: $_pickupAddress"),
            _buildInfoRow(Icons.location_on, Colors.red, "إلى: $_dropoffAddress"),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("تكلفة التوصيل التقديرية:", style: TextStyle(fontSize: 12.sp)),
                  Text("${_estimatedPrice.toStringAsFixed(2)} ج.م", 
                       style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold, fontSize: 16.sp)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _finalizeAndUpload,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
              ),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("تأكيد وطلب المندوب"),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, maxLines: 2, style: TextStyle(fontSize: 10.sp), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentStep == PickerStep.pickup ? "تحديد مكان الاستلام" : "تحديد وجهة التوصيل"),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _currentMapCenter,
              zoom: 15.0,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture) {
                  _currentMapCenter = pos.center!;
                  _getAddress(_currentMapCenter);
                }
              },
            ),
            children: [
              TileLayer(urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", subdomains: const ['a', 'b', 'c']),
            ],
          ),
          // الدبوس الثابت في منتصف الخريطة
          Center(
            child: Icon(Icons.location_pin, size: 40, color: _currentStep == PickerStep.pickup ? Colors.green : Colors.red),
          ),
          // واجهة التحكم السفلية
          PositionImageWidget(_tempAddress, _handleNextStep, _currentStep)
        ],
      ),
    );
  }

  Widget PositionImageWidget(String address, VoidCallback onPressed, PickerStep step) {
    return Positioned(
      bottom: 20, left: 20, right: 20,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(address, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 15),
              ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
                child: Text(step == PickerStep.pickup ? "تأكيد مكان الاستلام" : "تأكيد وجهة التوصيل"),
              )
            ],
          ),
        ),
      ),
    );
  }
}
