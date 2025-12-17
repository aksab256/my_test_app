// lib/screens/seller/offers_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/data_sources/offer_data_source.dart';
import 'package:my_test_app/models/offer_model.dart';
import 'package:my_test_app/widgets/form_widgets.dart';
import 'package:sizer/sizer.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});
  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  final OfferDataSource _dataSource = OfferDataSource();
  final String? _currentSellerId = FirebaseAuth.instance.currentUser?.uid;

  List<ProductOfferModel> _allOffers = [];
  List<ProductOfferModel> _filteredOffers = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchTerm = '';
  String _statusFilter = '';

  @override
  void initState() {
    super.initState();
    if (_currentSellerId != null) {
      _loadOffers();
    } else {
      _errorMessage = 'يجب تسجيل الدخول كبائع لعرض العروض.';
      _isLoading = false;
    }
  }

  Future<void> _loadOffers() async {
    setState(() => _isLoading = true);
    try {
      final offers = await _dataSource.loadSellerOffers(_currentSellerId!);
      if (!mounted) return;
      setState(() {
        _allOffers = offers;
        _applyFilters();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredOffers = _allOffers.where((offer) {
        final matchesSearch = offer.productName.toLowerCase().contains(_searchTerm.toLowerCase());
        final matchesStatus = _statusFilter.isEmpty || (offer.status == _statusFilter);
        return matchesSearch && matchesStatus;
      }).toList();
      _isLoading = false;
    });
  }

  void _showEditModal(ProductOfferModel offer) {
    showDialog(
      context: context,
      builder: (context) => _EditOfferModal(
        offer: offer,
        dataSource: _dataSource,
        onUpdateSuccess: _loadOffers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: RefreshIndicator(
        onRefresh: _loadOffers,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(4.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("قائمة عروضي", style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w900, color: Theme.of(context).primaryColor)),
              SizedBox(height: 2.h),
              _buildFilterBar(),
              SizedBox(height: 3.h),
              if (_filteredOffers.isEmpty)
                Center(child: Padding(padding: EdgeInsets.only(top: 10.h), child: Text("لا توجد عروض حالياً", style: TextStyle(fontSize: 14.sp, color: Colors.grey))))
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredOffers.length,
                  itemBuilder: (context, index) => _OfferItemCard(
                    offer: _filteredOffers[index],
                    onViewDetails: _showEditModal,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade300)),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(hintText: "بحث...", border: InputBorder.none, icon: Icon(Icons.search)),
              onChanged: (v) { _searchTerm = v; _applyFilters(); },
            ),
          ),
          Container(width: 1, height: 30, color: Colors.grey.shade300, margin: EdgeInsets.symmetric(horizontal: 2.w)),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _statusFilter.isEmpty ? null : _statusFilter,
                hint: Text("الحالة", style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold)),
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: "", child: Text("الكل")),
                  DropdownMenuItem(value: "active", child: Text("نشط")),
                  DropdownMenuItem(value: "inactive", child: Text("معطل")),
                ],
                onChanged: (v) { setState(() { _statusFilter = v ?? ''; _applyFilters(); }); },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferItemCard extends StatelessWidget {
  final ProductOfferModel offer;
  final Function(ProductOfferModel) onViewDetails;
  const _OfferItemCard({required this.offer, required this.onViewDetails});

  @override
  Widget build(BuildContext context) {
    final unit = offer.units.isNotEmpty ? offer.units[0] : null;
    final isLowStock = (unit?.availableStock ?? 0) <= (offer.lowStockThreshold ?? 5);

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isLowStock ? Colors.red : Colors.grey.shade200, width: isLowStock ? 2 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        onTap: () => onViewDetails(offer),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(offer.imageUrl ?? '', width: 20.w, height: 20.w, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.image, size: 30.sp, color: Colors.grey.shade300)),
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(offer.productName, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w900, color: Colors.black)),
                  SizedBox(height: 1.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("${unit?.price ?? 0} ج.م", style: TextStyle(fontSize: 14.sp, color: Theme.of(context).primaryColor, fontWeight: FontWeight.w900)),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
                        decoration: BoxDecoration(color: isLowStock ? Colors.red.shade50 : Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Text("مخزون: ${unit?.availableStock ?? 0}", style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: isLowStock ? Colors.red : Colors.blue.shade700)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditOfferModal extends StatefulWidget {
  final ProductOfferModel offer;
  final OfferDataSource dataSource;
  final VoidCallback onUpdateSuccess;
  const _EditOfferModal({required this.offer, required this.dataSource, required this.onUpdateSuccess});

  @override
  State<_EditOfferModal> createState() => _EditOfferModalState();
}

class _EditOfferModalState extends State<_EditOfferModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  late String _status;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final unit = widget.offer.units.isNotEmpty ? widget.offer.units[0] : null;
    _priceController = TextEditingController(text: unit?.price.toString() ?? "0");
    _stockController = TextEditingController(text: unit?.availableStock.toString() ?? "0");
    _status = widget.offer.status;
  }

  Future<void> _updateOffer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await widget.dataSource.updateOffer(widget.offer.id!, {
        'units': [
          {'unitName': widget.offer.units[0].unitName, 'price': double.parse(_priceController.text), 'availableStock': int.parse(_stockController.text)}
        ],
        'status': _status,
      });
      widget.onUpdateSuccess();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ في التحديث: $e")));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteOffer() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تأكيد الحذف"),
        content: const Text("هل أنت متأكد من حذف هذا العرض نهائياً؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("حذف", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await widget.dataSource.deleteOffer(widget.offer.id!);
      widget.onUpdateSuccess();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text("تعديل: ${widget.offer.productName}", style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomInputField(label: "السعر الجديد", controller: _priceController, keyboardType: TextInputType.number, hintText: "أدخل السعر"),
              SizedBox(height: 2.h),
              CustomInputField(label: "تعديل الكمية", controller: _stockController, keyboardType: TextInputType.number, hintText: "أدخل الكمية"),
              SizedBox(height: 2.h),
              // تم إضافة hintText هنا لحل مشكلة الـ Error
              CustomSelectBox<String, String>(
                label: "حالة العرض",
                hintText: "اختر الحالة", 
                items: const ["active", "inactive"],
                selectedValue: _status,
                itemLabel: (v) => v == "active" ? "نشط" : "معطل",
                onChanged: (v) => setState(() => _status = v!),
              ),
              SizedBox(height: 3.h),
              TextButton.icon(
                onPressed: _deleteOffer, 
                icon: const Icon(Icons.delete_forever, color: Colors.red), 
                label: Text("حذف العرض تماماً", style: TextStyle(color: Colors.red, fontSize: 13.sp, fontWeight: FontWeight.bold))
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text("إلغاء", style: TextStyle(fontSize: 12.sp))),
        ElevatedButton(
          onPressed: _isSaving ? null : _updateOffer,
          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, padding: EdgeInsets.symmetric(horizontal: 5.w)),
          child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : Text("حفظ", style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
