import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' show cos, sqrt, asin;
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
  BitmapDescriptor? _driverIcon;
  double _driverRotation = 0;
  LatLng? _lastDriverPosition;
  String _estimatedTime = "";
  String _distanceRemaining = "";
  bool _isMapCreated = false;
  bool _hasInitialCenteringDone = false;
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _loadCustomMarker();
  }

  // دالة تحميل أيقونة الموتوسيكل وتصغير حجمها ليكون مناسباً للخريطة
  Future<void> _loadCustomMarker() async {
    try {
      // حاول تحميل صورة من الـ Assets لو موجودة، وإلا استخدم الافتراضي بأمان
      // ملاحظة: تأكد من إضافة صورة باسم 'assets/images/bike.png' في pubspec.yaml
      final Uint8List markerIcon = await getBytesFromAsset('assets/images/bike.png', 100);
      setState(() {
        _driverIcon = BitmapDescriptor.fromBytes(markerIcon);
      });
    } catch (e) {
      // لو الصورة مش موجودة، نستخدم السهم الأزرق لتمييز الحركة
      _driverIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
  }

  // دالة مساعدة لتصغير حجم الصورة برمجياً
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

    if (mounted) {
      setState(() {
        _distanceRemaining = distanceInKm < 1
            ? "${(distanceInKm * 1000).toInt()} متر"
            : "${distanceInKm.toStringAsFixed(1)} كم";
        _estimatedTime = "$travelMinutes دقيقة";
        
        _polylines.clear();
        _polylines.add(Polyline(
          polylineId: const PolylineId("route"),
          points: [driver, destination],
          color: Colors.blue.withAlpha(180),
          width: 5,
          jointType: JointType.round,
        ));
      });
    }
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
    if (!_isMapCreated || _hasInitialCenteringDone) return;
    try {
      final GoogleMapController controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newLatLngZoom(location, 15));
      _hasInitialCenteringDone = true; 
    } catch (e) {
      debugPrint("Map Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // حل مشكلة الشاشة السوداء: التأكد من وجود الـ ID
    if (widget.orderId.isEmpty) return const Scaffold(body: Center(child: Text("طلب غير موجود")));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('specialRequests').doc(widget.orderId).snapshots(),
      builder: (context, orderSnapshot) {
        // حماية ضد الشاشة السوداء في حالة الـ Loading أو الـ Null
        if (orderSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator()));
        }
        if (!orderSnapshot.hasData || !orderSnapshot.data!.exists) {
          return const Scaffold(body: Center(child: Text("جاري تحديث بيانات الطلب...")));
        }

        var orderData = orderSnapshot.data!.data() as Map<String, dynamic>;
        String status = orderData['status'] ?? "pending";
        String? driverId = orderData['driverId'];
        
        // جلب المواقع مع حماية الـ null
        GeoPoint pickup = orderData['pickupLocation'] ?? const GeoPoint(0, 0);
        GeoPoint dropoff = orderData['dropoffLocation'] ?? const GeoPoint(0, 0);
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

                LatLng destination = (status == 'accepted' || status == 'at_pickup') ? pickupLatLng : dropoffLatLng;
                
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
                  backgroundColor: Colors.white.withOpacity(0.85),
                  elevation: 0,
                  title: Text("تتبع رابية أحلى", style: TextStyle(fontFamily: 'Cairo', fontSize: 13.sp, fontWeight: FontWeight.bold)),
                  centerTitle: true,
                ),
                body: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(target: pickupLatLng, zoom: 15),
                      onMapCreated: (c) {
                        if (!_mapController.isCompleted) _mapController.complete(c);
                        if (mounted) setState(() => _isMapCreated = true);
                      },
                      polylines: _polylines,
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                      scrollGesturesEnabled: true, 
                      markers: {
                        Marker(
                          markerId: const MarkerId('pickup'),
                          position: pickupLatLng,
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                          infoWindow: const InfoWindow(title: "المتجر"),
                        ),
                        Marker(
                          markerId: const MarkerId('dropoff'),
                          position: dropoffLatLng,
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                          infoWindow: const InfoWindow(title: "موقعك"),
                        ),
                        if (driverLatLng != null)
                          Marker(
                            markerId: const MarkerId('driver'),
                            position: driverLatLng!,
                            rotation: _driverRotation,
                            // الأيقونة هنا هي الموتوسيكل اللي حملناه
                            icon: _driverIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                            anchor: const Offset(0.5, 0.5),
                            flat: true,
                          ),
                      },
                    ),

                    // الكروت تظهر فقط بعد تحميل الخريطة لتجنب الشاشة السوداء
                    if (_isMapCreated) ...[
                      if (_estimatedTime.isNotEmpty && status != 'delivered')
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 70,
                          left: 12,
                          right: 12,
                          child: _buildEtaCard(),
                        ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: _buildBottomPanel(status, orderData, driverData),
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

  Widget _buildEtaCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoItem("الوقت المتوقع", _estimatedTime, Icons.timer),
          Container(width: 1, height: 30, color: Colors.grey[200]),
          _buildInfoItem("المسافة", _distanceRemaining, Icons.motorcycle),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(children: [Icon(icon, size: 14, color: Colors.blue[900]), const SizedBox(width: 5), Text(label, style: TextStyle(fontFamily: 'Cairo', fontSize: 9.sp, color: Colors.grey))]),
        Text(value, style: TextStyle(fontFamily: 'Cairo', fontSize: 11.sp, fontWeight: FontWeight.bold, color: Colors.blue[900])),
      ],
    );
  }

  Widget _buildBottomPanel(String status, Map<String, dynamic> order, Map<String, dynamic>? driver) {
    double progress = 0.1;
    String statusDesc = "بانتظار المندوب...";
    Color statusColor = Colors.orange;

    if (status == 'accepted') { progress = 0.4; statusDesc = "المندوب في طريقه للمحل"; statusColor = Colors.blue; }
    else if (status == 'at_pickup') { progress = 0.6; statusDesc = "المندوب يقوم بالاستلام"; statusColor = Colors.indigo; }
    else if (status == 'picked_up') { progress = 0.8; statusDesc = "الطلب في الطريق إليك"; statusColor = Colors.green; }
    else if (status == 'delivered') { progress = 1.0; statusDesc = "تم التسليم بنجاح"; statusColor = Colors.teal; }

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15)]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: progress, color: statusColor, backgroundColor: Colors.grey[100], minHeight: 6),
            const SizedBox(height: 15),
            
            if (status != 'delivered' && order.containsKey('verificationCode'))
              _buildCodeSnippet(order['verificationCode'].toString()),

            Text(statusDesc, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12.sp, color: statusColor)),
            const Divider(height: 30),
            
            Row(
              children: [
                CircleAvatar(backgroundColor: Colors.blue[50], child: Icon(Icons.person, color: Colors.blue[900])),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order['driverName'] ?? "جاري التخصيص...", style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                      if (order.containsKey('insurance_points'))
                        Text("تأمين عهدة: ${order['insurance_points']} ج.م", style: TextStyle(fontFamily: 'Cairo', fontSize: 9.sp, color: Colors.grey)),
                    ],
                  ),
                ),
                if (driver != null)
                  IconButton(onPressed: () => launchUrl(Uri.parse("tel:${driver['phone']}")), icon: const Icon(Icons.phone, color: Colors.green)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeSnippet(String code) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.blue[900], borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("كود تأمين العهدة", style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 10.sp)),
          Text(code, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14.sp, color: Colors.white, letterSpacing: 2)),
        ],
      ),
    );
  }
}

