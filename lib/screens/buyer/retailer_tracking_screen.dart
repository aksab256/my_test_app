// lib/screens/retailer/retailer_tracking_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';

class RetailerTrackingScreen extends StatelessWidget {
  static const routeName = '/retailerTracking';
  final String orderId; 

  const RetailerTrackingScreen({super.key, required this.orderId});

  final String mapboxToken = "pk.eyJ1IjoiYW1yc2hpcGwiLCJhIjoiY21lajRweGdjMDB0eDJsczdiemdzdXV6biJ9.E--si9vOB93NGcAq7uVgGw";

  // دالة الإلغاء
  Future<void> _handleRetailerCancel(BuildContext context, String currentStatus, String? originalOrderId) async {
    bool isAccepted = currentStatus != 'pending';
    
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("إلغاء طلب التوصيل", style: TextStyle(fontFamily: 'Cairo')),
          content: Text(isAccepted 
              ? "المندوب وافق بالفعل وهو في طريقه إليك. إلغاء الطلب الآن قد يترتب عليه رسوم تعويض نتيجة حجز العهدة. هل أنت متأكد؟" 
              : "هل تريد إلغاء البحث عن مندوب؟", style: const TextStyle(fontFamily: 'Cairo')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("تراجع")),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true), 
              child: const Text("تأكيد وإلغاء", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontFamily: 'Cairo'))
            ),
          ],
        ),
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      await FirebaseFirestore.instance.collection('specialRequests').doc(orderId).update({
        'status': isAccepted ? 'cancelled_by_retailer_after_accept' : 'cancelled_by_retailer_before_accept',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': 'retailer'
      });

      if (originalOrderId != null && originalOrderId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('consumerorders').doc(originalOrderId).update({
          'specialRequestId': FieldValue.delete(),
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
        String? originalOrderId = orderData['originalOrderId'];
        
        // 🛡️ منطق الأكواد الذكي:
        // لو الحالة عودة للتاجر (مرتجع)، نقرأ كود المرتجع، غير كدة نقرأ كود الاستلام العادي
        bool isReturning = status == 'returning_to_seller';
        String verificationCode = isReturning 
            ? (orderData['returnVerificationCode'] ?? "----") 
            : (orderData['verificationCode'] ?? "----");

        // الخروج من الصفحة لو تم الإلغاء أو التسليم النهائي
        if (status.contains('cancelled_by') || status == 'delivered') {
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
                  title: Text(isReturning ? "متابعة عودة العهدة (مرتجع)" : "متابعة العهدة والنقل", 
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.sp, color: isReturning ? Colors.red[900] : Colors.black, fontFamily: 'Cairo')),
                  centerTitle: true,
                  leading: IconButton(icon: Icon(Icons.arrow_back_ios, color: isReturning ? Colors.red : Colors.black), onPressed: () => Navigator.pop(context)),
                ),
                body: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(initialCenter: driverLatLng ?? pickupLatLng, initialZoom: 14.0),
                      children: [
                        TileLayer(urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token=$mapboxToken'),
                        MarkerLayer(
                          markers: [
                            Marker(point: pickupLatLng, width: 45, height: 45, child: const Icon(Icons.store, color: Colors.green, size: 40)),
                            Marker(point: dropoffLatLng, width: 45, height: 45, child: const Icon(Icons.person_pin_circle, color: Colors.red, size: 40)),
                            if (driverLatLng != null)
                              Marker(point: driverLatLng, width: 60, height: 60, child: _buildDriverMarker(isReturning)),
                          ],
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: SafeArea(
                        child: _buildRetailerBottomPanel(context, status, orderData, driverData, originalOrderId, verificationCode, isReturning),
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

  Widget _buildRetailerBottomPanel(BuildContext context, String status, Map<String, dynamic> order, Map<String, dynamic>? driver, String? originalOrderId, String code, bool isReturning) {
    double progress = 0.1;
    String statusDesc = "جاري البحث عن مندوب لتمثيل العهدة...";
    Color mainColor = isReturning ? Colors.red : Colors.orange;

    if (isReturning) {
      progress = 0.9;
      statusDesc = "المستهلك رفض الاستلام.. العهدة عائدة إليك";
      mainColor = Colors.red[900]!;
    } else if (status == 'accepted') { progress = 0.4; statusDesc = "تم تخصيص مندوب.. في طريقه للاستلام"; mainColor = Colors.blue; }
    else if (status == 'at_pickup') { progress = 0.6; statusDesc = "المندوب في نقطة الاستلام (توقيع العهدة)"; mainColor = Colors.indigo; }
    else if (status == 'picked_up') { progress = 0.8; statusDesc = "العهدة في حوزة المندوب (قيد التوصيل)"; mainColor = Colors.green; }

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(25), 
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 15)],
        border: isReturning ? Border.all(color: Colors.red, width: 2) : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: Colors.grey[200], color: mainColor)),
              const SizedBox(width: 10),
              Text("${(progress * 100).toInt()}%", style: TextStyle(fontWeight: FontWeight.bold, color: mainColor)),
            ],
          ),
          const SizedBox(height: 12),
          Text(statusDesc, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.sp, color: mainColor, fontFamily: 'Cairo')),
          const Divider(height: 25),

          // ✅ كارت الكود (استلام عهدة أو استلام مرتجع)
          if (status == 'accepted' || status == 'at_pickup' || isReturning)
            Container(
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: isReturning ? Colors.red[50] : Colors.amber[50], 
                borderRadius: BorderRadius.circular(15), 
                border: Border.all(color: isReturning ? Colors.red.shade200 : Colors.amber.shade300)
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(isReturning ? Icons.assignment_return : Icons.security, color: isReturning ? Colors.red : Colors.amber, size: 24),
                      const SizedBox(width: 10),
                      Text(isReturning ? "كود استلام المرتجع: " : "كود تأكيد العهدة: ", 
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, fontFamily: 'Cairo')),
                      Text(code, style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w900, color: isReturning ? Colors.red[900] : Colors.blue[900])),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(thickness: 0.5),
                  ),
                  Text(
                    isReturning 
                      ? "⚠️ لا تعطي هذا الكود للمندوب إلا بعد استلام البضاعة المرتجعة والتأكد من سلامتها تماماً."
                      : "⚠️ تنبيه: إدخال المندوب لهذا الكود بمثابة توقيع إلكتروني باستلام العهدة وتأمين قيمتها.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10.sp, color: Colors.black87, fontFamily: 'Cairo', fontWeight: FontWeight.w600, height: 1.4),
                  ),
                ],
              ),
            ),

          // بيانات المندوب المسؤول
          Row(
            children: [
              CircleAvatar(radius: 25, backgroundColor: Colors.grey[100], child: Icon(Icons.delivery_dining, color: mainColor)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driver != null ? driver['fullname'] : "جاري التخصيص...", style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                    Text(driver != null ? "هاتف: ${driver['phone']}" : "تتبع مباشر", style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'Cairo')),
                  ],
                ),
              ),
              if (driver != null)
                IconButton(
                  onPressed: () async => await launchUrl(Uri.parse("tel:${driver['phone']}")),
                  icon: Icon(Icons.phone_in_talk, color: mainColor, size: 30),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDriverMarker(bool isReturning) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, 
        shape: BoxShape.circle, 
        border: Border.all(color: isReturning ? Colors.red : Colors.blue, width: 2.5), 
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)]
      ),
      child: Icon(Icons.delivery_dining, color: isReturning ? Colors.red : Colors.blue, size: 35),
    );
  }
}
