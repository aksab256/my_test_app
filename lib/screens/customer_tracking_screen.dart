// lib/screens/customer_tracking_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerTrackingScreen extends StatelessWidget {
  static const routeName = '/customerTracking';
  final String orderId;
  const CustomerTrackingScreen({super.key, required this.orderId});

  final String mapboxToken = "pk.eyJ1IjoiYW1yc2hpcGwiLCJhIjoiY21lajRweGdjMDB0eDJsczdiemdzdXV6biJ9.E--si9vOB93NGcAq7uVgGw";

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('specialRequests').doc(orderId).snapshots(),
      builder: (context, orderSnapshot) {
        if (!orderSnapshot.hasData || !orderSnapshot.data!.exists) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        var orderData = orderSnapshot.data!.data() as Map<String, dynamic>;
        String status = orderData['status'] ?? "pending";
        String? driverId = orderData['driverId'];
        GeoPoint pickup = orderData['pickupLocation'];
        GeoPoint dropoff = orderData['dropoffLocation'];
        LatLng pickupLatLng = LatLng(pickup.latitude, pickup.longitude);
        LatLng dropoffLatLng = LatLng(dropoff.latitude, dropoff.longitude);

        return StreamBuilder<DocumentSnapshot>(
          stream: (driverId != null && driverId.isNotEmpty)
              ? FirebaseFirestore.instance.collection('freeDrivers').doc(driverId).snapshots()
              : const Stream.empty(),
          builder: (context, driverSnapshot) {
            Map<String, dynamic>? driverData;
            LatLng? driverLatLng;

            if (driverSnapshot.hasData && driverSnapshot.data!.exists) {
              driverData = driverSnapshot.data!.data() as Map<String, dynamic>;
              if (driverData != null && driverData.containsKey('location')) {
                GeoPoint dLoc = driverData['location'];
                driverLatLng = LatLng(dLoc.latitude, dLoc.longitude);
              }
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                extendBodyBehindAppBar: true,
                appBar: AppBar(
                  backgroundColor: Colors.white.withOpacity(0.8),
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.black, size: 30),
                  title: Text(
                    "تتبع الرحلة",
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18.sp, color: Colors.black),
                  ),
                  centerTitle: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                  ),
                ),
                body: Stack(
                  children: [
                    // 🗺️ الخريطة بمفتاح Mapbox
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: driverLatLng ?? pickupLatLng,
                        initialZoom: 14.5,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token=$mapboxToken',
                          additionalOptions: {'accessToken': mapboxToken},
                        ),
                        MarkerLayer(
                          markers: [
                            // نقطة الاستلام
                            Marker(
                              point: pickupLatLng,
                              width: 50, height: 50,
                              child: const Icon(Icons.location_on, color: Colors.green, size: 45),
                            ),
                            // نقطة التسليم
                            Marker(
                              point: dropoffLatLng,
                              width: 50, height: 50,
                              child: const Icon(Icons.flag_circle, color: Colors.red, size: 45),
                            ),
                            // المندوب (المتحرك)
                            if (driverLatLng != null)
                              Marker(
                                point: driverLatLng,
                                width: 70, height: 70,
                                child: _buildDriverMarker(orderData['vehicleType'] ?? 'motorcycle'),
                              ),
                          ],
                        ),
                      ],
                    ),
                    
                    // 🏷️ لوحة المعلومات السفلية
                    _buildBottomPanel(status, orderData, driverData),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDriverMarker(String vehicleType) {
    IconData icon = Icons.delivery_dining;
    if (vehicleType == "pickup" || vehicleType == "ربع نقل") icon = Icons.local_shipping;
    if (vehicleType == "jumbo" || vehicleType == "جامبو") icon = Icons.fire_truck;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[900],
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
          ),
          child: Icon(icon, color: Colors.white, size: 30),
        ),
        const Icon(Icons.arrow_drop_down, color: Colors.blue, size: 20),
      ],
    );
  }

  Widget _buildBottomPanel(String status, Map<String, dynamic> order, Map<String, dynamic>? driver) {
    return Positioned(
      bottom: 25, left: 15, right: 15,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 25, spreadRadius: 5)],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // مؤشر الحالة (Stepper)
            _statusStepper(status),
            const SizedBox(height: 20),
            const Divider(thickness: 1),
            const SizedBox(height: 10),
            
            // معلومات المندوب والسعر
            Row(
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.blue[100],
                  child: Icon(Icons.person, color: Colors.blue[900], size: 40),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver != null ? driver['fullname'] : "جاري تعيين مندوب...",
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.sp),
                      ),
                      Text(
                        "التكلفة النهائية: ${order['price']} ج.م",
                        style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w900, fontSize: 13.sp),
                      ),
                    ],
                  ),
                ),
                if (driver != null)
                  GestureDetector(
                    onTap: () => _makePhoneCall(driver['phone']),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                      child: const Icon(Icons.phone_in_talk, color: Colors.white, size: 30),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusStepper(String status) {
    bool isAccepted = status == 'accepted' || status == 'delivered';
    bool isDelivered = status == 'delivered';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _stepItem("تم الطلب", true),
        _stepLine(isAccepted),
        _stepItem("في الطريق", isAccepted),
        _stepLine(isDelivered),
        _stepItem("وصلنا", isDelivered),
      ],
    );
  }

  Widget _stepItem(String title, bool active) {
    return Column(
      children: [
        Icon(
          active ? Icons.check_circle : Icons.radio_button_off,
          color: active ? Colors.blue[900] : Colors.grey[300],
          size: 24.sp,
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 10.sp, 
            fontWeight: active ? FontWeight.w900 : FontWeight.normal,
            color: active ? Colors.black : Colors.grey
          ),
        ),
      ],
    );
  }

  Widget _stepLine(bool active) => Expanded(
    child: Container(
      height: 4, 
      margin: EdgeInsets.only(bottom: 25.sp, left: 5, right: 5),
      decoration: BoxDecoration(
        color: active ? Colors.blue[900] : Colors.grey[200],
        borderRadius: BorderRadius.circular(10)
      ),
    ),
  );

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }
}

