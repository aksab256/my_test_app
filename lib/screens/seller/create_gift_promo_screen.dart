import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sizer/sizer.dart';

class CreateGiftPromoScreen extends StatefulWidget {
  final String currentSellerId;

  const CreateGiftPromoScreen({
    super.key,
    required this.currentSellerId,
  });

  @override
  State<CreateGiftPromoScreen> createState() => _CreateGiftPromoScreenState();
}

class _CreateGiftPromoScreenState extends State<CreateGiftPromoScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _promoNameController = TextEditingController();
  final TextEditingController _minOrderController = TextEditingController();
  final TextEditingController _triggerQtyBaseController = TextEditingController();
  final TextEditingController _giftQtyPerBaseController = TextEditingController(text: "1");
  final TextEditingController _maxPromoQtyController = TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController();

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
          .where('sellerId', isEqualTo: widget.currentSellerId) // ✅ تم التصحيح هنا
          .get();

      final offers = snapshot.docs.map((doc) {
        final data = doc.data();
        final unit = (data['units'] as List?)?.first ?? {};
        return {
          'id': doc.id,
          'productName': data['productName'] ?? 'بدون اسم',
          'productId': data['productId'] ?? doc.id,
          'imageUrl': data['imageUrl'] ?? '',
          'availableStock': unit['availableStock'] ?? 0,
          'price': unit['price'] ?? 0,
          'unitName': unit['unitName'] ?? 'الوحدة الرئيسية',
          'fullData': data,
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
      _showSnackBar("برجاء استكمال البيانات واختيار الهدية", isError: true);
      return;
    }

    setState(() => _isLoading = true);
    
    // ✅ جلب بيانات الهدية المختارة بشكل صحيح لاستخدامها في الـ Transaction
    final giftOffer = _availableOffers.firstWhere((o) => o['id'] == _selectedGiftOfferId);
    final int requestedQty = int.parse(_maxPromoQtyController.text);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final giftRef = FirebaseFirestore.instance.collection('productOffers').doc(_selectedGiftOfferId);
        final giftDoc = await transaction.get(giftRef);

        if (!giftDoc.exists) throw "وثيقة الهدية غير موجودة";

        List units = List.from(giftDoc.data()?['units'] ?? []);
        if (units.isEmpty) throw "لا توجد وحدات لهذا العرض";

        Map unit0 = Map.from(units[0]);
        int currentStock = (unit0['availableStock'] ?? 0).toInt();

        if (currentStock < requestedQty) {
          throw "الرصيد غير كافٍ! المتاح: $currentStock";
        }

        // تحديث الرصيد
        unit0['availableStock'] = currentStock - requestedQty;
        unit0['reservedForPromos'] = (unit0['reservedForPromos'] ?? 0) + requestedQty;
        unit0['updatedAt'] = DateTime.now().toIso8601String();
        units[0] = unit0;

        // 1. تحديث عرض المنتج (حجز المخزون)
        transaction.update(giftRef, {'units': units});

        // 2. إنشاء وثيقة الـ Promo الجديدة (استخدام giftOffer بدلاً من gift غير المعرفة)
        final promoRef = FirebaseFirestore.instance.collection('giftPromos').doc();
        transaction.set(promoRef, {
          'sellerId': widget.currentSellerId,
          'promoName': _promoNameController.text,
          'giftOfferId': _selectedGiftOfferId,
          'giftProductName': giftOffer['productName'], // ✅ تم التصحيح
          'giftUnitName': giftOffer['unitName'],       // ✅ تم التصحيح
          'giftQuantityPerBase': int.parse(_giftQtyPerBaseController.text),
          'giftOfferPriceSnapshot': giftOffer['price'],// ✅ تم التصحيح
          'giftProductId': giftOffer['productId'],     // ✅ تم التصحيح
          'giftProductImage': giftOffer['imageUrl'],   // ✅ تم التصحيح
          'trigger': _triggerType == 'min_order'
              ? {'type': 'min_order', 'value': double.parse(_minOrderController.text)}
              : {
                  'type': 'specific_item',
                  'offerId': _selectedTriggerOfferId,
                  'triggerQuantityBase': int.parse(_triggerQtyBaseController.text)
                },
          'expiryDate': DateTime.parse(_expiryDateController.text).toIso8601String(),
          'maxQuantity': requestedQty,
          'usedQuantity': 0,
          'reservedQuantity': 0,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(), // استخدام توقيت السيرفر الرسمي
        });
      });

      _showSnackBar("تم إنشاء عرض الهدية وحجز الرصيد بنجاح ✅");
      Navigator.pop(context);
    } catch (e) {
      _showSnackBar(e.toString(), isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء عرض هدايا ترويجي'), backgroundColor: Colors.green),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.sp),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField(_promoNameController, "اسم العرض الترويجي"),
                    _buildDropdown("نوع الحدث", ['min_order', 'specific_item'], (val) {
                      setState(() => _triggerType = val!);
                    }),
                    if (_triggerType == 'min_order')
                      _buildTextField(_minOrderController, "الحد الأدنى للطلب (ج.م)", isNumber: true),
                    if (_triggerType == 'specific_item') ...[
                      _buildOfferPicker("اختر المنتج المشغل للهدية", (id) => _selectedTriggerOfferId = id),
                      _buildTextField(_triggerQtyBaseController, "الكمية المطلوبة لتفعيل الهدية", isNumber: true),
                    ],
                    const Divider(height: 40),
                    _buildOfferPicker("اختر عرض الهدية", (id) => _selectedGiftOfferId = id),
                    _buildTextField(_giftQtyPerBaseController, "كمية الهدية الممنوحة", isNumber: true),
                    _buildTextField(_maxPromoQtyController, "إجمالي عدد الهدايا المتاحة (للحجز)", isNumber: true),
                    _buildDatePicker(),
                    SizedBox(height: 30.sp),
                    ElevatedButton(
                      onPressed: _createGiftPromo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: Size(double.infinity, 50.sp),
                      ),
                      child: const Text("إنشاء العرض الآن", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
            ),
    );
  }

  // --- Widgets Helpers ---
  Widget _buildTextField(TextEditingController controller, String label, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        validator: (v) => v!.isEmpty ? "مطلوب" : null,
      ),
    );
  }

  Widget _buildOfferPicker(String label, Function(String?) onSelected) {
    return _buildDropdown(label, _availableOffers.map((e) => e['id'] as String).toList(), onSelected, isOffer: true);
  }

  Widget _buildDropdown(String label, List<String> items, Function(String?) onSelected, {bool isOffer = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: items.map((id) {
          String text = id;
          if (isOffer) {
            final offer = _availableOffers.firstWhere((o) => o['id'] == id);
            text = "${offer['productName']} (رصيد: ${offer['availableStock']})";
          } else {
            text = id == 'min_order' ? "عند الوصول لحد أدنى للمبلغ" : "عند شراء منتج محدد";
          }
          return DropdownMenuItem(value: id, child: Text(text));
        }).toList(),
        onChanged: onSelected,
      ),
    );
  }

  Widget _buildDatePicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: _expiryDateController,
        readOnly: true,
        decoration: const InputDecoration(labelText: "تاريخ انتهاء الصلاحية", border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
        onTap: () async {
          DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2030));
          if (picked != null) _expiryDateController.text = picked.toIso8601String().split('T')[0];
        },
      ),
    );
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.green));
  }
}

