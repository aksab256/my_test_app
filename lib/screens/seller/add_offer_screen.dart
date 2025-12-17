// lib/screens/seller/add_offer_screen.dart (النسخة المستقرة والنهائية)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _minOrderController = TextEditingController();
  final _maxOrderController = TextEditingController();

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
    super.dispose();
  }

  // --- دوال منطق البيانات المصححة ---

  Future<void> _loadInitialData() async {
    try {
      final categories = await _dataSource.loadMainCategories();
      final areas = await _dataSource.loadSellerDeliveryAreas(_currentSellerId);
      if (!mounted) return;
      setState(() {
        _mainCategories = categories;
        _sellerDeliveryAreas = areas;
        _isLoading = false;
      });
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
    // ⭐️ تصحيح: البحث الآمن باستخدام cast و orElse لتجنب Bad State ⭐️
    final product = _products.cast<SelectItemModel?>().firstWhere(
      (item) => item?.id == productId,
      orElse: () => null,
    );

    if (product == null) return;

    final productUnits = product.units;
    if (productUnits != null && productUnits.isNotEmpty) {
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

    // ⭐️ تصحيح: البحث الآمن عن المنتج المختار ⭐️
    final selectedProduct = _products.cast<SelectItemModel?>().firstWhere(
      (item) => item?.id == _selectedProductId,
      orElse: () => null,
    );

    if (selectedProduct == null) {
      _showMessage('خطأ: لم يتم العثور على المنتج المختار.', false);
      return;
    }

    try {
      final offerModel = ProductOfferModel(
        sellerId: _currentSellerId,
        sellerName: "المورد",
        productId: selectedProduct.id,
        productName: selectedProduct.name,
        imageUrl: selectedProduct.imageUrl ?? '',
        deliveryZones: _sellerDeliveryAreas,
        units: [
          OfferUnitModel(
            unitName: _selectedUnitName!,
            price: double.parse(_priceController.text),
            availableStock: int.parse(_quantityController.text),
          ),
        ],
        minOrder: int.tryParse(_minOrderController.text),
        maxOrder: int.tryParse(_maxOrderController.text),
      );

      await _dataSource.addOffer(offerModel);
      if (!mounted) return;
      _showMessage('تم إضافة العرض بنجاح!', true);
      _formKey.currentState!.reset();
      
      // إعادة تصفير الاختيارات بعد النجاح
      setState(() {
        _selectedProductId = null;
        _selectedUnitName = null;
        _availableUnits = [];
      });
    } catch (e) {
      _showMessage('خطأ أثناء الإضافة: $e', false);
    }
  }

  // --- واجهة المستخدم المطورة ---

  Widget _buildStepCard({required String step, required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      margin: EdgeInsets.only(bottom: 3.h),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12.sp, // تكبير دائرة الرقم
                backgroundColor: Theme.of(context).primaryColor,
                child: Text(step, style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Text(title, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900)),
              const Spacer(),
              Icon(icon, color: Colors.grey.shade400, size: 20.sp),
            ],
          ),
          const Divider(height: 35, thickness: 1),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_message != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  margin: const EdgeInsets.only(bottom: 25),
                  decoration: BoxDecoration(
                    color: _isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _isSuccess ? Colors.green : Colors.red, width: 1.5),
                  ),
                  child: Text(
                    _message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w900, color: _isSuccess ? Colors.green.shade800 : Colors.red.shade800),
                  ),
                ),

              Text("إضافة عرض جديد", style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w900, color: Theme.of(context).primaryColor)),
              SizedBox(height: 3.h),

              _buildStepCard(
                step: "1",
                title: "التصنيف الرئيسي",
                icon: Icons.grid_view_rounded,
                children: [
                  CustomSelectBox<SelectItemModel, String>(
                    label: 'القسم الرئيسي',
                    hintText: 'اختر قسماً',
                    items: _mainCategories,
                    selectedValue: _selectedMainCategoryId,
                    itemLabel: (item) => item.name,
                    itemValueGetter: (item) => item.id,
                    onChanged: (id) {
                      setState(() {
                        _selectedMainCategoryId = id;
                        _selectedSubCategoryId = null;
                        _selectedProductId = null;
                        _subCategories = [];
                        _products = [];
                      });
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
                      setState(() {
                        _selectedSubCategoryId = id;
                        _selectedProductId = null;
                        _products = [];
                      });
                      if (id != null) _loadProducts(id);
                    },
                  ),
                ],
              ),

              _buildStepCard(
                step: "2",
                title: "بيانات الصنف",
                icon: Icons.inventory_2_rounded,
                children: [
                  CustomSelectBox<SelectItemModel, String>(
                    label: 'المنتج',
                    hintText: 'اختر المنتج',
                    items: _products,
                    selectedValue: _selectedProductId,
                    itemLabel: (item) => item.name,
                    itemValueGetter: (item) => item.id,
                    onChanged: (id) {
                      setState(() {
                        _selectedProductId = id;
                        _selectedUnitName = null;
                        _availableUnits = [];
                      });
                      if (id != null) _loadAvailableUnits(id);
                    },
                  ),
                  SizedBox(height: 2.h),
                  CustomSelectBox<String, String>(
                    label: 'الوحدة',
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
                title: "التسعير والكمية",
                icon: Icons.monetization_on_rounded,
                children: [
                  CustomInputField(
                    label: 'السعر (ج.م)',
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    hintText: 'مثال: 15.5',
                  ),
                  SizedBox(height: 2.h),
                  CustomInputField(
                    label: 'الكمية المتاحة',
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    hintText: 'مثال: 100',
                  ),
                ],
              ),

              SizedBox(height: 2.h),
              SizedBox(
                width: double.infinity,
                height: 8.h,
                child: ElevatedButton.icon(
                  onPressed: _submitOffer,
                  icon: Icon(Icons.check_circle_outline, color: Colors.white, size: 22.sp),
                  label: Text("تأكيد ونشر العرض", style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w900)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    elevation: 5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
              SizedBox(height: 5.h),
            ],
          ),
        ),
      ),
    );
  }
}
