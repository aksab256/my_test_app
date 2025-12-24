// lib/screens/delivery_area_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/area_service.dart';
import '../widgets/delivery_map_view.dart';
import '../constants/delivery_constants.dart';

class DeliveryAreaScreen extends StatefulWidget {
  final String currentSellerId;
  final bool hasWriteAccess; // تم جعلها اختيارية لتجنب أخطاء الـ Navigation

  const DeliveryAreaScreen({
    super.key,
    required this.currentSellerId,
    this.hasWriteAccess = true, // 👈 القيمة الافتراضية هنا تحل مشكلة الـ Build
  });

  @override
  State<DeliveryAreaScreen> createState() => _DeliveryAreaScreenState();
}

class _DeliveryAreaScreenState extends State<DeliveryAreaScreen> {
  final AreaService _areaService = AreaService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. حالات إدارة البيانات
  Map<String, dynamic>? _geoJsonData;
  List<String> _selectedAreasFromDB = [];
  List<String> _currentSelectedAreas = [];

  // 2. حالات إدارة الـ UI
  bool _isLoading = true;
  bool _isSaving = false;
  String? _notificationMessage;
  Color _notificationColor = Colors.green;

  // ----------------------------------------------------------------------
  // LIFECYCLE & DATA LOADING
  // ----------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    // تحميل المناطق المحددة سابقاً من Firestore
    await _loadSelectedAreasFromDB();
    setState(() => _isLoading = false);
  }

  Future<void> _loadSelectedAreasFromDB() async {
    try {
      final sellerRef = _firestore.collection("sellers").doc(widget.currentSellerId);
      final sellerSnap = await sellerRef.get();

      if (sellerSnap.exists) {
        final data = sellerSnap.data();
        // استخدام الثابت الخاص بمجالات التوصيل
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

  // ----------------------------------------------------------------------
  // HANDLERS
  // ----------------------------------------------------------------------

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

    // بعد الحفظ، إعادة تحميل لضمان مزامنة حالة الـ UI
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
    // إخفاء الرسالة بعد 5 ثواني
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _notificationMessage = null);
      }
    });
  }


  // ----------------------------------------------------------------------
  // UI BUILDER
  // ----------------------------------------------------------------------

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

            // 🛑 حالة التحميل
            if (_isLoading)
              const Center(child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(color: Color(0xff28a745)),
              ))
            else
              DeliveryMapView(
                initialGeoJsonData: _geoJsonData,
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
