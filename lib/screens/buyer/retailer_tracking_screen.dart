// lib/screens/retailer/retailer_tracking_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';

class RetailerTrackingScreen extends StatelessWidget {
  static const routeName = '/retailerTracking';
  final String orderId; // معرف الطلب في specialRequests

  const RetailerTrackingScreen({super.key, required this.orderId});

  final String mapboxToken = "pk.eyJ1IjoiYW1yc2hpcGwiLCJhIjoiY21lajRweGdjMDB0eDJsczdiemdzdXV6biJ9.E--si9vOB93NGcAq7uVgGw";

  // دالة الإلغاء من طرف التاجر
  Future<void> _handleRetailerCancel(BuildContext context, String currentStatus, String? originalOrderId) async {
    bool isAccepted = currentStatus != 'pending';
    
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("إلغاء طلب التوصيل"),
          content: Text(isAccepted 
              ? "المندوب وافق بالفعل وهو في الطريق إليك. إلغاء الطلب الآن قد يترتب عليه رسوم تعويض. هل أنت متأكد؟" 
              : "هل تريد إلغاء البحث عن مندوب؟"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("تراجع")),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true), 
              child: const Text("تأكيد وإلغاء", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
            ),
          ],
        ),
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      // 1. تحديث حالة طلب الرادار
      await FirebaseFirestore.instance.collection('specialRequests').doc(orderId).update({
        'status': isAccepted ? 'cancelled_by_retailer_after_accept' : 'cancelled_by_retailer_before_accept',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': 'retailer'
      });

      // 2. 🔗 فك الارتباط من الطلب الأصلي لكي يرجع الزر لحالته الأولى
      if (originalOrderId != null && originalOrderId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('consumerorders').doc(originalOrderId).update({
          'specialRequestId': FieldValue.delete(), // حذف الحقل ليعود الزر برتقالي
        });
      }

      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint("Cancel Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (orderId.isEmpty) return const Scaffold(body: Center(child: Text("طلب غير موجود")));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('specialRequests').doc(orderId).snapshots(),
      builder: (context, orderSnapshot) {
        if (!orderSnapshot.hasData || !orderSnapshot.data!.exists) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        var orderData = orderSnapshot.data!.data() as Map<String, dynamic>;
        String status = orderData['status'] ?? "pending";
        String? originalOrderId = orderData['originalOrderId']; // لجلب ID الأوردر الأصلي

        // إغلاق الشاشة عند الإلغاء أو انتهاء التسليم بنجاح
        if (status.contains('cancelled') || status == 'delivered') {
           WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).pop();
          });
        }

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
                  backgroundColor: Colors.white.withOpacity(0.9),
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.black),
                  title: Text("متابعة خط سير المندوب", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.sp, color: Colors.black)),
                  centerTitle: true,
                  leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.black), onPressed: () => Navigator.pop(context)),
                ),
                body: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: driverLatLng ?? pickupLatLng, 
                        initialZoom: 14.0
                      ),
                      children: [
                        TileLayer(urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token=$mapboxToken'),
                        MarkerLayer(
                          markers: [
                            Marker(point: pickupLatLng, width: 45, height: 45, child: const Icon(Icons.store, color: Colors.green, size: 40)),
                            Marker(point: dropoffLatLng, width: 45, height: 45, child: const Icon(Icons.person_pin_circle, color: Colors.red, size: 40)),
                            if (driverLatLng != null)
                              Marker(point: driverLatLng, width: 60, height: 60, child: _buildDriverMarker()),
                          ],
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: SafeArea(
                        child: _buildRetailerBottomPanel(context, status, orderData, driverData, originalOrderId),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRetailerBottomPanel(BuildContext context, String status, Map<String, dynamic> order, Map<String, dynamic>? driver, String? originalOrderId) {
    double progress = 0.1;
    String statusDesc = "جاري البحث عن مندوب...";
    Color mainColor = Colors.orange;

    if (status == 'accepted') { progress = 0.4; statusDesc = "تم قبول الطلب.. المندوب في طريقه للمحل"; mainColor = Colors.blue; }
    else if (status == 'at_pickup') { progress = 0.6; statusDesc = "المندوب وصل للمحل (الاستلام)"; mainColor = Colors.indigo; }
    else if (status == 'picked_up') { progress = 0.8; statusDesc = "المندوب استلم وهو في طريقه للعميل"; mainColor = Colors.green; }

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(25), 
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 15)]
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: Colors.grey[200], color: mainColor)),
              const SizedBox(width: 10),
              Text("${(progress * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(statusDesc, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp, color: mainColor)),
          const Divider(height: 25),

          Container(
            margin: const EdgeInsets.only(bottom: 15),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.blue.shade100)),
            child: Row(
              children: [
                const Icon(Icons.person_outline, color: Colors.blue),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("العميل المستلم:", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                      Text("${order['customerName']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ),
                Text("${order['orderFinalAmount']} ج.م", style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green)),
              ],
            ),
          ),

          Row(
            children: [
              CircleAvatar(radius: 25, backgroundColor: Colors.grey[100], child: const Icon(Icons.delivery_dining, color: Colors.black)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driver != null ? driver['fullname'] : "في انتظار قبول مندوب...", style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(driver != null ? "رقم المندوب: ${driver['phone']}" : "تتبع مباشر", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
              if (driver != null)
                IconButton(
                  onPressed: () async => await launchUrl(Uri.parse("tel:${driver['phone']}")),
                  icon: const Icon(Icons.phone_in_talk, color: Colors.green, size: 30),
                ),
            ],
          ),
          
          if (status == 'pending' || status == 'accepted' || status == 'at_pickup')
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextButton(
                onPressed: () => _handleRetailerCancel(context, status, originalOrderId),
                child: const Text("إلغاء الاستدعاء", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDriverMarker() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.blue, width: 2), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)]),
      child: const Icon(Icons.delivery_dining, color: Colors.blue, size: 30),
    );
  }
}
