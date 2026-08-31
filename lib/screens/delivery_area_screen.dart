// lib/screens/delivery_area_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/area_service.dart';
import '../widgets/delivery_map_view.dart';
import '../constants/delivery_constants.dart';

// نموذج تكوين المحافظات (قابل للتوسع بسهولة)
class GovernorateConfig {
  final String id;
  final String name;
  final String assetPath;
  final LatLng center;

  const GovernorateConfig({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.center,
  });
}

// قائمة المحافظات المتاحة حالياً (يمكن إضافة أي محافظة إضافية هنا مستقبلاً)
final List<GovernorateConfig> availableGovernorates = [
  const GovernorateConfig(
    id: 'alexandria',
    name: 'الإسكندرية',
    assetPath: 'assets/OSMB-bc319d822a17aa9ad1089fc05e7d4e752460f877.geojson',
    center: LatLng(31.2001, 29.9187),
  ),
  const GovernorateConfig(
    id: 'buhayrah',
    name: 'البحيرة',
    assetPath: 'assets/governorates/AlBuhayrah.json',
    center: LatLng(31.0379, 30.4725),
  ),
];

class DeliveryAreaScreen extends StatefulWidget {
  final String currentSellerId;
  final bool hasWriteAccess;

  const DeliveryAreaScreen({
    super.key,
    required this.currentSellerId,
    this.hasWriteAccess = true,
  });

  @override
  State<DeliveryAreaScreen> createState() => _DeliveryAreaScreenState();
}

class _DeliveryAreaScreenState extends State<DeliveryAreaScreen> {
  final AreaService _areaService = AreaService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // المحافظة المختارة حالياً (الافتراضية الإسكندرية)
  late GovernorateConfig _selectedGovernorate;

  // 1. حالات إدارة البيانات
  List<String> _selectedAreasFromDB = [];
  List<String> _currentSelectedAreas = [];

  // 2. حالات إدارة الـ UI
  bool _isLoading = true;
  bool _isSaving = false;
  String? _notificationMessage;
  Color _notificationColor = Colors.green;

  @override
  void initState() {
    super.initState();
    _selectedGovernorate = availableGovernorates.first;
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    await _loadSelectedAreasFromDB();
    setState(() => _isLoading = false);
  }

  Future<void> _loadSelectedAreasFromDB() async {
    try {
      final sellerRef = _firestore.collection("sellers").doc(widget.currentSellerId);
      final sellerSnap = await sellerRef.get();

      if (sellerSnap.exists) {
        final data = sellerSnap.data();
        final List<dynamic> areas = data?[FIRESTORE_DELIVERY_AREAS_FIELD] ?? [];

        setState(() {
          _selectedAreasFromDB = areas.cast<String>();
          _currentSelectedAreas = List.from(_selectedAreasFromDB);
          _showNotification('⭐ تم تحميل ${_selectedAreasFromDB.length} مناطق محددة سابقاً.', isError: false);
        });
      }
    } catch (e) {
      _showNotification('❌ فشل تحميل مناطق التوصيل المحفوظة.', isError: true);
    }
  }

  void _updateCurrentSelection(List<String> selectedAreas) {
    setState(() {
      _currentSelectedAreas = selectedAreas;
    });
  }

  Future<void> _saveAreas() async {
    if (!widget.hasWriteAccess) {
      _showNotification('🚫 ليس لديك صلاحية التعديل.', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    _showNotification('⏳ جاري الحفظ والتحديث...', isError: false);

    final result = await _areaService.saveSellerAreas(
      sellerId: widget.currentSellerId,
      selectedAreaNames: _currentSelectedAreas,
    );

    await _loadSelectedAreasFromDB();

    if (result['success']) {
      _showNotification(result['message'], isError: false);
    } else {
      _showNotification(result['message'], isError: true);
    }

    setState(() => _isSaving = false);
  }

  void _showNotification(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _notificationMessage = message;
      _notificationColor = isError ? Colors.red : const Color(0xff28a745);
    });
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _notificationMessage = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تحديد مناطق التوصيل'),
        backgroundColor: const Color(0xff28a745),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🛑 شريط الإشعارات
            if (_notificationMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _notificationColor.withOpacity(0.1),
                  border: Border.all(color: _notificationColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _notificationMessage!,
                  style: TextStyle(color: _notificationColor, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),

            if (!widget.hasWriteAccess)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  border: Border.all(color: Colors.amber),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '🚫 وضع العرض فقط: ليس لديك صلاحية التعديل.',
                  style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),

            // 🛑 اختيار المحافظة (Dropdown)
            const Text(
              'اختر المحافظة:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<GovernorateConfig>(
              value: _selectedGovernorate,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: availableGovernorates.map((gov) {
                return DropdownMenuItem<GovernorateConfig>(
                  value: gov,
                  child: Text(gov.name),
                );
              }).toList(),
              onChanged: (GovernorateConfig? newGov) {
                if (newGov != null && newGov != _selectedGovernorate) {
                  setState(() {
                    _selectedGovernorate = newGov;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // 🛑 حالة التحميل وتمرير ملف المحافظة إلى الـ Map View
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(color: Color(0xff28a745)),
                ),
              )
            else
              DeliveryMapView(
                key: ValueKey(_selectedGovernorate.id),
                geoJsonAssetPath: _selectedGovernorate.assetPath,
                mapCenter: _selectedGovernorate.center,
                initialSelectedAreas: _selectedAreasFromDB,
                onAreasChanged: _updateCurrentSelection,
              ),

            const SizedBox(height: 20),

            // 🛑 زر الحفظ
            ElevatedButton.icon(
              onPressed: (_isSaving || !widget.hasWriteAccess) ? null : _saveAreas,
              icon: _isSaving
                  ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save, color: Colors.white),
              label: Text(
                _isSaving ? 'جاري الحفظ...' : 'حفظ مناطق التوصيل',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff28a745),
                minimumSize: const Size(double.infinity, 50),
                disabledBackgroundColor: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}