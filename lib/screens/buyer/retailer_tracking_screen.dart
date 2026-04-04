import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' show cos, sqrt, asin;
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
  bool _hasInitialCenteringDone = false;

  // إضافات التتبع والموتوسيكل
  BitmapDescriptor? _driverIcon;
  double _driverRotation = 0;
  LatLng? _lastDriverPosition;
  final Set<Polyline> _polylines = {};
  String _estimatedTime = "";
  String _distanceRemaining = "";

  @override
  void initState() {
    super.initState();
    _loadCustomMarker();
  }

  Future<void> _loadCustomMarker() async {
    try {
      // تحميل أيقونة الموتوسيكل من الـ Assets
      final Uint8List markerIcon = await getBytesFromAsset('assets/images/bike.png', 110);
      setState(() {
        _driverIcon = BitmapDescriptor.fromBytes(markerIcon);
      });
    } catch (e) {
      // أيقونة احتياطية في حالة عدم وجود الصورة
      _driverIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  }

  void _calculateETA(LatLng driver, LatLng destination) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((destination.latitude - driver.latitude) * p) / 2 +
        c(driver.latitude * p) * c(destination.latitude * p) *
            (1 - c((destination.longitude - driver.longitude) * p)) / 2;

    double distanceInKm = 12742 * asin(sqrt(a));
    int travelMinutes = ((distanceInKm / 30) * 60).round() + 2;

    if (!mounted) return;
    setState(() {
      _distanceRemaining = distanceInKm < 1
          ? "${(distanceInKm * 1000).toInt()} متر"
          : "${distanceInKm.toStringAsFixed(1)} كم";
      _estimatedTime = "$travelMinutes دقيقة";

      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId("route"),
          points: [driver, destination],
          color: Colors.blue.withAlpha(150),
          width: 6,
          jointType: JointType.round,
        ),
      );
    });
  }

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

  Future<void> _animateCameraOnce(LatLng location) async {
    if (!_isMapReady || _hasInitialCenteringDone) return;
    try {
      final GoogleMapController controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newLatLngZoom(location, 15.5));
      _hasInitialCenteringDone = true; 
    } catch (e) {
      debugPrint("Map Error: $e");
    }
  }

  Future<void> _handleRetailerCancel(BuildContext context, String currentStatus, String? originalOrderId) async {
    bool isAccepted = currentStatus != 'pending';
    bool confirm = await showDialog(
          context: context,
          builder: (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("إلغاء الطلب", style: TextStyle(fontFamily: 'Cairo')),
              content: Text(
                  isAccepted
                      ? "المندوب وافق وهو في الطريق. الإلغاء الآن قد يخصم نقاط تأمين كتعويض. هل أنت متأكد؟"
                      : "هل تريد إلغاء البحث عن مندوب؟",
                  style: const TextStyle(fontFamily: 'Cairo')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("تراجع")),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("تأكيد", style: TextStyle(color: Colors.red, fontFamily: 'Cairo'))),
              ],
            ),
          ),
        ) ?? false;

    if (!confirm) return;
    try {
      await FirebaseFirestore.instance.collection('specialRequests').doc(widget.orderId).update({
        'status': isAccepted ? 'cancelled_by_retailer_after_accept' : 'cancelled_by_retailer_before_accept',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': 'retailer'
      });
      if (originalOrderId != null) {
        await FirebaseFirestore.instance.collection('consumerorders').doc(originalOrderId).update({'specialRequestId': FieldValue.delete()});
      }
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) { debugPrint("Cancel Error: $e"); }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.orderId.isEmpty) return const Scaffold(body: Center(child: Text("ID غير صالح")));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('specialRequests').doc(widget.orderId).snapshots(),
      builder: (context, orderSnapshot) {
        // حماية الشاشة السوداء
        if (orderSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator()));
        }
        if (!orderSnapshot.hasData || !orderSnapshot.data!.exists) {
          return const Scaffold(body: Center(child: Text("جاري جلب البيانات...")));
        }

        var orderData = orderSnapshot.data!.data() as Map<String, dynamic>;
        String status = orderData['status'] ?? "pending";
        String? originalOrderId = orderData['originalOrderId'];
        bool isReturning = status == 'returning_to_seller';

        // كود التحقق (المرتجع أو العهدة)
        String verificationCode = isReturning 
            ? (orderData['returnVerificationCode']?.toString() ?? "----") 
            : (orderData['verificationCode']?.toString() ?? "----");

        if (status.contains('cancelled_by') || status == 'delivered') {
          WidgetsBinding.instance.addPostFrameCallback((_) { if (context.mounted) Navigator.of(context).pop(); });
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
              if (driverData.containsKey('location')) {
                GeoPoint dLoc = driverData['location'];
                driverLatLng = LatLng(dLoc.latitude, dLoc.longitude);
              } else if (driverData.containsKey('lat')) {
                driverLatLng = LatLng(driverData['lat'], driverData['lng']);
              }

              if (driverLatLng != null) {
                if (_lastDriverPosition != null && _lastDriverPosition != driverLatLng) {
                  _driverRotation = _calculateRotation(_lastDriverPosition!, driverLatLng!);
                }
                _lastDriverPosition = driverLatLng;
                _animateCameraOnce(driverLatLng!);

                LatLng destination = (status == 'accepted' || status == 'at_pickup' || isReturning) ? pickupLatLng : dropoffLatLng;
                
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _calculateETA(driverLatLng!, destination);
                });
              }
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                extendBodyBehindAppBar: true,
                appBar: AppBar(
                  backgroundColor: Colors.white.withOpacity(0.8),
                  elevation: 0,
                  title: Text(isReturning ? "متابعة المرتجع" : "تتبع عهدة النقل",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, color: isReturning ? Colors.red[900] : Colors.black, fontFamily: 'Cairo')),
                  centerTitle: true,
                  actions: [
                    if (status == 'pending' || status == 'accepted' || status == 'at_pickup')
                      IconButton(icon: const Icon(Icons.cancel_outlined, color: Colors.red), onPressed: () => _handleRetailerCancel(context, status, originalOrderId))
                  ],
                ),
                body: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(target: pickupLatLng, zoom: 15.0),
                      onMapCreated: (c) {
                        if (!_mapController.isCompleted) _mapController.complete(c);
                        if (mounted) setState(() => _isMapReady = true);
                      },
                      polylines: _polylines,
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                      markers: {
                        Marker(markerId: const MarkerId('pickup'), position: pickupLatLng, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)),
                        Marker(markerId: const MarkerId('dropoff'), position: dropoffLatLng, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)),
                        if (driverLatLng != null)
                          Marker(
                            markerId: const MarkerId('driver'),
                            position: driverLatLng!,
                            rotation: _driverRotation,
                            icon: _driverIcon ?? BitmapDescriptor.defaultMarkerWithHue(isReturning ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueAzure),
                            anchor: const Offset(0.5, 0.5),
                            flat: true,
                          ),
                      },
                    ),

                    if (_isMapReady) ...[
                      if (_estimatedTime.isNotEmpty && status != 'pending')
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 75,
                          left: 15,
                          right: 15,
                          child: _buildInfoCard(),
                        ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: _buildRetailerBottomPanel(status, orderData, driverData, verificationCode, isReturning),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoItem("وصول المندوب", _estimatedTime, Icons.access_time),
          Container(width: 1, height: 30, color: Colors.grey[200]),
          _buildInfoItem("المسافة الحالية", _distanceRemaining, Icons.motorcycle),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(children: [
      Row(children: [Icon(icon, size: 14, color: Colors.blue[800]), const SizedBox(width: 5), Text(label, style: TextStyle(fontSize: 9.sp, fontFamily: 'Cairo', color: Colors.grey))]),
      Text(value, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: Colors.blue[900], fontFamily: 'Cairo')),
    ]);
  }

  Widget _buildRetailerBottomPanel(String status, Map<String, dynamic> order, Map<String, dynamic>? driver, String code, bool isReturning) {
    double progress = 0.1;
    String statusDesc = "جاري البحث عن مندوب...";
    Color mainColor = isReturning ? Colors.red : Colors.orange;

    if (isReturning) { progress = 0.9; statusDesc = "المرتجع في عهدة المندوب إليك"; mainColor = Colors.red[900]!; }
    else if (status == 'accepted') { progress = 0.4; statusDesc = "تم تخصيص مندوب للاستلام"; mainColor = Colors.blue; }
    else if (status == 'at_pickup') { progress = 0.6; statusDesc = "المندوب في نقطة الاستلام"; mainColor = Colors.indigo; }
    else if (status == 'picked_up') { progress = 0.8; statusDesc = "العهدة قيد التوصيل للعميل"; mainColor = Colors.green; }

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(15, 0, 15, 10),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 15)]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: progress, minHeight: 6, color: mainColor, backgroundColor: Colors.grey[100]),
            const SizedBox(height: 15),
            
            if (status == 'accepted' || status == 'at_pickup' || isReturning)
              _buildVerificationBlock(code, isReturning),

            Text(statusDesc, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, color: mainColor, fontFamily: 'Cairo')),
            const Divider(height: 25),
            
            Row(
              children: [
                CircleAvatar(backgroundColor: Colors.blue[50], child: Icon(Icons.person, color: mainColor)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order['driverName'] ?? "جاري التخصيص...", style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                      if (order.containsKey('insurance_points'))
                        Text("نقاط تأمين العهدة: ${order['insurance_points']}", style: TextStyle(fontSize: 9.sp, color: Colors.grey, fontFamily: 'Cairo')),
                    ],
                  ),
                ),
                if (driver != null) 
                  IconButton(onPressed: () => launchUrl(Uri.parse("tel:${driver['phone']}")), icon: Icon(Icons.phone, color: mainColor, size: 28)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationBlock(String code, bool isReturning) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: isReturning ? Colors.red[50] : Colors.blue[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: isReturning ? Colors.red.shade100 : Colors.blue.shade100)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isReturning ? "كود استلام المرتجع:" : "كود تأمين العهدة:", style: TextStyle(fontFamily: 'Cairo', fontSize: 10.sp)),
              Text(code, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900, color: isReturning ? Colors.red[900] : Colors.blue[900])),
            ],
          ),
          Text(isReturning ? "لا تعطِ الكود إلا بعد فحص المرتجع." : "تزويد المندوب بالكود يعني تسليمه العهدة.", style: TextStyle(fontSize: 8.sp, color: Colors.grey[700], fontFamily: 'Cairo')),
        ],
      ),
    );
  }
}

