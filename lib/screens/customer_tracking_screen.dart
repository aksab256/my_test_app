import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // المكتبة الوحيدة للخرائط
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

class CustomerTrackingScreen extends StatefulWidget {
  static const routeName = '/customerTracking';
  final String orderId;

  const CustomerTrackingScreen({super.key, required this.orderId});

  @override
  State<CustomerTrackingScreen> createState() => _CustomerTrackingScreenState();
}

class _CustomerTrackingScreenState extends State<CustomerTrackingScreen> {
  // استخدام Completer للتحكم في الـ Google Map Controller
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    // جوجل مابس لا تحتاج لتهيئة كاش يدوي مثل المكتبة السابقة
    Future.delayed(Duration.zero, () {
      setState(() {
        _isMapReady = true;
      });
    });
  }

  @override
  void dispose() {
    // التخلص من أي موارد إذا لزم الأمر
    super.dispose();
  }

  // --- [منطق التقييم - مطابق للأصل] ---
  void _showRatingDialog(BuildContext context, String driverId) {
    double selectedRating = 5;
    TextEditingController commentController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("تقييم تجربة التوصيل", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("لقد تم تسليم طلبك بنجاح! قيم المندوب للمساعدة في تحسين الخدمة."),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: Colors.amber,
                        size: 35,
                      ),
                      onPressed: () => setState(() => selectedRating = index + 1.0),
                    );
                  }),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: commentController,
                  decoration: InputDecoration(
                    hintText: "ملاحظاتك (اختياري)...",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF43A047),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                  ),
                  onPressed: () async {
                    await FirebaseFirestore.instance.collection('specialRequests').doc(widget.orderId).update({
                      'rating': selectedRating,
                      'customerComment': commentController.text,
                      'status': 'delivered'
                    });
                    
                    if (driverId.isNotEmpty) {
                      await FirebaseFirestore.instance.collection('freeDrivers').doc(driverId).update({
                        'totalStars': FieldValue.increment(selectedRating),
                        'reviewsCount': FieldValue.increment(1),
                      });
                    }

                    if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text("تأكيد التقييم", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- [منطق الإلغاء الذكي - مطابق للأصل] ---
  Future<void> _handleSmartCancel(BuildContext context, String currentStatus) async {
    bool isAccepted = currentStatus != 'pending';
    String targetStatus = isAccepted
        ? 'cancelled_by_user_after_accept'
        : 'cancelled_by_user_before_accept';

    if (isAccepted) {
      bool confirm = await showDialog(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("تنبيه هام"),
            content: const Text("المندوب في طريقه إليك الآن. إلغاء الطلب الآن سيؤدي لخصم تعويض للمندوب من نقاطك. هل تريد الاستمرار؟"),
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
    }

    try {
      await FirebaseFirestore.instance.collection('specialRequests').doc(widget.orderId).update({
        'status': targetStatus,
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': 'customer'
      });
      if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      debugPrint("Cancel Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.orderId.isEmpty) return const Scaffold(body: Center(child: Text("طلب غير موجود")));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('specialRequests').doc(widget.orderId).snapshots(),
      builder: (context, orderSnapshot) {
        if (!orderSnapshot.hasData || !orderSnapshot.data!.exists) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        var orderData = orderSnapshot.data!.data() as Map<String, dynamic>;
        String status = orderData['status'] ?? "pending";
        bool isRated = orderData.containsKey('rating');

        // التعامل مع حالات انتهاء الطلب
        if (status.contains('cancelled') || status == 'no_drivers_available' || (status == 'delivered' && isRated)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              if (status == 'no_drivers_available') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("عذراً، لم نجد مناديب متاحة حالياً لطلبك. يرجى المحاولة مرة أخرى."), backgroundColor: Colors.redAccent),
                );
              }
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          });
        }

        if (status == 'delivered' && !isRated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showRatingDialog(context, orderData['driverId'] ?? "");
          });
        }

        String? driverId = orderData['driverId'];
        String verificationCode = orderData['verificationCode'] ?? "----";
        GeoPoint pickup = orderData['pickupLocation'];
        GeoPoint dropoff = orderData['dropoffLocation'];
        
        // تحويل لـ Google Maps LatLng
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
                
                // تحريك الكاميرا لموقع المندوب في جوجل مابس
                _animateCameraToDriver(driverLatLng);
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
                  title: Text("تتبع الرحلة", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.sp, color: Colors.black)),
                  centerTitle: true,
                ),
                body: Stack(
                  children: [
                    if (_isMapReady)
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: driverLatLng ?? pickupLatLng,
                        zoom: 14.5,
                      ),
                      onMapCreated: (GoogleMapController controller) {
                        _mapController.complete(controller);
                      },
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                      markers: {
                        Marker(
                          markerId: const MarkerId('pickup'),
                          position: pickupLatLng,
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                        ),
                        Marker(
                          markerId: const MarkerId('dropoff'),
                          position: dropoffLatLng,
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                        ),
                        if (driverLatLng != null)
                          Marker(
                            markerId: const MarkerId('driver'),
                            position: driverLatLng,
                            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                            // ملاحظة: لجعل الماركر بأيقونة سيارة/موتوسيكل مخصصة في جوجل مابس نحتاج تحويل الـ Widget لـ BitmapDescriptor
                          ),
                      },
                    ) else const Center(child: CircularProgressIndicator()),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: SafeArea(
                        child: _buildUnifiedBottomPanel(context, status, orderData, driverData, verificationCode),
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

  // تحريك الكاميرا بسلاسة في جوجل مابس
  Future<void> _animateCameraToDriver(LatLng location) async {
    final GoogleMapController controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newLatLng(location));
  }

  Widget _buildUnifiedBottomPanel(BuildContext context, String status, Map<String, dynamic> order, Map<String, dynamic>? driver, String code) {
    double progress = 0.1;
    String statusDesc = "بانتظار قبول مندوب...";
    Color mainColor = Colors.orange;

    if (status == 'accepted') { progress = 0.4; statusDesc = "المندوب وافق وفي طريقه إليك"; mainColor = Colors.blue; }
    else if (status == 'at_pickup') { progress = 0.6; statusDesc = "المندوب وصل لموقع الاستلام"; mainColor = Colors.indigo; }
    else if (status == 'picked_up') { progress = 0.8; statusDesc = "جاري التوصيل الآن"; mainColor = Colors.green; }
    else if (status == 'no_drivers_available') { progress = 1.0; statusDesc = "عذراً، لم نجد مناديب حالياً"; mainColor = Colors.red; }

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
          if (status == 'accepted' || status == 'at_pickup' || status == 'picked_up')
            Container(
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.amber)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.security, color: Colors.amber),
                  const SizedBox(width: 10),
                  const Text("كود التسليم: ", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(code, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900, color: Colors.red[900])),
                ],
              ),
            ),
          Row(
            children: [
              CircleAvatar(radius: 25, backgroundColor: Colors.blue[50], child: const Icon(Icons.person, color: Colors.blue)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driver != null ? driver['fullname'] : "بحث عن مندوب...", style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Text("موثق من رابية أحلى", style: TextStyle(fontSize: 10, color: Colors.grey)),
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
                onPressed: () => _handleSmartCancel(context, status),
                child: const Text("إلغاء الطلب", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }
}

