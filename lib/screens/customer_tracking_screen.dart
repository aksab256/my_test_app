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
        String verificationCode = orderData['verificationCode'] ?? "----"; // جلب كود الأمان

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
                  backgroundColor: Colors.white.withOpacity(0.9),
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.black),
                  title: Text("تتبع رحلة Aksab", // تحديث الاسم
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.sp, color: Colors.black)),
                  centerTitle: true,
                ),
                body: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: driverLatLng ?? pickupLatLng,
                        initialZoom: 14.5,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token=$mapboxToken',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: pickupLatLng,
                              width: 50, height: 50,
                              child: const Icon(Icons.location_on, color: Colors.green, size: 45),
                            ),
                            Marker(
                              point: dropoffLatLng,
                              width: 50, height: 50,
                              child: const Icon(Icons.flag_circle, color: Colors.red, size: 45),
                            ),
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
                    _buildUnifiedBottomPanel(status, orderData, driverData, verificationCode),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 🛠️ البار الموحد الجديد مع كود الأمان
  Widget _buildUnifiedBottomPanel(String status, Map<String, dynamic> order, Map<String, dynamic>? driver, String code) {
    double progress = 0.1;
    String statusDesc = "بانتظار قبول مندوب...";
    Color progressColor = Colors.orange;

    if (status == 'accepted') {
      progress = 0.4;
      statusDesc = "المندوب في طريقه لموقع الاستلام";
      progressColor = Colors.blue;
    } else if (status == 'at_pickup') {
      progress = 0.5;
      statusDesc = "المندوب وصل لموقع الاستلام";
      progressColor = Colors.blueAccent;
    } else if (status == 'picked_up') {
      progress = 0.8;
      statusDesc = "تم استلام الشحنة.. جاري التوصيل";
      progressColor = Colors.green;
    } else if (status == 'delivered') {
      progress = 1.0;
      statusDesc = "تم التسليم بنجاح ✅";
      progressColor = Colors.green[800]!;
    }

    return Positioned(
      bottom: 20, left: 15, right: 15,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // شريط التقدم الموحد
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: Colors.grey[200],
                      color: progressColor,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Text("${(progress * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            Text(statusDesc, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp, color: progressColor)),
            const Divider(height: 30),

            // كود الأمان (يظهر فقط إذا لم يتم الاستلام بعد)
            if (status == 'accepted' || status == 'at_pickup')
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.amber)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.security, color: Colors.amber),
                    const SizedBox(width: 10),
                    Text("كود تسليم الشحنة للمندوب: ", style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold)),
                    Text(code, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.black, letterSpacing: 2, color: Colors.red[900])),
                  ],
                ),
              ),

            // معلومات المندوب
            Row(
              children: [
                CircleAvatar(radius: 30, backgroundColor: Colors.grey[100], child: const Icon(Icons.person, size: 35)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(driver != null ? driver['fullname'] : "بحث عن مندوب...", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.sp)),
                      Text("Aksab Delivery", style: TextStyle(color: Colors.grey, fontSize: 10.sp)),
                    ],
                  ),
                ),
                if (driver != null)
                  IconButton(
                    onPressed: () => _makePhoneCall(driver['phone']),
                    icon: const Icon(Icons.phone_in_talk, color: Colors.green, size: 35),
                  ),
              ],
            ),
          ],
        ),
      ),
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
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
          ),
          child: Icon(icon, color: Colors.white, size: 25),
        ),
        const Icon(Icons.arrow_drop_down, color: Colors.blue, size: 20),
      ],
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }
}

