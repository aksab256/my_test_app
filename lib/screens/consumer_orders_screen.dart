import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../providers/customer_orders_provider.dart';
import '../models/consumer_order_model.dart';
import '../constants/constants.dart';
import '../helpers/order_printer_helper.dart';
import '../services/delivery_service.dart';

// --- الصفحة الوسيطة لمراجعة المسافة والسعر قبل البث النهائي ---
class RetailerDispatchScreen extends StatefulWidget {
  final ConsumerOrderModel order;
  final LatLng storeLocation;

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

  String _pickupAddress = "جاري التحميل...";
  String _dropoffAddress = "جاري التحميل...";
  double _estimatedPrice = 0.0;
  Map<String, double> _pricingDetails = {};

  @override
  void initState() {
    super.initState();
    _initializeDispatch();
  }

  Future<void> _initializeDispatch() async {
    _getAddress(widget.storeLocation, true);
    _getAddress(widget.order.customerLatLng, false);

    double distance = _deliveryService.calculateDistance(
      widget.storeLocation.latitude, widget.storeLocation.longitude,
      widget.order.customerLatLng.latitude, widget.order.customerLatLng.longitude
    );

    final results = await _deliveryService.calculateDetailedTripCost(
      distanceInKm: distance,
      vehicleType: "motorcycle" 
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("مراجعة بيانات التوصيل", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
          backgroundColor: Colors.white, elevation: 1, centerTitle: true,
        ),
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: widget.storeLocation, initialZoom: 13.0),
              children: [
                TileLayer(
                  urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token=$mapboxToken',
                  additionalOptions: {'accessToken': mapboxToken},
                ),
                MarkerLayer(
                  markers: [
                    Marker(point: widget.storeLocation, child: const Icon(Icons.store, color: Colors.green, size: 40)),
                    Marker(point: widget.order.customerLatLng, child: const Icon(Icons.person_pin_circle, color: Colors.red, size: 40)),
                  ],
                ),
              ],
            ),
            _buildDispatchCard(),
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
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [const Icon(Icons.circle, color: Colors.green, size: 16), const SizedBox(width: 10), Expanded(child: Text("من: $_pickupAddress", maxLines: 1, overflow: TextOverflow.ellipsis))]),
            const SizedBox(height: 10),
            Row(children: [const Icon(Icons.location_on, color: Colors.red, size: 16), const SizedBox(width: 10), Expanded(child: Text("إلى: ${widget.order.customerAddress}", maxLines: 1, overflow: TextOverflow.ellipsis))]),
            const Divider(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("التكلفة التقديرية:", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("${_estimatedPrice.toStringAsFixed(0)} ج.م", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                onPressed: () {
                  // هنا الزرار فقط ينقلك للصفحة التالية (صفحة التتبع/البث الفعلي)
                  // Navigator.push(context, MaterialPageRoute(builder: (context) => YourNextScreen(order: widget.order, pricing: _pricingDetails)));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم الانتقال لصفحة التتبع...")));
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text("تأكيد وفتح صفحة التتبع", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- ويدجت كارت الطلب (في الشاشة الرئيسية) ---
class OrderCard extends StatefulWidget {
  final ConsumerOrderModel order;
  final CustomerOrdersProvider provider;
  const OrderCard({super.key, required this.order, required this.provider});

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  late String _selectedStatus;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.order.status;
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final bool isDisabled = order.status == OrderStatuses.DELIVERED || order.status == OrderStatuses.CANCELLED;

    return Card(
      margin: const EdgeInsets.all(10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        title: Text('طلب رقم: ${order.orderId}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('المجموع: ${order.finalAmount} ج.م'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("الأصناف:", style: TextStyle(fontWeight: FontWeight.bold)),
                ...order.items.map((item) => Text("- ${item.name} (${item.quantity})")),
                const Divider(),
                Text("العنوان: ${order.customerAddress}"),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isDisabled ? null : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RetailerDispatchScreen(
                            order: order,
                            storeLocation: LatLng(
                              double.tryParse(widget.provider.storeLat ?? "31.2001") ?? 31.2001, 
                              double.tryParse(widget.provider.storeLng ?? "29.9187") ?? 29.9187
                            ),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.delivery_dining),
                    label: const Text('طلب مندوب'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
