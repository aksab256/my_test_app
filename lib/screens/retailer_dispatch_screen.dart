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
  final LatLng storeLocation; // موقع السوبر ماركت (نقطة الاستلام)

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
    // 1. جلب العناوين نصياً للعرض على الشاشة (الاستلام والتسليم)
    _getAddress(widget.storeLocation, true);
    _getAddress(widget.order.customerLatLng, false);

    // 2. حساب المسافة بدقة بين النقطتين
    double distance = _deliveryService.calculateDistance(
      widget.storeLocation.latitude, 
      widget.storeLocation.longitude,
      widget.order.customerLatLng.latitude, 
      widget.order.customerLatLng.longitude
    );

    // 3. حساب التكلفة بناءً على المسافة ونوع المركبة
    final results = await _deliveryService.calculateDetailedTripCost(
      distanceInKm: distance,
      vehicleType: "motorcycle" 
    );

    if (mounted) {
      setState(() {
        _pricingDetails = results;
        _estimatedPrice = results['totalPrice']!;
      });
      _fitMapBounds();
    }
  }

  void _fitMapBounds() {
    final bounds = LatLngBounds.fromPoints([
      widget.storeLocation,
      widget.order.customerLatLng,
    ]);
    _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
  }

  Future<void> _getAddress(LatLng position, bool isPickup) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        if (mounted) {
          setState(() {
            String addr = "${place.street ?? ''} ${place.locality ?? ''}";
            if (isPickup) _pickupAddress = addr; else _dropoffAddress = addr;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() { 
          if (isPickup) _pickupAddress = "موقع المتجر"; 
          else _dropoffAddress = widget.order.customerAddress; 
        });
      }
    }
  }

  String _generateOTP() => (1000 + Random().nextInt(9000)).toString();

  Future<void> _sendToRadar() async {
    if (_estimatedPrice == 0) return;
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final String securityCode = _generateOTP();

      // 🚀 رفع الطلب للرادار بكافة بيانات التواصل (أمان كامل وتنسيق سهل)
      await FirebaseFirestore.instance.collection('specialRequests').add({
        'userId': user?.uid ?? 'anonymous_retailer',
        
        // 🏪 بيانات التاجر (الاستلام)
        'retailerName': widget.order.supermarketName,
        'retailerPhone': widget.order.supermarketPhone, 
        
        // 👤 بيانات العميل (التسليم)
        'customerName': widget.order.customerName,
        'userPhone': widget.order.customerPhone, // هاتف المستلم
        
        // 📍 المواقع الجغرافية
        'pickupLocation': GeoPoint(widget.storeLocation.latitude, widget.storeLocation.longitude),
        'pickupAddress': _pickupAddress,
        'dropoffLocation': GeoPoint(widget.order.customerLatLng.latitude, widget.order.customerLatLng.longitude),
        'dropoffAddress': _dropoffAddress,
        
        // 💰 الحسابات المالية
        'totalPrice': _pricingDetails['totalPrice'],
        'commissionAmount': _pricingDetails['commissionAmount'],
        'driverNet': _pricingDetails['driverNet'],
        'vehicleType': 'motorcycle',
        
        // 📝 تفاصيل إضافية
        'details': "توصيل طلب متجر: ${widget.order.supermarketName} | عميل: ${widget.order.customerName}",
        'status': 'pending',
        'verificationCode': securityCode,
        'createdAt': FieldValue.serverTimestamp(),
        'requestSource': 'retailer', 
        'originalOrderId': widget.order.id, 
      });

      if (!mounted) return;
      Navigator.pop(context); 
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.green, content: Text("🚀 تم بث الطلب لرادار المناديب بنجاح!"))
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ أثناء البث: $e")));
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
          title: const Text("تأكيد مسار التوصيل", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 18)),
          backgroundColor: Colors.white,
          elevation: 1,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.black), onPressed: () => Navigator.pop(context)),
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
                      width: 50, height: 50,
                      child: const Icon(Icons.storefront_rounded, color: Colors.green, size: 45),
                    ),
                    Marker(
                      point: widget.order.customerLatLng,
                      width: 50, height: 50,
                      child: const Icon(Icons.person_pin_circle, color: Colors.red, size: 45),
                    ),
                  ],
                ),
              ],
            ),
            _buildDispatchCard(),
            if (_isLoading) Container(color: Colors.black45, child: const Center(child: CircularProgressIndicator(color: Colors.white))),
          ],
        ),
      ),
    );
  }

  Widget _buildDispatchCard() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.fromLTRB(15, 0, 15, 30),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, -5))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            _buildLocationRow(Icons.circle, Colors.green, "الاستلام من المتجر:", _pickupAddress),
            const Padding(padding: EdgeInsets.only(right: 7), child: SizedBox(height: 15, child: VerticalDivider(width: 2, color: Colors.grey))),
            _buildLocationRow(Icons.location_on, Colors.red, "التسليم للعميل:", _dropoffAddress),
            const Divider(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("تكلفة التوصيل المقدرة", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text("المستلم: ${widget.order.customerName}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                  ],
                ),
                Text("${_estimatedPrice.toStringAsFixed(0)} ج.م", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.green)),
              ],
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _sendToRadar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[800],
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.radar, color: Colors.white),
                    SizedBox(width: 10),
                    Text("تأكيد وبث لجميع المناديب", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, Color color, String label, String address) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 4), child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(address, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }
}
