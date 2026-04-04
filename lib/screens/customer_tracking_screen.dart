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

  Future<void> _loadCustomMarker() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 150.0; 

    final Paint circlePaint = Paint()..color = Colors.blue[900]!.withOpacity(0.9);
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2.2, circlePaint);

    final Paint borderPaint = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 6;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2.2, borderPaint);

    TextPainter textPainter = TextPainter(textDirection: TextDirection.rtl);
    textPainter.text = TextSpan(
      text: String.fromCharCode(Icons.motorcycle.codePoint),
      style: TextStyle(fontSize: 90.0, fontFamily: Icons.motorcycle.fontFamily, color: Colors.white),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2));

    final ui.Image image = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    if (mounted) setState(() { _driverIcon = BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List()); });
  }

  void _calculateETA(LatLng driver, LatLng destination) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((destination.latitude - driver.latitude) * p) / 2 +
        c(driver.latitude * p) * c(destination.latitude * p) *
            (1 - c((destination.longitude - driver.longitude) * p)) / 2;
    double dist = 12742 * asin(sqrt(a));
    if (mounted) {
      setState(() {
        _distanceRemaining = dist < 1 ? "${(dist * 1000).toInt()} متر" : "${dist.toStringAsFixed(1)} كم";
        _estimatedTime = "${((dist / 30) * 60).round() + 2} دقيقة";
        _polylines.clear();
        _polylines.add(Polyline(polylineId: const PolylineId("r"), points: [driver, destination], color: Colors.blue.withAlpha(150), width: 5));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('specialRequests').doc(widget.orderId).snapshots(),
      builder: (context, orderSnapshot) {
        if (orderSnapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (!orderSnapshot.hasData || !orderSnapshot.data!.exists) return const Scaffold(body: Center(child: Text("جاري التحديث...")));

        var oData = orderSnapshot.data!.data() as Map<String, dynamic>;
        String status = oData['status'] ?? "pending";
        String? driverId = oData['driverId'];
        GeoPoint p = oData['pickupLocation']; GeoPoint d = oData['dropoffLocation'];
        LatLng pickup = LatLng(p.latitude, p.longitude); LatLng dropoff = LatLng(d.latitude, d.longitude);

        return StreamBuilder<DocumentSnapshot>(
          stream: (driverId != null && driverId.isNotEmpty) ? FirebaseFirestore.instance.collection('freeDrivers').doc(driverId).snapshots() : const Stream.empty(),
          builder: (context, driverSnapshot) {
            LatLng? dLoc;
            if (driverSnapshot.hasData && driverSnapshot.data!.exists) {
              var dd = driverSnapshot.data!.data() as Map<String, dynamic>;
              GeoPoint loc = dd['location'] ?? GeoPoint(dd['lat'], dd['lng']);
              dLoc = LatLng(loc.latitude, loc.longitude);
              if (!_hasInitialCenteringDone) { 
                 _mapController.future.then((c) => c.animateCamera(CameraUpdate.newLatLngZoom(dLoc!, 15)));
                 _hasInitialCenteringDone = true;
              }
              WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _calculateETA(dLoc!, status.contains('pickup') ? pickup : dropoff); });
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                extendBodyBehindAppBar: true,
                appBar: AppBar(backgroundColor: Colors.white.withAlpha(200), elevation: 0, title: const Text("تتبع رابية أحلى", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold))),
                body: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(target: pickup, zoom: 15),
                      onMapCreated: (c) { if (!_mapController.isCompleted) _mapController.complete(c); setState(() => _isMapCreated = true); },
                      polylines: _polylines,
                      markers: {
                        Marker(markerId: const MarkerId('p'), position: pickup, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)),
                        Marker(markerId: const MarkerId('d'), position: dropoff, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)),
                        if (dLoc != null) Marker(markerId: const MarkerId('dr'), position: dLoc, icon: _driverIcon ?? BitmapDescriptor.defaultMarker(), flat: true, anchor: const Offset(0.5, 0.5)),
                      },
                    ),
                    if (_isMapCreated) Align(alignment: Alignment.bottomCenter, child: Container(margin: const EdgeInsets.all(15), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text("المندوب: ${oData['driverName'] ?? "جاري البحث"}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text("الوقت المتوقع: $_estimatedTime", style: const TextStyle(color: Colors.blue)),
                    ])))
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

