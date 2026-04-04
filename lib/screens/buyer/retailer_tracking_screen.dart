import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

class RetailerTrackingScreen extends StatefulWidget {
  static const routeName = '/retailerTracking';
  final String orderId;

  const RetailerTrackingScreen({super.key, required this.orderId});

  @override
  State<RetailerTrackingScreen> createState() => _RetailerTrackingScreenState();
}

class _RetailerTrackingScreenState extends State<RetailerTrackingScreen> {
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  bool _isMapReady = false;

  // --- إضافات التتبع الاحترافي ---
  BitmapDescriptor? _driverIcon;
  double _driverRotation = 0; 
  LatLng? _lastDriverPosition;
  Set<Polyline> _polylines = {}; 

  @override
  void initState() {
    super.initState();
    _loadCustomMarker();
    Future.delayed(Duration.zero, () {
      if (mounted) setState(() => _isMapReady = true);
    });
  }

  Future<void> _loadCustomMarker() async {
    _driverIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
  }

  // دالة حساب الدوران المتوافقة (النسخة الآمنة)
  double _calculateRotation(LatLng start, LatLng end) {
    double latDiff = (end.latitude - start.latitude).abs();
    double lngDiff = (end.longitude - start.longitude).abs();
    double rotation = 0;
    if (start.latitude < end.latitude && start.longitude < end.longitude) {
      rotation = (57.2957795 * (ui.Offset(lngDiff, latDiff).direction));
    } else if (start.latitude >= end.latitude && start.longitude < end.longitude) {
      rotation = 90 + (57.2957795 * (ui.Offset(latDiff, lngDiff).direction));
    } else if (start.latitude >= end.latitude && start.longitude >= end.longitude) {
      rotation = 180 + (57.2957795 * (ui.Offset(lngDiff, latDiff).direction));
    } else if (start.latitude < end.latitude && start.longitude >= end.longitude) {
      rotation = 270 + (57.2957795 * (ui.Offset(latDiff, lngDiff).direction));
    }
    return rotation;
  }

  void _updatePolyline(LatLng driver, LatLng destination) {
    if (!mounted) return;
    setState(() {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId("route"),
          points: [driver, destination],
          color: Colors.blue.withOpacity(0.6),
          width: 5,
          jointType: JointType.round,
        ),
      );
    });
  }

  // --- [منطق الإلغاء - مطابق تماماً للأصل] ---
  Future<void> _handleRetailerCancel(BuildContext context, String currentStatus, String? originalOrderId) async {
    bool isAccepted = currentStatus != 'pending';
    bool confirm = await showDialog(
          context: context,
          builder: (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("إلغاء طلب التوصيل", style: TextStyle(fontFamily: 'Cairo')),
              content: Text(
                  isAccepted
                      ? "المندوب وافق بالفعل وهو في طريقه إليك. إلغاء الطلب الآن قد يترتب عليه رسوم تعويض نتيجة حجز العهدة. هل أنت متأكد؟"
                      : "هل تريد إلغاء البحث عن مندوب؟",
                  style: const TextStyle(fontFamily: 'Cairo')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("تراجع")),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text("تأكيد وإلغاء",
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontFamily: 'Cairo'))),
              ],
            ),
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      await FirebaseFirestore.instance.collection('specialRequests').doc(widget.orderId).update({
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
    if (widget.orderId.isEmpty) return const Scaffold(body: Center(child: Text("طلب غير موجود")));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('specialRequests').doc(widget.orderId).snapshots(),
      builder: (context, orderSnapshot) {
        if (!orderSnapshot.hasData || !orderSnapshot.data!.exists) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        var orderData = orderSnapshot.data!.data() as Map<String, dynamic>;
        String status = orderData['status'] ?? "pending";
        String? originalOrderId = orderData['originalOrderId'];

        bool isReturning = status == 'returning_to_seller';
        String verificationCode = isReturning ? (orderData['returnVerificationCode'] ?? "----") : (orderData['verificationCode'] ?? "----");

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
            LatLng? driverLatLng;
            Map<String, dynamic>? driverData;

            if (driverSnapshot.hasData && driverSnapshot.data!.exists) {
              driverData = driverSnapshot.data!.data() as Map<String, dynamic>;
              if (driverData != null) {
                if (driverData.containsKey('lat') && driverData.containsKey('lng')) {
                  driverLatLng = LatLng(driverData['lat'], driverData['lng']);
                } else if (driverData.containsKey('location')) {
                  GeoPoint dLoc = driverData['location'];
                  driverLatLng = LatLng(dLoc.latitude, dLoc.longitude);
                }

                if (driverLatLng != null) {
                  if (_lastDriverPosition != null && _lastDriverPosition != driverLatLng) {
                    _driverRotation = _calculateRotation(_lastDriverPosition!, driverLatLng!);
                  }
                  _lastDriverPosition = driverLatLng;
                  _animateCameraToDriver(driverLatLng!);
                  
                  // تحديث المسار (Polyline)
                  LatLng destination = (status == 'accepted' || status == 'at_pickup' || isReturning) ? pickupLatLng : dropoffLatLng;
                  _updatePolyline(driverLatLng!, destination);
                }
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
                  actions: [
                    if (status == 'pending' || status == 'accepted' || status == 'at_pickup')
                      IconButton(icon: const Icon(Icons.cancel_outlined, color: Colors.red), onPressed: () => _handleRetailerCancel(context, status, originalOrderId))
                  ],
                ),
                body: Stack(
                  children: [
                    if (_isMapReady)
                    GoogleMap(
                      initialCameraPosition: CameraPosition(target: driverLatLng ?? pickupLatLng, zoom: 15.0, tilt: 45),
                      onMapCreated: (c) => _mapController.complete(c),
                      myLocationEnabled: false,
                      zoomControlsEnabled: false,
                      polylines: _polylines,
                      markers: {
                        Marker(markerId: const MarkerId('pickup'), position: pickupLatLng, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)),
                        Marker(markerId: const MarkerId('dropoff'), position: dropoffLatLng, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)),
                        if (driverLatLng != null)
                          Marker(
                            markerId: const MarkerId('driver'),
                            position: driverLatLng!,
                            rotation: _driverRotation,
                            anchor: const Offset(0.5, 0.5),
                            icon: _driverIcon ?? BitmapDescriptor.defaultMarkerWithHue(isReturning ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueAzure),
                            flat: true,
                          ),
                      },
                    ) else const Center(child: CircularProgressIndicator()),
                    Align(alignment: Alignment.bottomCenter, child: SafeArea(child: _buildRetailerBottomPanel(context, status, orderData, driverData, originalOrderId, verificationCode, isReturning))),
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
    controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: location, zoom: 15.5, tilt: 45)));
  }

  Widget _buildRetailerBottomPanel(BuildContext context, String status, Map<String, dynamic> order, Map<String, dynamic>? driver, String? originalOrderId, String code, bool isReturning) {
    double progress = 0.1;
    String statusDesc = "جاري البحث عن مندوب لتمثيل العهدة...";
    Color mainColor = isReturning ? Colors.red : Colors.orange;

    if (isReturning) { progress = 0.9; statusDesc = "المستهلك رفض الاستلام.. العهدة عائدة إليك"; mainColor = Colors.red[900]!; }
    else if (status == 'accepted') { progress = 0.4; statusDesc = "تم تخصيص مندوب.. في طريقه للاستلام"; mainColor = Colors.blue; }
    else if (status == 'at_pickup') { progress = 0.6; statusDesc = "المندوب في نقطة الاستلام (توقيع العهدة)"; mainColor = Colors.indigo; }
    else if (status == 'picked_up') { progress = 0.8; statusDesc = "العهدة في حوزة المندوب (قيد التوصيل)"; mainColor = Colors.green; }

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 15)], border: isReturning ? Border.all(color: Colors.red, width: 2) : null),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [Expanded(child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: Colors.grey[200], color: mainColor)), const SizedBox(width: 10), Text("${(progress * 100).toInt()}%", style: TextStyle(fontWeight: FontWeight.bold, color: mainColor))]),
          const SizedBox(height: 12),
          Text(statusDesc, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.sp, color: mainColor, fontFamily: 'Cairo')),
          const Divider(height: 25),
          if (status == 'accepted' || status == 'at_pickup' || isReturning)
            Container(
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: isReturning ? Colors.red[50] : Colors.amber[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: isReturning ? Colors.red.shade200 : Colors.amber.shade300)),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(isReturning ? Icons.assignment_return : Icons.security, color: isReturning ? Colors.red : Colors.amber, size: 24),
                    const SizedBox(width: 10),
                    Text(isReturning ? "كود استلام المرتجع: " : "كود تأكيد العهدة: ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, fontFamily: 'Cairo')),
                    Text(code, style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w900, color: isReturning ? Colors.red[900] : Colors.blue[900])),
                  ]),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Divider(thickness: 0.5)),
                  Text(isReturning ? "⚠️ لا تعطي هذا الكود للمندوب إلا بعد استلام البضاعة المرتجعة والتأكد من سلامتها تماماً." : "⚠️ تنبيه: إدخال المندوب لهذا الكود بمثابة توقيع إلكتروني باستلام العهدة وتأمين قيمتها.", textAlign: TextAlign.center, style: TextStyle(fontSize: 10.sp, color: Colors.black87, fontFamily: 'Cairo', fontWeight: FontWeight.w600, height: 1.4)),
                ],
              ),
            ),
          Row(
            children: [
              CircleAvatar(radius: 25, backgroundColor: Colors.grey[100], child: Icon(Icons.delivery_dining, color: mainColor)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(driver != null ? driver['fullname'] : "جاري التخصيص...", style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')), Text(driver != null ? "هاتف: ${driver['phone']}" : "تتبع مباشر", style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'Cairo'))])),
              if (driver != null) IconButton(onPressed: () async => await launchUrl(Uri.parse("tel:${driver['phone']}")), icon: Icon(Icons.phone_in_talk, color: mainColor, size: 30)),
            ],
          ),
        ],
      ),
    );
  }
}

