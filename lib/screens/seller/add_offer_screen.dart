// lib/screens/seller/add_offer_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/data_sources/add_offer_data_source.dart';
import 'package:my_test_app/models/offer_model.dart';
import 'package:my_test_app/models/select_item_model.dart';
import 'package:my_test_app/widgets/form_widgets.dart';
import 'package:sizer/sizer.dart';

class AddOfferScreen extends StatefulWidget {
  const AddOfferScreen({super.key});

  @override
  State<AddOfferScreen> createState() => _AddOfferScreenState();
}

class _AddOfferScreenState extends State<AddOfferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dataSource = AddOfferDataSource();
  
  // التحكم في المدخلات النصية (Controllers)
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _minOrderController = TextEditingController(); 
  final _maxOrderController = TextEditingController();
  final _lowStockController = TextEditingController();

  // 🎯 الحقل الاختياري الجديد لسعر العرض التخفيضي فقط
  final _offerPriceController = TextEditingController();

  // متغيرات البيانات
  List<SelectItemModel> _mainCategories = [];
  List<SelectItemModel> _subCategories = [];
  List<SelectItemModel> _products = [];
  Map<String, Set<String>> _offeredUnitsByProduct = {};

  String? _selectedMainCategoryId;
  String? _selectedSubCategoryId;
  String? _selectedProductId;
  String? _selectedUnitName;
  List<String> _availableUnits = [];
  
  List<String> _sellerDeliveryAreas = []; 
  String _sellerName = "المورد";

  String? _message;
  bool _isSuccess = false;
  bool _isLoading = true;
  final String _currentSellerId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown_seller';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _priceController.dispose();
    _quantityController.dispose();
    _minOrderController.dispose();
    _maxOrderController.dispose();
    _lowStockController.dispose();
    _offerPriceController.dispose(); // 🎯 إغلاق الـ Controller الجديد
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final categories = await _dataSource.loadMainCategories();
      final sellerDoc = await FirebaseFirestore.instance.collection('sellers').doc(_currentSellerId).get();
      
      if (sellerDoc.exists) {
        final data = sellerDoc.data()!;
        setState(() {
          _mainCategories = categories;
          _sellerDeliveryAreas = List<String>.from(data['deliveryAreas'] ?? []);
          _sellerName = data['merchantName'] ?? data['supermarketName'] ?? "مورد غير معروف";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _message = 'خطأ في تحميل البيانات: $e';
      });
    }
  }

  Future<void> _loadSubCategories(String mainId) async {
    try {
      final subCats = await _dataSource.loadSubCategories(mainId);
      if (!mounted) return;
      setState(() => _subCategories = subCats);
    } catch (e) {
      _showMessage('خطأ في تحميل الأقسام الفرعية.', false);
    }
  }

  Future<void> _loadProducts(String subId) async {
    try {
      final result = await _dataSource.loadProducts(subId, _currentSellerId);
      if (!mounted) return;
      setState(() {
        _products = result['allProducts'] as List<SelectItemModel>;
        _offeredUnitsByProduct = result['offeredUnitsByProduct'] as Map<String, Set<String>>;
      });
    } catch (e) {
      _showMessage('خطأ في تحميل المنتجات.', false);
    }
  }

  void _loadAvailableUnits(String productId) {
    final product = _products.cast<SelectItemModel?>().firstWhere(
      (item) => item?.id == productId,
      orElse: () => null,
    );
    if (product == null) return;
    final productUnits = product.units;
    if (productUnits != null) {
      final offeredUnits = _offeredUnitsByProduct[productId] ?? {};
      final units = productUnits
          .map<String>((unit) => unit['unitName'].toString())
          .where((unitName) => !offeredUnits.contains(unitName))
          .toList();
      setState(() => _availableUnits = units);
    }
  }

  void _showMessage(String msg, bool isSuccess) {
    setState(() {
      _message = msg;
      _isSuccess = isSuccess;
    });
  }

  Future<void> _submitOffer() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProductId == null || _selectedUnitName == null) {
      _showMessage('الرجاء اختيار المنتج والوحدة.', false);
      return;
    }

    final selectedProduct = _products.cast<SelectItemModel?>().firstWhere(
      (item) => item?.id == _selectedProductId,
      orElse: () => null,
    );

    if (selectedProduct == null) return;

    final double mainPrice = double.parse(_priceController.text);
    final double? offerPrice = double.tryParse(_offerPriceController.text);
    
    if (offerPrice != null && offerPrice >= mainPrice) {
      _showMessage('سعر العرض الخاص يجب أن يكون أقل من السعر الأصلي للوحدة.', false);
      return;
    }

    try {
      setState(() => _isLoading = true);

      final offerModel = ProductOfferModel(
        sellerId: _currentSellerId,
        sellerName: _sellerName,
        productId: selectedProduct.id,
        productName: selectedProduct.name,
        imageUrl: selectedProduct.imageUrl,
        deliveryZones: _sellerDeliveryAreas,
        units: [
          OfferUnitModel(
            unitName: _selectedUnitName!,
            price: mainPrice,
            availableStock: int.parse(_quantityController.text),
          ),
        ],
        minOrder: int.tryParse(_minOrderController.text),
        maxOrder: int.tryParse(_maxOrderController.text),
        lowStockThreshold: int.tryParse(_lowStockController.text) ?? 5,
        
        // 🎯 يتم إرسال سعر العرض كـ null إن لم يُدخل التاجر قيمة (لضمان عدم التخزين بقيمة 0)
        offerPrice: offerPrice,
      );

      await _dataSource.addOffer(offerModel);
      
      if (!mounted) return;
      _showMessage('تم إضافة العرض بنجاح ونشره على المنصة!', true);
      _formKey.currentState!.reset();
      _priceController.clear();
      _quantityController.clear();
      _minOrderController.clear();
      _maxOrderController.clear();
      _lowStockController.clear();
      _offerPriceController.clear();

      setState(() {
        _selectedProductId = null;
        _selectedUnitName = null;
        _availableUnits = [];
        _isLoading = false;
      });
      
      if (_selectedSubCategoryId != null) _loadProducts(_selectedSubCategoryId!);

    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage('خطأ أثناء الإضافة: $e', false);
    }
  }

  Widget _buildStepCard({required String step, required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      margin: EdgeInsets.only(bottom: 2.5.h),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 13.sp,
                backgroundColor: const Color(0xFF2D9E68),
                child: Text(step, style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 15),
              Text(title, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900, color: const Color(0xFF1A1A1A))),
              const Spacer(),
              Icon(icon, color: Colors.grey.shade300, size: 22.sp),
            ],
          ),
          const Divider(height: 35, thickness: 1.2),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _mainCategories.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: Text("إضافة عرض جديد", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18.sp)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF1A1A1A),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_message != null)
                _buildMessageBanner(),

              _buildStepCard(
                step: "1",
                title: "تصنيف المنتج",
                icon: Icons.category_rounded,
                children: [
                  CustomSelectBox<SelectItemModel, String>(
                    label: 'القسم الرئيسي',
                    hintText: 'اختر القسم',
                    items: _mainCategories,
                    selectedValue: _selectedMainCategoryId,
                    itemLabel: (item) => item.name,
                    itemValueGetter: (item) => item.id,
                    onChanged: (id) {
                      setState(() { _selectedMainCategoryId = id; _selectedSubCategoryId = null; _selectedProductId = null; });
                      if (id != null) _loadSubCategories(id);
                    },
                  ),
                  SizedBox(height: 2.h),
                  CustomSelectBox<SelectItemModel, String>(
                    label: 'القسم الفرعي',
                    hintText: 'اختر القسم الفرعي',
                    items: _subCategories,
                    selectedValue: _selectedSubCategoryId,
                    itemLabel: (item) => item.name,
                    itemValueGetter: (item) => item.id,
                    onChanged: (id) {
                      setState(() { _selectedSubCategoryId = id; _selectedProductId = null; });
                      if (id != null) _loadProducts(id);
                    },
                  ),
                ],
              ),

              _buildStepCard(
                step: "2",
                title: "اختيار الصنف والوحدة",
                icon: Icons.inventory_2_rounded,
                children: [
                  CustomSelectBox<SelectItemModel, String>(
                    label: 'المنتج',
                    hintText: 'اختر اسم المنتج',
                    items: _products,
                    selectedValue: _selectedProductId,
                    itemLabel: (item) => item.name,
                    itemValueGetter: (item) => item.id,
                    onChanged: (id) {
                      setState(() { _selectedProductId = id; _selectedUnitName = null; });
                      if (id != null) _loadAvailableUnits(id);
                    },
                  ),
                  SizedBox(height: 2.h),
                  CustomSelectBox<String, String>(
                    label: 'وحدة البيع',
                    hintText: 'اختر الوحدة المتاحة',
                    items: _availableUnits,
                    selectedValue: _selectedUnitName,
                    itemLabel: (item) => item,
                    onChanged: (val) => setState(() => _selectedUnitName = val),
                  ),
                ],
              ),

              _buildStepCard(
                step: "3",
                title: "التسعير والمخزون",
                icon: Icons.monetization_on_rounded,
                children: [
                  CustomInputField(
                    label: 'السعر الأصلي للوحدة (ج.م)',
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    hintText: 'مثال: 300',
                  ),
                  SizedBox(height: 2.h),
                  // 🎯 حقل سعر العرض الخصم المضاف حديثاً
                  CustomInputField(
                    label: 'سعر العرض/الخصم (اختياري)',
                    controller: _offerPriceController,
                    keyboardType: TextInputType.number,
                    hintText: 'مثال: 270 (اتركه فارغاً إذا لم يوجد خصم)',
                  ),
                  SizedBox(height: 2.h),
                  CustomInputField(
                    label: 'الكمية المتوفرة حالياً',
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    hintText: 'مثال: 100',
                  ),
                  SizedBox(height: 2.h),
                  CustomInputField(
                    label: 'حد التحذير لنقص المخزون',
                    controller: _lowStockController,
                    keyboardType: TextInputType.number,
                    hintText: 'مثال: 10',
                  ),
                ],
              ),

              _buildStepCard(
                step: "4",
                title: "سياسة حدود الطلب (اختياري)",
                icon: Icons.shopping_bag_rounded,
                children: [
                  CustomInputField(
                    label: 'الحد الأدنى للطلب (كمية)',
                    controller: _minOrderController,
                    keyboardType: TextInputType.number,
                    hintText: 'مثال: 5',
                  ),
                  SizedBox(height: 2.h),
                  CustomInputField(
                    label: 'الحد الأقصى للطلب (كمية)',
                    controller: _maxOrderController,
                    keyboardType: TextInputType.number,
                    hintText: 'مثال: 50 (أو 1 لو عايز تخليه قطعة واحدة كعرض خاص)',
                  ),
                ],
              ),

              SizedBox(height: 2.h),
              _buildSubmitButton(),
              SizedBox(height: 5.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 25),
      decoration: BoxDecoration(
        color: _isSuccess ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _isSuccess ? Colors.green : Colors.red, width: 1.5),
      ),
      child: Text(_message!, textAlign: TextAlign.center, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w900, color: _isSuccess ? Colors.green.shade800 : Colors.red.shade800)),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 8.h,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _submitOffer,
        icon: _isLoading 
            ? const CircularProgressIndicator(color: Colors.white) 
            : Icon(Icons.check_circle_outline, color: Colors.white, size: 22.sp),
        label: Text(_isLoading ? "جاري الحفظ..." : "تأكيد ونشر العرض", style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w900)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2D9E68),
          elevation: 8,
          shadowColor: const Color(0xFF2D9E68).withOpacity(0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
      ),
    );
  }
}