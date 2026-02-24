// lib/screens/retailer_dispatch_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import '../models/consumer_order_model.dart';
import '../services/delivery_service.dart';
import 'dart:math';

class RetailerDispatchScreen extends StatefulWidget {
  final ConsumerOrderModel order;
  final LatLng storeLocation; // موقع السوبر ماركت

  const RetailerDispatchScreen({
    super.key,
    required this.order,
    required this.storeLocation,
  });

  @override
  State<RetailerDispatchScreen> createState() => _RetailerDispatchScreenState();
}

class _RetailerDispatchScreenState extends State<RetailerDispatchScreen> {
  final MapController _mapController = MapController();
  final DeliveryService _deliveryService = DeliveryService();
  
  final String mapboxToken = "pk.eyJ1IjoiYW1yc2hpcGwiLCJhIjoiY21lajRweGdjMDB0eDJsczdiemdzdXV6biJ9.E--si9vOB93NGcAq7uVgGw";

  String _pickupAddress = "جاري جلب العنوان...";
  String _dropoffAddress = "جاري جلب العنوان...";
  double _estimatedPrice = 0.0;
  Map<String, double> _pricingDetails = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeDispatch();
  }

  Future<void> _initializeDispatch() async {
    // 1. جلب العناوين نصياً للعرض
    _getAddress(widget.storeLocation, true);
    // تأكد أن موديل الطلب يحتوي على LatLng للعميل
    // لو مش موجود حالياً، هنفترض وجود حقل customerLatLng في الموديل
    _getAddress(widget.order.customerLatLng, false);

    // 2. حساب التكلفة للموتوسيكل فقط فوراً
    double distance = _deliveryService.calculateDistance(
      widget.storeLocation.latitude, widget.storeLocation.longitude,
      widget.order.customerLatLng.latitude, widget.order.customerLatLng.longitude
    );

    final results = await _deliveryService.calculateDetailedTripCost(
      distanceInKm: distance,
      vehicleType: "motorcycle" // ثابت للموتوسيكل
    );

    setState(() {
      _pricingDetails = results;
      _estimatedPrice = results['totalPrice']!;
    });
  }

  Future<void> _getAddress(LatLng position, bool isPickup) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          String addr = "${place.street ?? ''} ${place.locality ?? ''}";
          if (isPickup) _pickupAddress = addr; else _dropoffAddress = addr;
        });
      }
    } catch (e) {
      if (mounted) setState(() { if (isPickup) _pickupAddress = "موقع المتجر"; else _dropoffAddress = "موقع العميل"; });
    }
  }

  String _generateOTP() => (1000 + Random().nextInt(9000)).toString();

  Future<void> _sendToRadar() async {
    if (_estimatedPrice == 0) return;
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final String securityCode = _generateOTP();

      // الرفع لنفس المجموعة (specialRequests) مع الحقل المميز
      await FirebaseFirestore.instance.collection('specialRequests').add({
        'userId': user?.uid ?? 'anonymous_retailer',
        'userPhone': widget.order.customerPhone, // هاتف العميل للتوصيل
        'pickupLocation': GeoPoint(widget.storeLocation.latitude, widget.storeLocation.longitude),
        'pickupAddress': _pickupAddress,
        'dropoffLocation': GeoPoint(widget.order.customerLatLng.latitude, widget.order.customerLatLng.longitude),
        'dropoffAddress': _dropoffAddress,
        'totalPrice': _pricingDetails['totalPrice'],
        'commissionAmount': _pricingDetails['commissionAmount'],
        'driverNet': _pricingDetails['driverNet'],
        'vehicleType': 'motorcycle',
        'details': "طلب من متجر: رقم الطلب ${widget.order.orderId}",
        'status': 'pending',
        'verificationCode': securityCode,
        'createdAt': FieldValue.serverTimestamp(),
        // ✅ الحقل المميز للتفريق بين طلب المستهلك وطلب التاجر
        'requestSource': 'retailer', 
        'originalOrderId': widget.order.id, // ربط الطلبين ببعض
      });

      if (!mounted) return;
      Navigator.pop(context); // العودة لصفحة الطلبات
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.green, content: Text("🚀 تم بث الطلب للرادار بنجاح!"))
      );
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
        appBar: AppBar(
          title: const Text("تأكيد مسار التوصيل", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
          backgroundColor: Colors.white,
          elevation: 1,
          centerTitle: true,
        ),
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.storeLocation,
                initialZoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token=$mapboxToken',
                  additionalOptions: {'accessToken': mapboxToken},
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: widget.storeLocation,
                      child: const Icon(Icons.store, color: Colors.green, size: 40),
                    ),
                    Marker(
                      point: widget.order.customerLatLng,
                      child: const Icon(Icons.person_pin_circle, color: Colors.red, size: 40),
                    ),
                  ],
                ),
              ],
            ),
            _buildDispatchCard(),
            if (_isLoading) Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }

  Widget _buildDispatchCard() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.all(15),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLocationRow(Icons.circle, Colors.green, "الاستلام: $_pickupAddress"),
            const SizedBox(height: 10),
            _buildLocationRow(Icons.location_on, Colors.red, "التسليم: $_dropoffAddress"),
            const Divider(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("تكلفة التوصيل (موتوسيكل):", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("${_estimatedPrice.toStringAsFixed(0)} ج.م", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _sendToRadar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[800],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                child: const Text("تأكيد وبث للرادار الآن", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 10),
        Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
      ],
    );
  }
}
