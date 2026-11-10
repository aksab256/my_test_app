// lib/screens/seller/create_gift_promo_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_test_app/screens/seller/manage_gift_promos_screen.dart';
import 'package:my_test_app/utils/gift_value.dart';

/// Phase 2 (AND): one extra required-purchase line selected by the seller.
/// The base line keeps using the screen's single-line fields; extras are
/// appended (max 4 extras = 5 lines total, matching the agreed design cap).
class _ExtraTriggerLine {
  String? offerId;
  int unitIndex = 0;
  final TextEditingController qty;

  _ExtraTriggerLine() : qty = TextEditingController();
}

class CreateGiftPromoScreen extends StatefulWidget {
  final String currentSellerId;
  const CreateGiftPromoScreen({super.key, required this.currentSellerId});

  @override
  State<CreateGiftPromoScreen> createState() => _CreateGiftPromoScreenState();
}

class _CreateGiftPromoScreenState extends State<CreateGiftPromoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _promoNameController = TextEditingController();
  final _minOrderValueController = TextEditingController();
  final _triggerQtyBaseController = TextEditingController();
  final _giftQtyPerBaseController = TextEditingController(text: "1");
  final _promoQuantityController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final List<_ExtraTriggerLine> _extraLines = [];

  String _triggerType = 'min_order';
  String? _selectedTriggerOfferId;
  String? _selectedGiftOfferId;
  int _selectedTriggerUnitIndex = 0;
  int _selectedGiftUnitIndex = 0;
  List<Map<String, dynamic>> _availableOffers = [];
  bool _isLoading = false;

  void _addExtraLine() {
    if (_extraLines.length >= 4) {
      _showSnackBar("الحد الأقصى 5 منتجات في العرض الواحد", isError: true);
      return;
    }
    final line = _ExtraTriggerLine();
    line.qty.addListener(_refreshQuote);
    setState(() => _extraLines.add(line));
  }

  void _removeExtraLine(int index) {
    final removed = _extraLines.removeAt(index);
    removed.qty.dispose();
    _refreshQuote();
  }

  bool get _isMultiLine =>
      _triggerType == 'specific_item' && _extraLines.isNotEmpty;

  bool _validateExtraLines() {
    if (_extraLines.isEmpty) return true;
    if (_triggerType != 'specific_item') return true;
    if (_extraLines.length > 4) {
      _showSnackBar("الحد الأقصى 5 منتجات في العرض الواحد", isError: true);
      return false;
    }
    if (_selectedTriggerOfferId == null) {
      _showSnackBar("اختر المنتج الأساسي أولًا", isError: true);
      return false;
    }
    final seen = <String>{};
    seen.add('$_selectedTriggerOfferId||$_selectedTriggerUnitIndex');
    for (var i = 0; i < _extraLines.length; i++) {
      final line = _extraLines[i];
      final qty = int.tryParse(line.qty.text) ?? 0;
      if (line.offerId == null || qty <= 0) {
        _showSnackBar("أكمل المنتج الإضافي رقم ${i + 1}: المنتج والكمية", isError: true);
        return false;
      }
      if (!seen.add('${line.offerId}||${line.unitIndex}')) {
        _showSnackBar("المنتج الإضافي رقم ${i + 1} مكرر — اختر منتجًا أو وحدة مختلفة", isError: true);
        return false;
      }
    }
    return true;
  }

  Map<String, dynamic> _lineMap(String? offerId, int unitIndex, int qtyBase) {
    final offer = _availableOffers.firstWhere((o) => o['id'] == offerId);
    final List unitsMeta = offer['units'] as List? ?? [];
    final int idx = unitsMeta.isEmpty ? 0 : unitIndex.clamp(0, unitsMeta.length - 1);
    final double? unitPrice = unitsMeta.isEmpty ? ((offer['offerPrice']) as num?)?.toDouble() : (((unitsMeta[idx] as Map)['price']) as num?)?.toDouble();
    final String unitName = unitsMeta.isEmpty ? ((offer['unitName'])?.toString() ?? 'وحدة') : ((((unitsMeta[idx] as Map)['unitName'])?.toString()) ?? 'وحدة');
    return {
      'type': 'specific_item',
      'offerId': offerId,
      'productName': offer['productName'],
      'unitName': unitName,
      'unitIndex': idx,
      'triggerUnitPrice': unitPrice,
      'triggerQuantityBase': qtyBase,
    };
  }

  List<Map<String, dynamic>> _triggerLinesForDoc() {
    final lines = <Map<String, dynamic>>[
      _lineMap(_selectedTriggerOfferId, _selectedTriggerUnitIndex, int.parse(_triggerQtyBaseController.text)),
    ];
    for (final line in _extraLines) {
      lines.add(_lineMap(line.offerId, line.unitIndex, int.parse(line.qty.text)));
    }
    return lines;
  }

  void _refreshQuote() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _triggerQtyBaseController.addListener(_refreshQuote);
    _giftQtyPerBaseController.addListener(_refreshQuote);
    _minOrderValueController.addListener(_refreshQuote);
    _fetchSellerOffers();
  }

  @override
  void dispose() {
    _promoNameController.dispose();
    _minOrderValueController.dispose();
    _triggerQtyBaseController.dispose();
    _giftQtyPerBaseController.dispose();
    _promoQuantityController.dispose();
    _expiryDateController.dispose();
    for (final line in _extraLines) {
      line.qty.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchSellerOffers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('productOffers')
          .where('sellerId', isEqualTo: widget.currentSellerId)
          .get();

      final offers = snapshot.docs.map((doc) {
        final data = doc.data();
        final List units = data['units'] as List? ?? [];
        final unit0 = units.isNotEmpty ? units[0] : {};

        return {
          'id': doc.id,
          'productName': data['productName'] ?? 'بدون اسم',
          'productId': data['productId'] ?? doc.id,
          'imageUrl': data['imageUrl'] ?? '',
          'availableStock': unit0['availableStock'] ?? 0,
          'offerPrice': unit0['price'] ?? 0,
          'unitName': unit0['unitName'] ?? 'الوحدة الرئيسية',
          'units': units.map((u) {
            final Map um = u as Map;
            return {
              'unitName': um['unitName'] ?? 'وحدة',
              'price': um['price'] ?? 0,
              'availableStock': um['availableStock'] ?? 0,
            };
          }).toList(),
        };
      }).toList();

      if (mounted) {
        setState(() {
          _availableOffers = offers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar("خطأ في تحميل العروض: $e", isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createGiftPromo() async {
    if (!_formKey.currentState!.validate() || _selectedGiftOfferId == null) {
      _showSnackBar("الرجاء استكمال البيانات واختيار الهدية", isError: true);
      return;
    }
    if (!_validateExtraLines()) {
      return;
    }
    /* Phase 2: the duplicated legacy guard below is intentionally disabled —
       _validateExtraLines() above is the single validation point.
      _showSnackBar("الرجاء استكمال البيانات واختيار الهدية", isError: true);
      return;
    }
    */
    setState(() => _isLoading = true);
    try {
      final selectedGiftOffer = _availableOffers.firstWhere((o) => o['id'] == _selectedGiftOfferId);
      final int totalPromoQuantity = int.parse(_promoQuantityController.text);
      final List giftUnitsMeta = selectedGiftOffer['units'] as List? ?? [];
      final int giftUnitIdx = giftUnitsMeta.isEmpty ? 0 : _selectedGiftUnitIndex.clamp(0, giftUnitsMeta.length - 1);
      final String giftUnitName = giftUnitsMeta.isEmpty
          ? (selectedGiftOffer['unitName']?.toString() ?? 'وحدة')
          : (((giftUnitsMeta[giftUnitIdx] as Map)['unitName'])?.toString() ?? 'وحدة');
      final GiftValueQuote valueQuote = _currentQuote();
      final double giftPriceSnapshot = ((giftUnitsMeta.isEmpty
              ? selectedGiftOffer['offerPrice']
              : (giftUnitsMeta[giftUnitIdx] as Map)['price']) as num?)?.toDouble() ?? 0.0;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final giftRef = FirebaseFirestore.instance.collection('productOffers').doc(_selectedGiftOfferId);
        final giftDoc = await transaction.get(giftRef);

        if (!giftDoc.exists) throw "وثيقة الهدية غير موجودة";
        final data = giftDoc.data()!;
        List units = List.from(data['units'] ?? []);
        final int giftUnitIdxTxn = units.isEmpty ? 0 : giftUnitIdx.clamp(0, units.length - 1);
        Map unit0 = Map.from(units[giftUnitIdxTxn]);
        int currentAvailableStock = (unit0['availableStock'] ?? 0).toInt();

        if (currentAvailableStock < totalPromoQuantity) {
          throw "الرصيد غير كافٍ! المتاح حالياً: $currentAvailableStock";
        }

        unit0['availableStock'] = currentAvailableStock - totalPromoQuantity;
        unit0['reservedForPromos'] = (unit0['reservedForPromos'] ?? 0) + totalPromoQuantity;
        unit0['updatedAt'] = DateTime.now().toIso8601String();
        units[giftUnitIdxTxn] = unit0;

        final double? triggerUnitPriceForDoc = _triggerType == 'specific_item'
            ? _selectedUnitPrice(_selectedTriggerOfferId, _selectedTriggerUnitIndex)
            : null;
        final promoRef = FirebaseFirestore.instance.collection('giftPromos').doc();
        Map<String, dynamic> triggerCondition = {};
        if (_triggerType == 'min_order') {
          triggerCondition = {
            'type': 'min_order',
            'value': double.parse(_minOrderValueController.text)
          };
        } else {
          final triggerOffer = _availableOffers.firstWhere((o) => o['id'] == _selectedTriggerOfferId);
          final List triggerUnitsMeta = triggerOffer['units'] as List? ?? [];
          final int triggerUnitIdx = triggerUnitsMeta.isEmpty ? 0 : _selectedTriggerUnitIndex.clamp(0, triggerUnitsMeta.length - 1);
          final double? triggerUnitPrice = triggerUnitsMeta.isEmpty ? null : (((triggerUnitsMeta[triggerUnitIdx] as Map)['price']) as num?)?.toDouble();
          final String triggerUnitName = triggerUnitsMeta.isEmpty ? (triggerOffer['unitName']?.toString() ?? 'وحدة') : (((triggerUnitsMeta[triggerUnitIdx] as Map)['unitName'])?.toString() ?? 'وحدة');
          triggerCondition = {
            'type': 'specific_item',
            'offerId': _selectedTriggerOfferId,
            'productName': triggerOffer['productName'],
            'unitName': triggerUnitName,
            'unitIndex': triggerUnitIdx,
            'triggerUnitPrice': triggerUnitPrice,
            'triggerQuantityBase': int.parse(_triggerQtyBaseController.text)
          };
        }

        transaction.set(promoRef, {
          'sellerId': widget.currentSellerId,
          'promoName': _promoNameController.text,
          'giftOfferId': _selectedGiftOfferId,
          'giftProductName': selectedGiftOffer['productName'],
          'giftUnitName': giftUnitName,
          'giftUnitIndex': giftUnitIdx,
          'giftQuantityPerBase': int.parse(_giftQtyPerBaseController.text),
          'giftOfferPriceSnapshot': giftPriceSnapshot,
          'giftUnitPrice': giftPriceSnapshot,
          'triggerUnitPrice': triggerUnitPriceForDoc,
          'requiredPurchaseValue': valueQuote.available ? valueQuote.requiredPurchaseValue : null,
          'giftValue': valueQuote.available ? valueQuote.giftValue : null,
          'giftValuePercentage': valueQuote.available ? valueQuote.percentage : null,
          'valueStatus': valueQuote.available ? 'ok' : 'value_unavailable',
          'giftProductId': selectedGiftOffer['productId'],
          'giftProductImage': selectedGiftOffer['imageUrl'],
          'trigger': triggerCondition,
          if (_isMultiLine) 'triggers': _triggerLinesForDoc(),
          if (_isMultiLine) 'matchMode': 'all',
          'expiryDate': DateTime.parse(_expiryDateController.text).toIso8601String(),
          'maxQuantity': totalPromoQuantity,
          'usedQuantity': 0,
          'reservedQuantity': 0,
          'status': 'active',
          'isNotified': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.update(giftRef, {'units': units});
      });

      _showSnackBar("🎉 تم حجز المخزن وإنشاء العرض بنجاح!");
      _formKey.currentState?.reset();
      _promoNameController.clear();
      _promoQuantityController.clear();
      _selectedGiftOfferId = null;
      _selectedTriggerOfferId = null;
      for (final line in _extraLines) {
        line.qty.dispose();
      }
      _extraLines.clear();
      _selectedGiftUnitIndex = 0;
      _selectedTriggerUnitIndex = 0;
      _fetchSellerOffers();
    } catch (e) {
      _showSnackBar(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  TextStyle get _cairoStyle => GoogleFonts.cairo(fontWeight: FontWeight.bold);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F1),
      appBar: AppBar(
        title: Text("إنشاء عرض هدايا", style: _cairoStyle.copyWith(fontSize: 18.sp, color: Colors.white)),
        backgroundColor: const Color(0xFF1B5E20),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.inventory_2_outlined, color: Colors.white, size: 22.sp),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ManageGiftPromosScreen(currentSellerId: widget.currentSellerId))),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.only(bottom: 6.h),
              decoration: const BoxDecoration(
                color: Color(0xFF1B5E20),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
              ),
              child: Center(
                child: Text("كافئ عملائك وزد من مبيعاتك اليوم", 
                  style: _cairoStyle.copyWith(color: Colors.white70, fontSize: 13.sp, fontWeight: FontWeight.normal)),
              ),
            ),
            
            Transform.translate(
              offset: Offset(0, -4.h),
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 4.w),
                padding: EdgeInsets.all(20.sp),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: const Offset(0, 10))]
                ),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel("📦 بيانات الحملة"),
                      _buildTextField(_promoNameController, "اسم العرض (مثال: عرض الجمعة)", Icons.campaign),
                      _buildDatePicker(),
                      
                      const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(thickness: 1.2)),
                      _sectionLabel("⚖️ شروط الاستحقاق"),
                      _buildDropdown("متى يستحق العميل الهدية؟", {
                        'min_order': 'عند الوصول لمبلغ فاتورة معين',
                        'specific_item': 'عند شراء منتج محدد'
                      }, (val) => setState(() => _triggerType = val!)),
                      
                      if (_triggerType == 'min_order')
                        _buildTextField(_minOrderValueController, "مبلغ الفاتورة الأدنى (ج.م)", Icons.payments, isNumber: true),
                      
                      if (_triggerType == 'specific_item') ...[
                        _buildOfferPicker("اختر المنتج المطلوب شراؤه", (id) => setState(() { _selectedTriggerOfferId = id; _selectedTriggerUnitIndex = 0; })),
                        _buildUnitDropdown("وحدة الشرط المطلوبة", _unitsOf(_selectedTriggerOfferId), _selectedTriggerUnitIndex, (v) => setState(() => _selectedTriggerUnitIndex = v)),
                        _buildTextField(_triggerQtyBaseController, "الكمية المطلوبة من هذا المنتج", Icons.shopping_cart_checkout, isNumber: true),
                      ],

                      const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(thickness: 1.2)),
                      if (_triggerType == 'specific_item') ...[
                        if (_extraLines.isEmpty)
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: _addExtraLine,
                              icon: Icon(Icons.add_circle_outline, size: 18.sp),
                              label: Text("اشتراط منتج آخر معه (AND)", style: _cairoStyle.copyWith(fontSize: 13.sp)),
                            ),
                          ),
                        for (var i = 0; i < _extraLines.length; i++)
                          Container(
                            margin: EdgeInsets.only(bottom: 2.h),
                            padding: EdgeInsets.all(10.sp),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.green.shade200),
                              color: Colors.green.shade50,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("منتج إضافي ${i + 2} (يجب شراؤه أيضًا)",
                                        style: _cairoStyle.copyWith(fontSize: 13.sp, color: Colors.green[900])),
                                    IconButton(
                                      icon: Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20.sp),
                                      onPressed: () => _removeExtraLine(i),
                                    ),
                                  ],
                                ),
                                _buildOfferPicker("اختر المنتج الإضافي", (id) => setState(() {
                                      _extraLines[i].offerId = id;
                                      _extraLines[i].unitIndex = 0;
                                    })),
                                _buildUnitDropdown("وحدة المنتج الإضافي", _unitsOf(_extraLines[i].offerId), _extraLines[i].unitIndex, (v) => setState(() => _extraLines[i].unitIndex = v)),
                                _buildTextField(_extraLines[i].qty, "الكمية المطلوبة من المنتج الإضافي", Icons.shopping_cart_checkout, isNumber: true),
                              ],
                            ),
                          ),
                        if (_extraLines.isNotEmpty && _extraLines.length < 4)
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: _addExtraLine,
                              icon: Icon(Icons.add_circle_outline, size: 18.sp),
                              label: Text("إضافة منتج آخر (AND)", style: _cairoStyle.copyWith(fontSize: 13.sp)),
                            ),
                          ),
                      ],
                      _sectionLabel("🎁 تفاصيل الهدية"),
                      _buildOfferPicker("اختر المنتج الذي سيُقدم كهدية", (id) => setState(() { _selectedGiftOfferId = id; _selectedGiftUnitIndex = 0; })),
                      _buildUnitDropdown("وحدة الهدية", _unitsOf(_selectedGiftOfferId), _selectedGiftUnitIndex, (v) => setState(() => _selectedGiftUnitIndex = v)),
                      
                      Row(
                        children: [
                          Expanded(child: _buildTextField(_giftQtyPerBaseController, "كمية الهدية", Icons.card_giftcard, isNumber: true)),
                          SizedBox(width: 4.w),
                          Expanded(child: _buildTextField(_promoQuantityController, "إجمالي الهدايا المتاحة", Icons.inventory, isNumber: true)),
                        ],
                      ),
                      
                      SizedBox(height: 4.h),
                      _buildValueSummary(),
                      SizedBox(height: 2.h),
                      _buildSubmitButton(),
                      SizedBox(height: 1.h),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: EdgeInsets.only(bottom: 12.sp, top: 5.sp),
    child: Text(text, style: _cairoStyle.copyWith(fontSize: 15.sp, color: Colors.green[900])),
  );

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {bool isNumber = false}) => Padding(
    padding: EdgeInsets.only(bottom: 2.h),
    child: TextFormField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: _cairoStyle.copyWith(fontSize: 14.sp, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: _cairoStyle.copyWith(fontSize: 12.sp, color: Colors.grey[700]),
        prefixIcon: Icon(icon, color: Colors.green[800], size: 18.sp),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: EdgeInsets.symmetric(vertical: 2.h, horizontal: 5.w),
      ),
      validator: (v) => (v == null || v.isEmpty) ? "هذا الحقل مطلوب" : null,
    ),
  );

  Widget _buildDatePicker() => Padding(
    padding: EdgeInsets.only(bottom: 2.h),
    child: TextFormField(
      controller: _expiryDateController,
      readOnly: true,
      style: _cairoStyle.copyWith(fontSize: 14.sp, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: "تاريخ انتهاء العرض",
        labelStyle: _cairoStyle.copyWith(fontSize: 12.sp, color: Colors.grey[700]),
        prefixIcon: Icon(Icons.event_available, color: Colors.redAccent, size: 18.sp),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      onTap: () async {
        DateTime? picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now().add(const Duration(days: 1)),
          firstDate: DateTime.now(),
          lastDate: DateTime(2030),
        );
        if (picked != null) {
          String formattedDate = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
          setState(() => _expiryDateController.text = formattedDate);
        }
      },
      validator: (v) => (v == null || v.isEmpty) ? "برجاء تحديد التاريخ" : null,
    ),
  );

  Widget _buildDropdown(String label, Map<String, String> items, Function(String?) onChanged) => Padding(
    padding: EdgeInsets.only(bottom: 2.h),
    child: DropdownButtonFormField<String>(
      style: _cairoStyle.copyWith(color: Colors.black, fontSize: 13.sp, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: _cairoStyle.copyWith(fontSize: 12.sp),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      value: _triggerType,
      items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: _cairoStyle.copyWith(fontSize: 13.sp)))).toList(),
      onChanged: onChanged,
    ),
  );

  List<Map<String, dynamic>> _unitsOf(String? offerId) {
    if (offerId == null) return [];
    try {
      final offer = _availableOffers.firstWhere((o) => o['id'] == offerId);
      final List raw = offer['units'] as List? ?? [];
      return raw.map((u) {
        final Map um = u as Map;
        return {
          'unitName': (um['unitName'])?.toString() ?? 'وحدة',
          'availableStock': um['availableStock'] ?? 0,
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Widget _buildUnitDropdown(String label, List<Map<String, dynamic>> units, int value, Function(int) onChanged) => Padding(
    padding: EdgeInsets.only(bottom: 2.h),
    child: DropdownButtonFormField<int>(
      isExpanded: true,
      hint: Text(label, style: _cairoStyle.copyWith(fontSize: 13.sp, fontWeight: FontWeight.normal)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: _cairoStyle.copyWith(fontSize: 12.sp),
        prefixIcon: Icon(Icons.straighten_outlined, color: Colors.teal, size: 18.sp),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      value: units.isEmpty ? null : value.clamp(0, units.length - 1),
      items: units.asMap().entries.map((e) => DropdownMenuItem(
        value: e.key,
        child: Text("${e.value['unitName']} (المتاح: ${e.value['availableStock']})", style: _cairoStyle.copyWith(fontSize: 13.sp)),
      )).toList(),
      onChanged: (v) { if (v != null) onChanged(v); },
      validator: (v) => units.isEmpty ? "اختر المنتج أولًا" : null,
    ),
  );

  double? _selectedUnitPrice(String? offerId, int unitIndex) {
    if (offerId == null) return null;
    try {
      final offer = _availableOffers.firstWhere((o) => o['id'] == offerId);
      final List raw = offer['units'] as List? ?? [];
      if (raw.isEmpty) {
        return (offer['offerPrice'] as num?)?.toDouble();
      }
      final int idx = unitIndex.clamp(0, raw.length - 1);
      return ((raw[idx] as Map)['price'] as num?)?.toDouble();
    } catch (_) {
      return null;
    }
  }

  /// الحاسبة الحية: قيمة المشتريات المطلوبة مقابل قيمة الهدية والنسبة.
  /// تُحسب من أسعار الوحدات المختارة فعليًا — لا أرقام مخترعة.
  GiftValueQuote _currentQuote() {
    final giftPrice = _selectedUnitPrice(_selectedGiftOfferId, _selectedGiftUnitIndex);
    final giftQty = int.tryParse(_giftQtyPerBaseController.text) ?? 0;
    if (_triggerType == 'min_order') {
      final threshold = double.tryParse(_minOrderValueController.text);
      if (threshold == null || giftPrice == null || giftQty <= 0) {
        return const GiftValueQuote.unavailable();
      }
      final gv = giftPrice * giftQty;
      if (threshold <= 0) {
        return gv <= 0
            ? const GiftValueQuote.available(requiredPurchaseValue: 0, giftValue: 0, percentage: 0)
            : const GiftValueQuote.unavailable();
      }
      return GiftValueQuote.available(
        requiredPurchaseValue: threshold,
        giftValue: gv,
        percentage: gv / threshold * 100,
      );
    }
    final triggerPrice = _selectedUnitPrice(_selectedTriggerOfferId, _selectedTriggerUnitIndex);
    final triggerQty = int.tryParse(_triggerQtyBaseController.text) ?? 0;
    if (_extraLines.isNotEmpty) {
      return quoteAndGiftValue(
        triggerLines: [
          (unitPrice: triggerPrice, qty: triggerQty),
          for (final line in _extraLines)
            (
              unitPrice: _selectedUnitPrice(line.offerId, line.unitIndex),
              qty: int.tryParse(line.qty.text) ?? 0
            ),
        ],
        giftUnitPrice: giftPrice,
        giftQty: giftQty,
      );
    }
    return quoteSingleGiftValue(
      triggerUnitPrice: triggerPrice,
      triggerQty: triggerQty,
      giftUnitPrice: giftPrice,
      giftQty: giftQty,
    );
  }

  Widget _buildValueSummary() {
    final q = _currentQuote();
    final String text = q.available
        ? "قيمة المشتريات المطلوبة: ${q.requiredPurchaseValue!.toStringAsFixed(2)} ج\nقيمة الهدية التقديرية: ${q.giftValue!.toStringAsFixed(2)} ج\nنسبة الهدية: ${q.percentage!.toStringAsFixed(2)} %"
        : "قيمة الهدية: غير متاحة — أكمل اختيار المنتج والوحدة والكميات والأسعار";
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.sp),
      decoration: BoxDecoration(
        color: q.available ? const Color(0xffe8f5e9) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: q.available ? Colors.green : Colors.grey.shade400),
      ),
      child: Text(
        text,
        style: _cairoStyle.copyWith(fontSize: 12.sp, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Widget _buildOfferPicker(String label, Function(String?) onSelected) => Padding(
    padding: EdgeInsets.only(bottom: 2.h),
    child: DropdownButtonFormField<String>(
      isExpanded: true,
      hint: Text(label, style: _cairoStyle.copyWith(fontSize: 13.sp, fontWeight: FontWeight.normal)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: _cairoStyle.copyWith(fontSize: 12.sp),
        prefixIcon: Icon(Icons.shopping_bag_outlined, color: Colors.orange, size: 18.sp),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      items: _availableOffers.map((o) => DropdownMenuItem(
        value: o['id'].toString(),
        child: Text("${o['productName']} (المتاح: ${o['availableStock']})", style: _cairoStyle.copyWith(fontSize: 13.sp)),
      )).toList(),
      onChanged: onSelected,
      validator: (v) => v == null ? "برجاء اختيار منتج" : null,
    ),
  );

  Widget _buildSubmitButton() => SizedBox(
    width: double.infinity,
    height: 8.h,
    child: ElevatedButton(
      onPressed: _isLoading ? null : _createGiftPromo,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1B5E20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 6,
      ),
      child: _isLoading
        ? const CircularProgressIndicator(color: Colors.white)
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bolt, color: Colors.yellow, size: 20.sp),
              SizedBox(width: 3.w),
              Text("حجز البضاعة وتفعيل العرض", style: _cairoStyle.copyWith(color: Colors.white, fontSize: 16.sp)),
            ],
          ),
    ),
  );

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: _cairoStyle.copyWith(fontSize: 13.sp, color: Colors.white)),
      backgroundColor: isError ? Colors.redAccent : Colors.green[800],
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.all(15.sp),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ));
  }
}

