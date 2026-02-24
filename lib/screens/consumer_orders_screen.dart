import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

import '../providers/customer_orders_provider.dart';
import '../models/consumer_order_model.dart';
import '../constants/constants.dart';
import '../helpers/order_printer_helper.dart';
import '../services/delivery_service.dart';

// --- الصفحة الفعلية لبث الطلب للرادار (نسخة التاجر) ---
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

  String _pickupAddress = "جاري جلب عنوان المتجر...";
  String _dropoffAddress = "جاري جلب عنوان العميل...";
  double _estimatedPrice = 0.0;
  Map<String, double> _pricingDetails = {};
  bool _isLoading = false;

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

  String _generateOTP() => (1000 + Random().nextInt(9000)).toString();

  Future<void> _sendToRadar() async {
    if (_estimatedPrice == 0) return;
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final String securityCode = _generateOTP();

      await FirebaseFirestore.instance.collection('specialRequests').add({
        'userId': user?.uid ?? 'anonymous_retailer',
        'userPhone': widget.order.customerPhone,
        'pickupLocation': GeoPoint(widget.storeLocation.latitude, widget.storeLocation.longitude),
        'pickupAddress': _pickupAddress,
        'dropoffLocation': GeoPoint(widget.order.customerLatLng.latitude, widget.order.customerLatLng.longitude),
        'dropoffAddress': _dropoffAddress,
        'totalPrice': _pricingDetails['totalPrice'],
        'commissionAmount': _pricingDetails['commissionAmount'],
        'driverNet': _pricingDetails['driverNet'],
        'vehicleType': 'motorcycle',
        'details': "طلب تجاري رقم: ${widget.order.orderId}",
        'status': 'pending',
        'verificationCode': securityCode,
        'createdAt': FieldValue.serverTimestamp(),
        'requestSource': 'retailer', // العلامة المميزة
        'originalOrderId': widget.order.id,
      });

      if (!mounted) return;
      Navigator.pop(context);
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
          title: const Text("تأكيد وبث الطلب", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
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
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [const Icon(Icons.circle, color: Colors.green, size: 16), const SizedBox(width: 10), Expanded(child: Text("من: $_pickupAddress", maxLines: 1, overflow: TextOverflow.ellipsis))]),
            const SizedBox(height: 10),
            Row(children: [const Icon(Icons.location_on, color: Colors.red, size: 16), const SizedBox(width: 10), Expanded(child: Text("إلى: $_dropoffAddress", maxLines: 1, overflow: TextOverflow.ellipsis))]),
            const Divider(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("التكلفة (موتوسيكل):", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("${_estimatedPrice.toStringAsFixed(0)} ج.م", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                onPressed: _sendToRadar,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text("تأكيد وبث للرادار الآن", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- الشاشة الرئيسية للطلبات ---
class ConsumerOrdersScreen extends StatelessWidget {
  const ConsumerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ordersProvider = Provider.of<CustomerOrdersProvider>(context);
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('طلبات العملاء', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true, backgroundColor: Colors.white, foregroundColor: const Color(0xFF4CAF50), elevation: 1,
      ),
      body: SafeArea(
        child: ordersProvider.isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
            : ordersProvider.orders.isEmpty
                ? Center(child: Text(ordersProvider.message ?? 'لا توجد طلبات.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(15),
                    itemCount: ordersProvider.orders.length,
                    itemBuilder: (context, index) => OrderCard(order: ordersProvider.orders[index], provider: ordersProvider),
                  ),
      ),
    );
  }
}

class OrderCard extends StatefulWidget {
  final ConsumerOrderModel order;
  final CustomerOrdersProvider provider;
  const OrderCard({super.key, required this.order, required this.provider});

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  bool _isExpanded = false;
  late String _selectedStatus;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.order.status;
  }

  void _confirmFreelanceDispatch(BuildContext context, ConsumerOrderModel order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('تأكيد إرسال للمندوب'),
        content: Text('هل تود بث الطلب رقم ${order.orderId} للمناديب الأحرار؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RetailerDispatchScreen(
                    order: order,
                    // هنا يجب تمرير إحداثيات المتجر الحقيقية
                    storeLocation: const LatLng(31.2001, 29.9187), 
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50)),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final bool isDisabled = order.status == OrderStatuses.DELIVERED || order.status == OrderStatuses.CANCELLED;

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: order.status == OrderStatuses.NEW_ORDER ? Colors.orange : Colors.green, width: 2)),
      child: ExpansionTile(
        title: Text('طلب رقم: ${order.orderId}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${order.finalAmount} EGP - ${order.customerName}'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildInfoRow(Icons.location_on, 'العنوان', order.customerAddress),
                const Divider(),
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  items: OrderStatusesHelpers.allStatuses.map((s) => DropdownMenuItem(value: s, child: Text(getStatusDisplayName(s)))).toList(),
                  onChanged: isDisabled ? null : (val) => setState(() => _selectedStatus = val!),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: ElevatedButton(onPressed: isDisabled ? null : () => widget.provider.updateOrderStatus(order.id, _selectedStatus), child: const Text('حفظ'))),
                    const SizedBox(width: 10),
                    Expanded(child: ElevatedButton(onPressed: () => OrderPrinterHelper.printOrderReceipt(order), child: const Text('طباعة'))),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isDisabled ? null : () => _confirmFreelanceDispatch(context, order),
                    icon: const Icon(Icons.delivery_dining),
                    label: const Text('بث الطلب للرادار'),
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(children: [Icon(icon, size: 16), const SizedBox(width: 8), Text('$label: $value', style: const TextStyle(fontSize: 13))]);
  }
}

extension OrderStatusesHelpers on OrderStatuses {
  static List<String> get allStatuses => [OrderStatuses.NEW_ORDER, OrderStatuses.PROCESSING, OrderStatuses.SHIPPED, OrderStatuses.DELIVERED, OrderStatuses.CANCELLED];
}
