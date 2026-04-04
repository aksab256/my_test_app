import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; 
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:ui' as ui; // لإدارة أيقونات الخريطة المخصصة
import 'package:flutter/services.dart';

class CustomerTrackingScreen extends StatefulWidget {
  static const routeName = '/customerTracking';
  final String orderId;

  const CustomerTrackingScreen({super.key, required this.orderId});

  @override
  State<CustomerTrackingScreen> createState() => _CustomerTrackingScreenState();
}

class _CustomerTrackingScreenState extends State<CustomerTrackingScreen> {
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  bool _isMapReady = false;
  
  // --- إضافات التتبع الاحترافي ---
  BitmapDescriptor? _driverIcon;
  double _driverRotation = 0; // زاوية دوران المندوب
  LatLng? _lastDriverPosition;

  @override
  void initState() {
    super.initState();
    _loadCustomMarker(); // تحميل أيقونة الموتوسيكل
    Future.delayed(Duration.zero, () {
      setState(() => _isMapReady = true);
    });
  }

  // تحميل أيقونة مخصصة للمندوب
  Future<void> _loadCustomMarker() async {
    // يمكنك استبدال الرابط بصورة asset عندك لو موجودة
    // حالياً سنستخدم الماركر الافتراضي الملون لحين توفير صورة asset
    _driverIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
  }

  // حساب الزاوية بين نقطتين لجعل الماركر يلف مع الطريق
  double _calculateRotation(LatLng start, LatLng end) {
    double latDiff = end.latitude - start.latitude;
    double lngDiff = end.longitude - start.longitude;
    return (ui.Gradient.lerp(null, null, 0)?.hashCode.toDouble() ?? 0) + 
           (57.2957795 * (ui.Offset(lngDiff, latDiff).direction)); 
  }

  @override
  void dispose() {
    super.dispose();
  }

  // --- [منطق التقييم والإلغاء - مطابق تماماً للأصل بدون اختصار] ---
  // (تم الإبقاء على الدوال _showRatingDialog و _handleSmartCancel كما هي في الكود الأصلي)
  
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
            title: const Text("تقييم تجربة التوصيل", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("لقد تم تسليم طلبك بنجاح! قيم المندوب للمساعدة في تحسين الخدمة.", style: TextStyle(fontFamily: 'Cairo')),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) => IconButton(
                    icon: Icon(index < selectedRating ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber, size: 35),
                    onPressed: () => setState(() => selectedRating = index + 1.0),
                  )),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: commentController,
                  decoration: InputDecoration(hintText: "ملاحظاتك (اختياري)...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey[50]),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF43A047), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: () async {
                    await FirebaseFirestore.instance.collection('specialRequests').doc(widget.orderId).update({'rating': selectedRating, 'customerComment': commentController.text, 'status': 'delivered'});
                    if (driverId.isNotEmpty) {
                      await FirebaseFirestore.instance.collection('freeDrivers').doc(driverId).update({'totalStars': FieldValue.increment(selectedRating), 'reviewsCount': FieldValue.increment(1)});
                    }
                    if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text("تأكيد التقييم", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSmartCancel(BuildContext context, String currentStatus) async {
    bool isAccepted = currentStatus != 'pending';
    String targetStatus = isAccepted ? 'cancelled_by_user_after_accept' : 'cancelled_by_user_before_accept';
    if (isAccepted) {
      bool confirm = await showDialog(context: context, builder: (ctx) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(title: const Text("تنبيه هام"), content: const Text("المندوب في طريقه إليك الآن. إلغاء الطلب سيؤدي لخصم تعويض للمندوب. استمرار؟"), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("تراجع")), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("إلغاء", style: TextStyle(color: Colors.red)))]))) ?? false;
      if (!confirm) return;
    }
    await FirebaseFirestore.instance.collection('specialRequests').doc(widget.orderId).update({'status': targetStatus, 'cancelledAt': FieldValue.serverTimestamp(), 'cancelledBy': 'customer'});
    if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.orderId.isEmpty) return const Scaffold(body: Center(child: Text("طلب غير موجود")));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('specialRequests').doc(widget.orderId).snapshots(),
      builder: (context, orderSnapshot) {
        if (!orderSnapshot.hasData || !orderSnapshot.data!.exists) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        var orderData = orderSnapshot.data!.data() as Map<String, dynamic>;
        String status = orderData['status'] ?? "pending";
        bool isRated = orderData.containsKey('rating');

        // الحالات النهائية
        if (status.contains('cancelled') || status == 'no_drivers_available' || (status == 'delivered' && isRated)) {
          WidgetsBinding.instance.addPostFrameCallback((_) { if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst); });
        }
        if (status == 'delivered' && !isRated) {
          WidgetsBinding.instance.addPostFrameCallback((_) { _showRatingDialog(context, orderData['driverId'] ?? ""); });
        }

        String? driverId = orderData['driverId'];
        GeoPoint pickup = orderData['pickupLocation'];
        GeoPoint dropoff = orderData['dropoffLocation'];
        LatLng pickupLatLng = LatLng(pickup.latitude, pickup.longitude);
        LatLng dropoffLatLng = LatLng(dropoff.latitude, dropoff.longitude);

        return StreamBuilder<DocumentSnapshot>(
          stream: (driverId != null && driverId.isNotEmpty) ? FirebaseFirestore.instance.collection('freeDrivers').doc(driverId).snapshots() : const Stream.empty(),
          builder: (context, driverSnapshot) {
            LatLng? driverLatLng;
            if (driverSnapshot.hasData && driverSnapshot.data!.exists) {
              var driverData = driverSnapshot.data!.data() as Map<String, dynamic>;
              // ✅ قراءة اللوكيشن بشكل مرن (سواء كان حقل lat/lng أو GeoPoint)
              if (driverData.containsKey('lat') && driverData.containsKey('lng')) {
                driverLatLng = LatLng(driverData['lat'], driverData['lng']);
              } else if (driverData.containsKey('location')) {
                GeoPoint dLoc = driverData['location'];
                driverLatLng = LatLng(dLoc.latitude, dLoc.longitude);
              }

              if (driverLatLng != null) {
                // حساب الدوران إذا تحرك المندوب
                if (_lastDriverPosition != null && _lastDriverPosition != driverLatLng) {
                  _driverRotation = _calculateRotation(_lastDriverPosition!, driverLatLng!);
                }
                _lastDriverPosition = driverLatLng;
                _animateCameraToDriver(driverLatLng!);
              }
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                extendBodyBehindAppBar: true,
                appBar: AppBar(backgroundColor: Colors.white.withOpacity(0.9), elevation: 0, title: Text("تتبع الرحلة اللحظي", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.sp, color: Colors.black, fontFamily: 'Cairo')), centerTitle: true),
                body: Stack(
                  children: [
                    if (_isMapReady)
                    GoogleMap(
                      initialCameraPosition: CameraPosition(target: driverLatLng ?? pickupLatLng, zoom: 15),
                      onMapCreated: (c) => _mapController.complete(c),
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                      // ✅ إضافة خاصية الـ Polylines هنا لاحقاً (رسم المسار)
                      markers: {
                        Marker(markerId: const MarkerId('pickup'), position: pickupLatLng, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen), infoWindow: const InfoWindow(title: "موقع الاستلام")),
                        Marker(markerId: const MarkerId('dropoff'), position: dropoffLatLng, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed), infoWindow: const InfoWindow(title: "موقعك")),
                        if (driverLatLng != null)
                          Marker(
                            markerId: const MarkerId('driver'),
                            position: driverLatLng!,
                            rotation: _driverRotation, // ✅ جعل الماركر يلف
                            anchor: const Offset(0.5, 0.5), // المركز في المنتصف لضمان الدوران الصحيح
                            icon: _driverIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                            flat: true, // يجعله يبدو كأنه جزء من الأرض وليس واقفا (احترافي أكثر)
                          ),
                      },
                    ) else const Center(child: CircularProgressIndicator()),
                    Align(alignment: Alignment.bottomCenter, child: SafeArea(child: _buildUnifiedBottomPanel(context, status, orderData, driverSnapshot.data?.data() as Map<String, dynamic>?, orderData['verificationCode'] ?? "----"))),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _animateCameraToDriver(LatLng location) async {
    final GoogleMapController controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: location, zoom: 15.5, tilt: 45))); // إضافة إمالة (Tilt) لرؤية 3D خفيفة
  }

  Widget _buildUnifiedBottomPanel(BuildContext context, String status, Map<String, dynamic> order, Map<String, dynamic>? driver, String code) {
    double progress = 0.1;
    String statusDesc = "بانتظار قبول مندوب...";
    Color mainColor = Colors.orange;
    if (status == 'accepted') { progress = 0.4; statusDesc = "المندوب وافق وفي طريقه إليك"; mainColor = Colors.blue; }
    else if (status == 'at_pickup') { progress = 0.6; statusDesc = "المندوب وصل للمحل"; mainColor = Colors.indigo; }
    else if (status == 'picked_up') { progress = 0.8; statusDesc = "المندوب استلم الطلب وهو في الطريق"; mainColor = Colors.green; }

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 15)]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [Expanded(child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: Colors.grey[200], color: mainColor)), const SizedBox(width: 10), Text("${(progress * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold))]),
          const SizedBox(height: 12),
          Text(statusDesc, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp, color: mainColor, fontFamily: 'Cairo')),
          const Divider(height: 25),
          if (status == 'accepted' || status == 'at_pickup' || status == 'picked_up')
            Container(margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.amber)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.security, color: Colors.amber), const SizedBox(width: 10), const Text("كود التسليم: ", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')), Text(code, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900, color: Colors.red[900]))])),
          Row(
            children: [
              CircleAvatar(radius: 25, backgroundColor: Colors.blue[50], child: const Icon(Icons.person, color: Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(driver != null ? driver['fullname'] : "بحث عن مندوب...", style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')), const Text("موثق من رابية أحلى", style: TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'Cairo'))])),
              if (driver != null) IconButton(onPressed: () async => await launchUrl(Uri.parse("tel:${driver['phone']}")), icon: const Icon(Icons.phone_in_talk, color: Colors.green, size: 30)),
            ],
          ),
          if (status == 'pending' || status == 'accepted' || status == 'at_pickup')
            Padding(padding: const EdgeInsets.only(top: 10), child: TextButton(onPressed: () => _handleSmartCancel(context, status), child: const Text("إلغاء الطلب", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontFamily: 'Cairo')))),
        ],
      ),
    );
  }
}

