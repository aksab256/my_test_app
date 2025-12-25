// lib/screens/seller/create_gift_promo_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

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

  String _triggerType = 'min_order';
  String? _selectedTriggerOfferId;
  String? _selectedGiftOfferId;
  List<Map<String, dynamic>> _availableOffers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchSellerOffers();
  }

  Future<void> _fetchSellerOffers() async {
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
        };
      }).toList();

      setState(() {
        _availableOffers = offers;
        _isLoading = false;
      });
    } catch (e) {
      _showSnackBar("خطأ في تحميل العروض: $e", isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createGiftPromo() async {
    if (!_formKey.currentState!.validate() || _selectedGiftOfferId == null) {
      _showSnackBar("الرجاء استكمال البيانات واختيار الهدية", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final selectedGiftOffer = _availableOffers.firstWhere((o) => o['id'] == _selectedGiftOfferId);
      final int totalPromoQuantity = int.parse(_promoQuantityController.text);
      final double giftPriceSnapshot = (selectedGiftOffer['offerPrice'] as num).toDouble();

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final giftRef = FirebaseFirestore.instance.collection('productOffers').doc(_selectedGiftOfferId);
        final giftDoc = await transaction.get(giftRef);

        if (!giftDoc.exists) throw "وثيقة الهدية غير موجودة";

        final data = giftDoc.data()!;
        List units = List.from(data['units'] ?? []);
        if (units.isEmpty) throw "بنية بيانات العرض غير صالحة (Units empty)";

        // ✅ معالجة حجز المخزن - مطابق لمنطق الـ HTML تماماً
        Map unit0 = Map.from(units[0]);
        int currentAvailableStock = (unit0['availableStock'] ?? 0).toInt();

        if (currentAvailableStock < totalPromoQuantity) {
          throw "الرصيد غير كافٍ! المتاح حالياً: $currentAvailableStock";
        }

        unit0['availableStock'] = currentAvailableStock - totalPromoQuantity;
        unit0['reservedForPromos'] = (unit0['reservedForPromos'] ?? 0) + totalPromoQuantity;
        unit0['updatedAt'] = DateTime.now().toIso8601String();
        units[0] = unit0;

        // ✅ بناء الـ Promo مع ضمان حقول اللمدا
        final promoRef = FirebaseFirestore.instance.collection('giftPromos').doc();
        Map<String, dynamic> triggerCondition = {};
        
        if (_triggerType == 'min_order') {
          triggerCondition = {
            'type': 'min_order',
            'value': double.parse(_minOrderValueController.text)
          };
        } else {
          final triggerOffer = _availableOffers.firstWhere((o) => o['id'] == _selectedTriggerOfferId);
          triggerCondition = {
            'type': 'specific_item',
            'offerId': _selectedTriggerOfferId,
            'productName': triggerOffer['productName'],
            'unitName': triggerOffer['unitName'],
            'triggerQuantityBase': int.parse(_triggerQtyBaseController.text)
          };
        }

        transaction.set(promoRef, {
          'sellerId': widget.currentSellerId,
          'promoName': _promoNameController.text,
          'giftOfferId': _selectedGiftOfferId,
          'giftProductName': selectedGiftOffer['productName'],
          'giftUnitName': selectedGiftOffer['unitName'],
          'giftQuantityPerBase': int.parse(_giftQtyPerBaseController.text),
          'giftOfferPriceSnapshot': giftPriceSnapshot,
          'giftProductId': selectedGiftOffer['productId'],
          'giftProductImage': selectedGiftOffer['imageUrl'],
          'trigger': triggerCondition,
          'expiryDate': DateTime.parse(_expiryDateController.text).toIso8601String(),
          'maxQuantity': totalPromoQuantity,
          'usedQuantity': 0, // ثابت
          'reservedQuantity': 0, // ثابت
          'status': 'active',
          'isNotified': false, // جاهز للمدا
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.update(giftRef, {'units': units});
      });

      // ✅ إصلاح قفلة الكود لضمان النجاح قبل الخروج
      _showSnackBar("🎉 تم حجز المخزن وإنشاء الهدية بنجاح!");
      
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);

    } catch (e) {
      _showSnackBar(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI Methods مع خط Cairo ---
  TextStyle get _cairoStyle => GoogleFonts.cairo(fontWeight: FontWeight.bold);

  Widget _buildCard(List<Widget> children) => Card(
    elevation: 3,
    margin: EdgeInsets.only(bottom: 12.sp),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    child: Padding(padding: EdgeInsets.all(12.sp), child: Column(children: children)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("إنشاء هدايا ترويجية", style: _cairoStyle.copyWith(fontSize: 16.sp)),
        backgroundColor: const Color(0xFF1B5E20),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : SingleChildScrollView(
              padding: EdgeInsets.all(12.sp),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildCard([
                      _buildTextField(_promoNameController, "اسم العرض (مثل: هدية الزيت)", Icons.campaign),
                      _buildDatePicker(),
                    ]),
                    _buildCard([
                      _buildDropdown("نوع تفعيل الهدية", {
                        'min_order': 'عند الوصول لمبلغ فاتورة معين',
                        'specific_item': 'عند شراء منتج محدد'
                      }, (val) => setState(() => _triggerType = val!)),
                      if (_triggerType == 'min_order')
                        _buildTextField(_minOrderValueController, "المبلغ المطلوب (ج.م)", Icons.payments, isNumber: true),
                      if (_triggerType == 'specific_item') ...[
                        _buildOfferPicker("المنتج الذي يجب شراؤه", (id) => _selectedTriggerOfferId = id),
                        _buildTextField(_triggerQtyBaseController, "الكمية المطلوبة للتفعيل", Icons.shopping_basket, isNumber: true),
                      ]
                    ]),
                    _buildCard([
                      _buildOfferPicker("اختر الهدية التي ستُمنح", (id) => _selectedGiftOfferId = id),
                      _buildTextField(_giftQtyPerBaseController, "كمية الهدية لكل استحقاق", Icons.card_giftcard, isNumber: true),
                      _buildTextField(_promoQuantityController, "إجمالي الهدايا المتاحة (سيتم حجزها من المخزن)", Icons.inventory, isNumber: true),
                    ]),
                    SizedBox(height: 20.sp),
                    ElevatedButton(
                      onPressed: _createGiftPromo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[800],
                        minimumSize: Size(100.w, 55.sp),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text("تأكيد الحجز وإنشاء العرض", style: _cairoStyle.copyWith(color: Colors.white, fontSize: 14.sp)),
                    )
                  ],
                ),
              ),
            ),
    );
  }

  // UI Helpers (تعديل الخطوط)
  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {bool isNumber = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextFormField(
      controller: ctrl,
      style: _cairoStyle,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: _cairoStyle.copyWith(color: Colors.grey[700]),
        prefixIcon: Icon(icon, color: Colors.green),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: (v) => v!.isEmpty ? "هذا الحقل مطلوب" : null,
    ),
  );

  Widget _buildDropdown(String label, Map<String, String> items, Function(String?) onChanged) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: DropdownButtonFormField<String>(
      style: _cairoStyle.copyWith(color: Colors.black),
      decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
      value: items.keys.first,
      items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: _cairoStyle))).toList(),
      onChanged: onChanged,
    ),
  );

  Widget _buildOfferPicker(String label, Function(String?) onSelected) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: DropdownButtonFormField<String>(
      isExpanded: true,
      decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
      items: _availableOffers.map((o) => DropdownMenuItem(
        value: o['id'].toString(),
        child: Text("${o['productName']} (${o['unitName']})", style: _cairoStyle.copyWith(fontSize: 10.sp)),
      )).toList(),
      onChanged: onSelected,
      validator: (v) => v == null ? "مطلوب" : null,
    ),
  );

  Widget _buildDatePicker() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextFormField(
      controller: _expiryDateController,
      readOnly: true,
      style: _cairoStyle,
      decoration: InputDecoration(labelText: "تاريخ الانتهاء", prefixIcon: const Icon(Icons.calendar_today), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
      onTap: () async {
        DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 7)), firstDate: DateTime.now(), lastDate: DateTime(2030));
        if (picked != null) setState(() => _expiryDateController.text = picked.toIso8601String().split('T')[0]);
      },
      validator: (v) => v!.isEmpty ? "مطلوب" : null,
    ),
  );

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: _cairoStyle),
      backgroundColor: isError ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }
}

