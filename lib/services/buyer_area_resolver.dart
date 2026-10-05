// lib/services/buyer_area_resolver.dart
//
// يحول GPS المشتري إلى أسماء مناطق (delivery-area names) باستخدام نفس ملفات
// GeoJSON ونفس أولويات استخراج الأسماء ونفس منطق المضلعات المستخدم في
// TradersScreen/DeliveryMapView — بدون اختراع نظام موقع جديد وبدون إضافة
// محافظات (لا Gharbia، لا coverage جديدة).

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:my_test_app/constants/delivery_constants.dart';
import 'package:my_test_app/utils/offer_geo_filter.dart';

/// أولوية استخراج اسم المنطقة — مطابقة لـ DeliveryMapView.
String? extractAreaName(Map<String, dynamic> properties) {
  const List<String> priorityKeys = [
    'name',
    'name:ar',
    'shapeName',
    'ADM3_AR',
    'ADM2_AR',
    'NL_NAME_2',
    'NAME_2',
    'localname',
    'NAME_3',
    'NL_NAME_3',
    'ADM1_AR',
    'ADM3_EN',
    'ADM2_EN',
    'name:en',
    'name_ar',
    'name_en',
  ];
  for (final key in priorityKeys) {
    final value = properties[key];
    if (value != null) {
      final text = value.toString().trim();
      if (text.isNotEmpty && text != 'NA') return text;
    }
  }
  return null;
}

/// يبني خريطة (اسم المنطقة -> مضلع) من GeoJSON خام. يدعم Polygon
/// و MultiPolygon. نقي وقابل للاختبار.
Map<String, List<GeoPoint>> parseGeoJsonAreas(Map<String, dynamic> geoJson) {
  final Map<String, List<GeoPoint>> result = {};
  final dynamic features = geoJson['features'];
  if (features is! List) return result;
  for (final feature in features) {
    if (feature is! Map<String, dynamic>) continue;
    final properties = feature['properties'];
    final geometry = feature['geometry'];
    if (properties is! Map<String, dynamic> || geometry is! Map) continue;
    final areaName = extractAreaName(properties);
    if (areaName == null) continue;

    List? ring;
    final type = geometry['type'];
    final coordinates = geometry['coordinates'];
    try {
      if (type == 'MultiPolygon') {
        ring = (coordinates as List)[0][0] as List;
      } else if (type == 'Polygon') {
        ring = (coordinates as List)[0] as List;
      } else {
        continue;
      }
    } catch (_) {
      continue;
    }
    final polygon = <GeoPoint>[];
    for (final coord in ring) {
      if (coord is List && coord.length >= 2) {
        final lng = (coord[0] as num).toDouble();
        final lat = (coord[1] as num).toDouble();
        polygon.add(GeoPoint(lat: lat, lng: lng));
      }
    }
    if (polygon.length >= 3) {
      result[areaName] = polygon;
    }
  }
  return result;
}

/// يحمّل polygons كل المحافظات المدعومة حاليًا (نفس خريطة الثوابت) مع cache.
class BuyerAreaResolver {
  static Map<String, List<GeoPoint>>? _cache;

  /// للاختبار/إعادة التحميل فقط.
  static void clearCache() => _cache = null;

  static Future<Map<String, List<GeoPoint>>> loadAreaPolygons() async {
    if (_cache != null) return _cache!;
    final Map<String, List<GeoPoint>> all = {};
    for (final entry in GOVERNORATE_GEOJSON_PATHS.entries) {
      try {
        final jsonString = await rootBundle.loadString(entry.value);
        final data = json.decode(jsonString) as Map<String, dynamic>;
        all.addAll(parseGeoJsonAreas(data));
      } catch (_) {
        // ملف غير متاح — يُتجاهل مثل TradersScreen، بدون كسر باقي المحافظات.
      }
    }
    _cache = all;
    return all;
  }

  /// مناطق المشتري المكتشفة من GPS. مشترٍ بلا إحداثيات -> قائمة فارغة
  /// (يرى الـGlobal فقط — نفس قاعدة TradersScreen للموقع المجهول).
  static Future<List<String>> resolveBuyerAreas({
    required double? lat,
    required double? lng,
  }) async {
    if (lat == null || lng == null) return const [];
    final polygons = await loadAreaPolygons();
    return resolveAreasForPoint(GeoPoint(lat: lat, lng: lng), polygons);
  }
}
