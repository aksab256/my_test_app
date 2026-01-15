// lib/screens/seller/create_gift_promo_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_test_app/screens/seller/manage_gift_promos_screen.dart';

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

  @override
  void dispose() {
    _promoNameController.dispose();
    _minOrderValueController.dispose();
    _triggerQtyBaseController.dispose();
    _giftQtyPerBaseController.dispose();
    _promoQuantityController.dispose();
    _expiryDateController.dispose();
    super.dispose();
  }

  // --- دالة جلب العروض الأصلية ---
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

  // --- دالة إنشاء العرض الأصلية ---
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
        Map unit0 = Map.from(units[0]);
        int currentAvailableStock = (unit0['availableStock'] ?? 0).toInt();

        if (currentAvailableStock < totalPromoQuantity) {
          throw "الرصيد غير كافٍ! المتاح حالياً: $currentAvailableStock";
        }

        unit0['availableStock'] = currentAvailableStock - totalPromoQuantity;
        unit0['reservedForPromos'] = (unit0['reservedForPromos'] ?? 0) + totalPromoQuantity;
        unit0['updatedAt'] = DateTime.now().toIso8601String();
        units[0] = unit0;

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
      backgroundColor: const Color(0xFFF4F7F4),
      appBar: AppBar(
        title: Text("هدايا العملاء", style: _cairoStyle.copyWith(fontSize: 15.sp, color: Colors.white)),
        backgroundColor: const Color(0xFF1B5E20),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ManageGiftPromosScreen(currentSellerId: widget.currentSellerId))),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.only(bottom: 4.h),
              decoration: const BoxDecoration(
                color: Color(0xFF1B5E20),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              ),
              child: Center(
                child: Text("قم بإنشاء عرض هدايا جذاب لعملائك", 
                  style: _cairoStyle.copyWith(color: Colors.white70, fontSize: 10.sp, fontWeight: FontWeight.normal)),
              ),
            ),
            
            Transform.translate(
              offset: Offset(0, -3.h),
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 5.w),
                padding: EdgeInsets.all(16.sp),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15, offset: const Offset(0, 5))]
                ),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel("بيانات الحملة"),
                      _buildTextField(_promoNameController, "اسم العرض الترويجي", Icons.campaign),
                      _buildDatePicker(),
                      
                      Divider(height: 4.h), // تمت إزالة const هنا
                      _sectionLabel("شروط الاستحقاق"),
                      _buildDropdown("متى يستحق العميل الهدية؟", {
                        'min_order': 'عند الوصول لمبلغ فاتورة معين',
                        'specific_item': 'عند شراء منتج محدد'
                      }, (val) => setState(() => _triggerType = val!)),
                      
                      if (_triggerType == 'min_order')
                        _buildTextField(_minOrderValueController, "مبلغ الفاتورة الأدنى", Icons.payments, isNumber: true),
                      
                      if (_triggerType == 'specific_item') ...[
                        _buildOfferPicker("اختر المنتج الشرطي", (id) => setState(() => _selectedTriggerOfferId = id)),
                        _buildTextField(_triggerQtyBaseController, "الكمية اللازم شراؤها", Icons.shopping_cart_checkout, isNumber: true),
                      ],

                      Divider(height: 4.h), // تمت إزالة const هنا
                      _sectionLabel("تفاصيل الهدية"),
                      _buildOfferPicker("اختر منتج الهدية", (id) => setState(() => _selectedGiftOfferId = id)),
                      
                      Row(
                        children: [
                          Expanded(child: _buildTextField(_giftQtyPerBaseController, "كمية الهدية", Icons.card_giftcard, isNumber: true)),
                          SizedBox(width: 3.w),
                          Expanded(child: _buildTextField(_promoQuantityController, "إجمالي المحجوز", Icons.inventory, isNumber: true)),
                        ],
                      ),
                      
                      SizedBox(height: 3.h),
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
    padding: EdgeInsets.symmetric(vertical: 8.sp),
    child: Text(text, style: _cairoStyle.copyWith(fontSize: 12.sp, color: Colors.green[900])),
  );

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {bool isNumber = false}) => Padding(
    padding: EdgeInsets.only(bottom: 1.5.h),
    child: TextFormField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: _cairoStyle.copyWith(fontSize: 12.sp, fontWeight: FontWeight.normal),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.green[800]),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: EdgeInsets.symmetric(vertical: 1.5.h, horizontal: 4.w),
      ),
      validator: (v) => (v == null || v.isEmpty) ? "مطلوب" : null,
    ),
  );

  Widget _buildDatePicker() => Padding(
    padding: EdgeInsets.only(bottom: 1.5.h),
    child: TextFormField(
      controller: _expiryDateController,
      readOnly: true,
      style: _cairoStyle.copyWith(fontSize: 12.sp, fontWeight: FontWeight.normal),
      decoration: InputDecoration(
        labelText: "تاريخ انتهاء الصلاحية",
        prefixIcon: const Icon(Icons.event_available, color: Colors.redAccent),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
          setState(() {
            _expiryDateController.text = formattedDate;
          });
        }
      },
      validator: (v) => (v == null || v.isEmpty) ? "برجاء اختيار التاريخ" : null,
    ),
  );

  Widget _buildDropdown(String label, Map<String, String> items, Function(String?) onChanged) => Padding(
    padding: EdgeInsets.only(bottom: 1.5.h),
    child: DropdownButtonFormField<String>(
      style: _cairoStyle.copyWith(color: Colors.black, fontSize: 11.sp, fontWeight: FontWeight.normal),
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      value: _triggerType,
      items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: _cairoStyle.copyWith(fontSize: 11.sp)))).toList(),
      onChanged: onChanged,
    ),
  );

  Widget _buildOfferPicker(String label, Function(String?) onSelected) => Padding(
    padding: EdgeInsets.only(bottom: 1.5.h),
    child: DropdownButtonFormField<String>(
      isExpanded: true,
      hint: Text(label, style: _cairoStyle.copyWith(fontSize: 11.sp, fontWeight: FontWeight.normal)),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.shopping_bag_outlined, color: Colors.orange),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: _availableOffers.map((o) => DropdownMenuItem(
        value: o['id'].toString(),
        child: Text("${o['productName']} (المتاح: ${o['availableStock']})", style: _cairoStyle.copyWith(fontSize: 11.sp)),
      )).toList(),
      onChanged: onSelected,
      validator: (v) => v == null ? "برجاء اختيار منتج" : null,
    ),
  );

  Widget _buildSubmitButton() => SizedBox(
    width: double.infinity,
    height: 7.h,
    child: ElevatedButton(
      onPressed: _isLoading ? null : _createGiftPromo,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1B5E20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),
      child: _isLoading
        ? const CircularProgressIndicator(color: Colors.white)
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 3.w),
              Text("حجز وتفعيل العرض", style: _cairoStyle.copyWith(color: Colors.white, fontSize: 13.sp)),
            ],
          ),
    ),
  );

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: _cairoStyle.copyWith(fontSize: 12.sp, color: Colors.white)),
      backgroundColor: isError ? Colors.redAccent : Colors.green[800],
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}
