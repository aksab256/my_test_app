// lib/widgets/delivery_map_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_geojson/flutter_map_geojson.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

// 🛑 إعدادات Mapbox الجديدة
const String MAPBOX_ACCESS_TOKEN = 'pk.eyJ1IjoiYW1yc2hpcGwiLCJhIjoiY21lajRweGdjMDB0eDJsczdiemdzdXV6biJ9.E--si9vOB93NGcAq7uVgGw';
const String MAPBOX_STYLE_ID = 'mapbox/streets-v12'; // يمكنك استخدام light-v11 أو dark-v11 أيضاً

// الرابط الخاص بـ Mapbox Tiles
const String TILE_URL = 'https://api.mapbox.com/styles/v1/{id}/tiles/{z}/{x}/{y}?access_token={accessToken}';

const LatLng MAP_CENTER = LatLng(30.9, 28.5);
const double MAP_ZOOM = 5.5;
const String GEOJSON_FILE_PATH = 'assets/OSMB-bc319d822a17aa9ad1089fc05e7d4e752460f877.geojson';

class DeliveryMapView extends StatefulWidget {
  final Map<String, dynamic>? initialGeoJsonData;
  final List<String> initialSelectedAreas;
  final Function(List<String> selectedAreas) onAreasChanged;

  const DeliveryMapView({
    super.key,
    required this.initialGeoJsonData,
    required this.initialSelectedAreas,
    required this.onAreasChanged,
  });

  @override
  State<DeliveryMapView> createState() => _DeliveryMapViewState();
}

class _DeliveryMapViewState extends State<DeliveryMapView> {
  List<String> _selectedAreaNames = [];
  List<Polygon> _polygons = [];
  final MapController _mapController = MapController();
  Map<String, dynamic>? _geoJsonData;
  bool _isLoading = true;
  String? _loadingError;

  @override
  void initState() {
    super.initState();
    _selectedAreaNames = List.from(widget.initialSelectedAreas);
    _loadGeoJsonAndInitialize();
  }

  Future<void> _loadGeoJsonAndInitialize() async {
    _geoJsonData = widget.initialGeoJsonData;
    if (_geoJsonData == null) {
      try {
        final geoJsonString = await rootBundle.loadString(GEOJSON_FILE_PATH);
        _geoJsonData = jsonDecode(geoJsonString) as Map<String, dynamic>;
        _loadingError = null;
      } catch (e) {
        _loadingError = '❌ فشل تحميل ملف GeoJSON من الأصول.';
        print('FATAL ERROR: $e');
      }
    }

    setState(() {
      _isLoading = false;
      if (_geoJsonData != null) {
        _updateMapAndPolygons(_selectedAreaNames);
      }
    });
  }

  @override
  void didUpdateWidget(covariant DeliveryMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSelectedAreas != oldWidget.initialSelectedAreas) {
      _selectedAreaNames = List.from(widget.initialSelectedAreas);
      _updateMapAndPolygons(_selectedAreaNames);
    }
  }

  void _handleDropdownChange(List<String> newSelection) {
    setState(() {
      _selectedAreaNames = newSelection;
    });
    widget.onAreasChanged(newSelection);
    _updateMapAndPolygons(newSelection);
  }

  void _updateMapAndPolygons(List<String> areaNames) {
    if (_geoJsonData == null || areaNames.isEmpty) {
      setState(() => _polygons = []);
      return;
    }

    final selectedFeatures = (_geoJsonData!['features'] as List)
        .where((f) => areaNames.contains(f['properties']['name']))
        .toList();

    if (selectedFeatures.isEmpty) {
      setState(() => _polygons = []);
      return;
    }

    final geoJsonParser = GeoJsonParser(
      defaultPolygonBorderColor: const Color(0xff28a745),
      defaultPolygonFillColor: const Color(0xff28a745).withOpacity(0.5),
    );

    geoJsonParser.parseGeoJson({
      'type': 'FeatureCollection',
      'features': selectedFeatures
    });

    setState(() {
      _polygons = geoJsonParser.polygons;
    });

    final allPoints = _polygons.expand((p) => p.points).toList();
    if (allPoints.isNotEmpty) {
      final bounds = LatLngBounds.fromPoints(allPoints);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_loadingError != null) {
      return Center(child: Text(_loadingError!, style: const TextStyle(color: Colors.red)));
    }

    final List<dynamic> features = _geoJsonData!['features'] as List;
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
              decoration: InputDecoration(border: const OutlineInputBorder(), hintText: hintText),
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
            child: FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: MAP_CENTER,
                initialZoom: MAP_ZOOM,
              ),
              children: [
                // 🟢 تعديل الـ TileLayer لاستخدام Mapbox
                TileLayer(
                  urlTemplate: TILE_URL,
                  additionalOptions: {
                    'accessToken': MAPBOX_ACCESS_TOKEN,
                    'id': MAPBOX_STYLE_ID,
                  },
                  userAgentPackageName: 'com.example.app',
                  maxZoom: 19,
                ),
                PolygonLayer(
                  polygons: _polygons,
                  polygonCulling: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// الـ Widget المساعد (MultiSelectAreaDialog) يبقى كما هو دون تغيير...
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
      title: const Text('اختيار المناطق الإدارية'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.allAreas.length,
          itemBuilder: (context, index) {
            final item = widget.allAreas[index];
            return CheckboxListTile(
              value: _selectedItems.contains(item),
              title: Text(item),
              onChanged: (isChecked) {
                setState(() {
                  if (isChecked == true) _selectedItems.add(item);
                  else _selectedItems.remove(item);
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selectedItems),
          child: Text('حفظ (${_selectedItems.length})'),
        ),
      ],
    );
  }
}

