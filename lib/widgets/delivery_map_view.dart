// lib/widgets/delivery_map_view.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class DeliveryMapView extends StatefulWidget {
  final String geoJsonAssetPath;
  final LatLng mapCenter;
  final List<String> initialSelectedAreas;
  final Function(List<String> selectedAreas) onAreasChanged;

  const DeliveryMapView({
    super.key,
    required this.geoJsonAssetPath,
    required this.mapCenter,
    required this.initialSelectedAreas,
    required this.onAreasChanged,
  });

  @override
  State<DeliveryMapView> createState() => _DeliveryMapViewState();
}

class _DeliveryMapViewState extends State<DeliveryMapView> {
  List<String> _selectedAreaNames = [];
  Set<Polygon> _gMapsPolygons = {};
  GoogleMapController? _mapController;
  Map<String, dynamic>? _geoJsonData;
  bool _isLoading = true;
  String? _loadingError;

  @override
  void initState() {
    super.initState();
    _selectedAreaNames = List.from(widget.initialSelectedAreas);
    _loadGeoJsonAndInitialize();
  }

  @override
  void didUpdateWidget(covariant DeliveryMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // إذا تغير مسار المحافظة يقوم بتحميل الملف الجديد فوراً
    if (widget.geoJsonAssetPath != oldWidget.geoJsonAssetPath) {
      _loadGeoJsonAndInitialize();
    } else if (widget.initialSelectedAreas != oldWidget.initialSelectedAreas) {
      _selectedAreaNames = List.from(widget.initialSelectedAreas);
      _updateMapAndPolygons(_selectedAreaNames);
    }
  }

  Future<void> _loadGeoJsonAndInitialize() async {
    setState(() {
      _isLoading = true;
      _loadingError = null;
    });

    try {
      final geoJsonString = await rootBundle.loadString(widget.geoJsonAssetPath);
      _geoJsonData = jsonDecode(geoJsonString) as Map<String, dynamic>;
    } catch (e) {
      _loadingError = '❌ فشل تحميل خريطة المحافظة.';
      debugPrint('ERROR Loading GeoJSON: $e');
    }

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (_geoJsonData != null) {
        _parseGeoJsonToGooglePolygons(_selectedAreaNames);
      }
    });

    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(widget.mapCenter),
      );
    }
  }

  void _handleDropdownChange(List<String> newSelection) {
    setState(() {
      _selectedAreaNames = newSelection;
    });
    widget.onAreasChanged(newSelection);
    _updateMapAndPolygons(newSelection);
  }

  void _parseGeoJsonToGooglePolygons(List<String> areaNames) {
    if (_geoJsonData == null || areaNames.isEmpty) {
      setState(() => _gMapsPolygons = {});
      return;
    }

    Set<Polygon> newPolygons = {};
    try {
      final features = _geoJsonData!['features'] as List;
      for (var feature in features) {
        final String? name = feature['properties']['name'];
        if (name != null && areaNames.contains(name)) {
          final geometry = feature['geometry'];
          if (geometry['type'] == 'Polygon') {
            final List coords = geometry['coordinates'][0];
            List<LatLng> polygonPoints = coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();

            newPolygons.add(
              Polygon(
                polygonId: PolygonId(name),
                points: polygonPoints,
                fillColor: const Color(0xff28a745).withOpacity(0.3),
                strokeColor: const Color(0xff28a745),
                strokeWidth: 2,
              ),
            );
          } else if (geometry['type'] == 'MultiPolygon') {
            final List multiCoords = geometry['coordinates'];
            for (int i = 0; i < multiCoords.length; i++) {
              final List coords = multiCoords[i][0];
              List<LatLng> polygonPoints = coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();

              newPolygons.add(
                Polygon(
                  polygonId: PolygonId("${name}_$i"),
                  points: polygonPoints,
                  fillColor: const Color(0xff28a745).withOpacity(0.3),
                  strokeColor: const Color(0xff28a745),
                  strokeWidth: 2,
                ),
              );
            }
          }
        }
      }
      setState(() => _gMapsPolygons = newPolygons);
    } catch (e) {
      debugPrint('Error parsing GeoJson for Google Maps: $e');
    }
  }

  void _updateMapAndPolygons(List<String> areaNames) {
    _parseGeoJsonToGooglePolygons(areaNames);

    if (_mapController != null && _gMapsPolygons.isNotEmpty) {
      _fitMapToPolygons();
    }
  }

  void _fitMapToPolygons() {
    if (_gMapsPolygons.isEmpty || _mapController == null) return;

    double? minLat, maxLat, minLng, maxLng;

    for (var polygon in _gMapsPolygons) {
      for (var point in polygon.points) {
        if (minLat == null || point.latitude < minLat) minLat = point.latitude;
        if (maxLat == null || point.latitude > maxLat) maxLat = point.latitude;
        if (minLng == null || point.longitude < minLng) minLng = point.longitude;
        if (maxLng == null || point.longitude > maxLng) maxLng = point.longitude;
      }
    }

    if (minLat != null && maxLat != null && minLng != null && maxLng != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          50.0,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_loadingError != null) {
      return Center(child: Text(_loadingError!, style: const TextStyle(color: Colors.red)));
    }

    final List<dynamic> features = _geoJsonData!['features'] as List? ?? [];
    final List<String> allAreaNames = features
        .map((f) => f['properties']['name'] as String?)
        .where((name) => name != null && name.isNotEmpty)
        .cast<String>()
        .toList();

    final String hintText = allAreaNames.isEmpty
        ? '⚠️ لم يتم استخراج أي مناطق.'
        : 'تم اختيار ${_selectedAreaNames.length} مناطق من أصل ${allAreaNames.length}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('اختيار مناطق التوصيل:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            if (allAreaNames.isEmpty) return;
            final List<String>? result = await showDialog<List<String>>(
              context: context,
              builder: (context) => MultiSelectAreaDialog(
                allAreas: allAreaNames,
                initialSelection: _selectedAreaNames,
              ),
            );
            if (result != null) _handleDropdownChange(result);
          },
          child: IgnorePointer(
            child: DropdownButtonFormField<String>(
              value: null,
              decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: hintText,
                  hintStyle: const TextStyle(fontSize: 14)),
              items: const [],
              onChanged: (_) {},
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 400,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: widget.mapCenter,
                zoom: 10.0,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                if (_selectedAreaNames.isNotEmpty) {
                  _fitMapToPolygons();
                }
              },
              polygons: _gMapsPolygons,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              mapType: MapType.normal,
            ),
          ),
        ),
      ],
    );
  }
}

class MultiSelectAreaDialog extends StatefulWidget {
  final List<String> allAreas;
  final List<String> initialSelection;
  const MultiSelectAreaDialog({super.key, required this.allAreas, required this.initialSelection});

  @override
  State<MultiSelectAreaDialog> createState() => _MultiSelectAreaDialogState();
}

class _MultiSelectAreaDialogState extends State<MultiSelectAreaDialog> {
  final List<String> _selectedItems = [];
  @override
  void initState() {
    super.initState();
    _selectedItems.addAll(widget.initialSelection);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('اختيار المناطق الإدارية', textAlign: TextAlign.right),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.allAreas.length,
          itemBuilder: (context, index) {
            final item = widget.allAreas[index];
            return CheckboxListTile(
              activeColor: const Color(0xff28a745),
              value: _selectedItems.contains(item),
              title: Text(item, textAlign: TextAlign.right),
              onChanged: (isChecked) {
                setState(() {
                  if (isChecked == true) {
                    _selectedItems.add(item);
                  } else {
                    _selectedItems.remove(item);
                  }
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff28a745)),
          onPressed: () => Navigator.pop(context, _selectedItems),
          child: Text('حفظ (${_selectedItems.length})', style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}