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

  // رسم الموتوسيكل برمجياً (بدون صور خارجية)
  Future<void> _loadCustomMarker() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 150.0; 

    final Paint circlePaint = Paint()..color = Colors.indigo.withOpacity(0.9);
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2.2, circlePaint);

    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2.2, borderPaint);

    TextPainter textPainter = TextPainter(textDirection: TextDirection.rtl);
    textPainter.text = TextSpan(
      text: String.fromCharCode(Icons.motorcycle.codePoint),
      style: TextStyle(
        fontSize: 90.0,
        fontFamily: Icons.motorcycle.fontFamily,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2));

    final ui.Image image = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    if (mounted) {
      setState(() {
        _driverIcon = BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
      });
    }
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
      _distanceRemaining = distanceInKm < 1 ? "${(distanceInKm * 1000).toInt()} متر" : "${distanceInKm.toStringAsFixed(1)} كم";
      _estimatedTime = "$travelMinutes دقيقة";
      _polylines.clear();
      _polylines.add(Polyline(polylineId: const PolylineId("route"), points: [driver, destination], color: Colors.blue.withAlpha(150), width: 6));
    });
  }

  double _calculateRotation(LatLng start, LatLng end) {
    double latDiff = (end.latitude - start.latitude).abs();
    double lngDiff = (end.longitude - start.longitude).abs();
    double rotation = 0;
    if (start.latitude < end.latitude && start.longitude < end.longitude) rotation = (57.2957795 * (ui.Offset(lngDiff, latDiff).direction));
    else if (start.latitude >= end.latitude && start.longitude < end.longitude) rotation = 90 + (57.2957795 * (ui.Offset(latDiff, lngDiff).direction));
    else if (start.latitude >= end.latitude && start.longitude >= end.longitude) rotation = 180 + (57.2957795 * (ui.Offset(lngDiff, latDiff).direction));
    else if (start.latitude < end.latitude && start.longitude >= end.longitude) rotation = 270 + (57.2957795 * (ui.Offset(latDiff, lngDiff).direction));
    return rotation;
  }

  Future<void> _animateCameraOnce(LatLng location) async {
    if (!_isMapReady || _hasInitialCenteringDone) return;
    try {
      final GoogleMapController controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newLatLngZoom(location, 15.5));
      _hasInitialCenteringDone = true; 
    } catch (e) { debugPrint("Map Error: $e"); }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('specialRequests').doc(widget.orderId).snapshots(),
      builder: (context, orderSnapshot) {
        if (orderSnapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (!orderSnapshot.hasData || !orderSnapshot.data!.exists) return const Scaffold(body: Center(child: Text("جاري جلب البيانات...")));

        var orderData = orderSnapshot.data!.data() as Map<String, dynamic>;
        String status = orderData['status'] ?? "pending";
        bool isReturning = status == 'returning_to_seller';
        String vCode = isReturning ? (orderData['returnVerificationCode']?.toString() ?? "----") : (orderData['verificationCode']?.toString() ?? "----");

        String? driverId = orderData['driverId'];
        GeoPoint pLoc = orderData['pickupLocation'];
        GeoPoint dLoc = orderData['dropoffLocation'];
        LatLng pickup = LatLng(pLoc.latitude, pLoc.longitude);
        LatLng dropoff = LatLng(dLoc.latitude, dLoc.longitude);

        return StreamBuilder<DocumentSnapshot>(
          stream: (driverId != null && driverId.isNotEmpty) ? FirebaseFirestore.instance.collection('freeDrivers').doc(driverId).snapshots() : const Stream.empty(),
          builder: (context, driverSnapshot) {
            LatLng? driverLatLng;
            Map<String, dynamic>? dData;

            if (driverSnapshot.hasData && driverSnapshot.data!.exists) {
              dData = driverSnapshot.data!.data() as Map<String, dynamic>;
              GeoPoint loc = dData['location'] ?? (dData.containsKey('lat') ? GeoPoint(dData['lat'], dData['lng']) : const GeoPoint(0,0));
              driverLatLng = LatLng(loc.latitude, loc.longitude);

              if (_lastDriverPosition != null && _lastDriverPosition != driverLatLng) _driverRotation = _calculateRotation(_lastDriverPosition!, driverLatLng);
              _lastDriverPosition = driverLatLng;
              _animateCameraOnce(driverLatLng);
              
              LatLng target = (status == 'accepted' || status == 'at_pickup' || isReturning) ? pickup : dropoff;
              WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _calculateETA(driverLatLng!, target); });
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                extendBodyBehindAppBar: true,
                appBar: AppBar(backgroundColor: Colors.white.withOpacity(0.8), elevation: 0, title: Text(isReturning ? "متابعة المرتجع" : "تتبع عهدة النقل", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isReturning ? Colors.red[900] : Colors.black))),
                body: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(target: pickup, zoom: 15.0),
                      onMapCreated: (c) { if (!_mapController.isCompleted) _mapController.complete(c); setState(() => _isMapReady = true); },
                      polylines: _polylines,
                      markers: {
                        Marker(markerId: const MarkerId('p'), position: pickup, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)),
                        Marker(markerId: const MarkerId('d'), position: dropoff, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)),
                        if (driverLatLng != null) Marker(markerId: const MarkerId('dr'), position: driverLatLng, rotation: _driverRotation, icon: _driverIcon ?? BitmapDescriptor.defaultMarker(), anchor: const Offset(0.5, 0.5), flat: true),
                      },
                    ),
                    if (_isMapReady) ...[
                      if (_estimatedTime.isNotEmpty && status != 'pending') Positioned(top: 100, left: 15, right: 15, child: _buildInfoCard()),
                      Align(alignment: Alignment.bottomCenter, child: _buildBottomPanel(status, orderData, dData, vCode, isReturning)),
                    ]
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoCard() => Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [Column(children: [Text("الوصول خلال", style: TextStyle(fontSize: 8.sp, color: Colors.grey)), Text(_estimatedTime, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[900]))]), Column(children: [Text("المسافة", style: TextStyle(fontSize: 8.sp, color: Colors.grey)), Text(_distanceRemaining, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[900]))])]));

  Widget _buildBottomPanel(String s, Map<String, dynamic> o, Map<String, dynamic>? d, String c, bool r) {
    Color color = r ? Colors.red : Colors.orange;
    return Container(margin: const EdgeInsets.all(15), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)]), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(r ? "كود استلام المرتجع: $c" : "كود تأمين العهدة: $c", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, color: color)),
      const Divider(),
      Row(children: [const CircleAvatar(child: Icon(Icons.person)), const SizedBox(width: 10), Expanded(child: Text(o['driverName'] ?? "جاري البحث...")), if (d != null) IconButton(onPressed: () => launchUrl(Uri.parse("tel:${d['phone']}")), icon: const Icon(Icons.phone, color: Colors.green))])
    ]));
  }
}

