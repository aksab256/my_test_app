// lib/screens/seller/create_bundle_screen.dart
//
// Bundle creation (preview-only stock math; real reservation is backend-only).
// Catalog is restricted to the current seller's own `productOffers`.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import 'package:my_test_app/data_sources/bundle_data_source.dart';
import 'package:my_test_app/screens/seller/manage_bundles_screen.dart';
import 'package:my_test_app/utils/bundle_stock.dart';

class _PickedLine {
  final BundleCatalogRow row;
  int qty;
  _PickedLine({required this.row, this.qty = 1});
}

class CreateBundleScreen extends StatefulWidget {
  const CreateBundleScreen({super.key});

  @override
  State<CreateBundleScreen> createState() => _CreateBundleScreenState();
}

class _CreateBundleScreenState extends State<CreateBundleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dataSource = BundleDataSource();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();

  final String _sellerId = FirebaseAuth.instance.currentUser?.uid ?? '';
  List<BundleCatalogRow> _catalog = [];
  final List<_PickedLine> _picked = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _message;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    if (_sellerId.isEmpty) {
      setState(() {
        _isLoading = false;
        _message = 'يجب تسجيل الدخول كبائع.';
      });
      return;
    }
    try {
      final rows = await _dataSource.loadSellerCatalog(_sellerId);
      if (!mounted) return;
      setState(() {
        _catalog = rows;
        _isLoading = false;
        // Natural 3-product trial: preselect the first 3 distinct offers.
        if (_picked.isEmpty && rows.length >= 3) {
          final seen = <String>{};
          for (final r in rows) {
            final key = '${r.offerId}||${r.unitIndex}';
            if (seen.add(key)) {
              _picked.add(_PickedLine(row: r, qty: 1));
              if (_picked.length == 3) break;
            }
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _message = 'فشل تحميل الكتالوج: $e';
      });
    }
  }

  List<BundleStockLine> get _stockLines => _picked
      .map((p) => BundleStockLine(
            offerId: p.row.offerId,
            unitIndex: p.row.unitIndex,
            label: '${p.row.productName} (${p.row.unitName})',
            physicalStock: p.row.physicalStock,
            existingBundleReserved: p.row.bundleReserved,
            giftReserved: p.row.giftReserved,
            qtyRequired: p.qty,
          ))
      .toList();

  BundleValidation get _validation => validateBundleDraft(_stockLines);

  BundlePricing? get _pricing {
    final bundlePrice = double.tryParse(_priceController.text.trim());
    if (bundlePrice == null) return null;
    return bundlePricing(
      linePrices: _picked.map((p) => p.row.price).toList(),
      lineQuantities: _picked.map((p) => p.qty).toList(),
      bundlePrice: bundlePrice,
    );
  }

  bool _isPicked(BundleCatalogRow r) => _picked.any((p) =>
      p.row.offerId == r.offerId && p.row.unitIndex == r.unitIndex);

  void _togglePick(BundleCatalogRow r) {
    setState(() {
      final idx = _picked.indexWhere(
          (p) => p.row.offerId == r.offerId && p.row.unitIndex == r.unitIndex);
      if (idx >= 0) {
        _picked.removeAt(idx);
      } else {
        if (_picked.length >= 5) {
          _message = 'الحد الأقصى 5 منتجات مختلفة في البندل.';
          _isSuccess = false;
          return;
        }
        _picked.add(_PickedLine(row: r, qty: 1));
        _message = null;
      }
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_picked.length < 2 || _picked.length > 5) {
      setState(() {
        _message = 'اختر من منتجين إلى 5 منتجات مختلفة.';
        _isSuccess = false;
      });
      return;
    }
    final bundlePrice = double.parse(_priceController.text.trim());
    setState(() {
      _isSubmitting = true;
      _message = null;
    });
    try {
      // Re-fetch fresh stock immediately before the create request.
      final fresh = await _dataSource.refetchRows(_picked
          .map((p) => {'offerId': p.row.offerId, 'unitIndex': p.row.unitIndex})
          .toList());
      final freshByKey = {
        for (final r in fresh) '${r.offerId}||${r.unitIndex}': r
      };
      final recheck = <BundleStockLine>[];
      for (final p in _picked) {
        final f = freshByKey['${p.row.offerId}||${p.row.unitIndex}'];
        final base = f ?? p.row;
        recheck.add(BundleStockLine(
          offerId: p.row.offerId,
          unitIndex: p.row.unitIndex,
          label: '${p.row.productName} (${p.row.unitName})',
          physicalStock: base.physicalStock,
          existingBundleReserved: base.bundleReserved,
          giftReserved: base.giftReserved,
          qtyRequired: p.qty,
        ));
      }
      final gate = validateBundleDraft(recheck);
      if (!gate.canCreate) {
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
          _message = gate.message;
          _isSuccess = false;
        });
        // Refresh the visible counters with the freshest data.
        final refreshedCatalog =
            await _dataSource.loadSellerCatalog(_sellerId);
        if (!mounted) return;
        setState(() => _catalog = refreshedCatalog);
        return;
      }
      final idempotencyKey =
          FirebaseFirestore.instance.collection('_bundleKeys').doc().id;
      final result = await _dataSource.createBundle(
        bundleName: _nameController.text.trim(),
        items: _picked
            .map((p) => {
                  'offerId': p.row.offerId,
                  'unitIndex': p.row.unitIndex,
                  'qtyRequired': p.qty,
                })
            .toList(),
        totalPrice: bundlePrice,
        idempotencyKey: idempotencyKey,
      );
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _isSuccess = true;
        _message =
            'تم إنشاء البندل وحجز مكوناته: ${result['bundleId'] ?? ''}';
      });
      _formKey.currentState!.reset();
      _nameController.clear();
      _priceController.clear();
      setState(() => _picked.clear());
      await _loadCatalog();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _isSuccess = false;
        _message = 'فشل الإنشاء: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final validation = _validation;
    final pricing = _pricing;
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: const Text('إنشاء بندل جديد',
            style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'إدارة البندلات',
            icon: const Icon(Icons.inventory_2_outlined),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        ManageBundlesScreen(sellerId: _sellerId))),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_message != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _isSuccess
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: _isSuccess ? Colors.green : Colors.red),
                  ),
                  child: Text(_message!,
                      style: TextStyle(
                          color: _isSuccess
                              ? Colors.green.shade900
                              : Colors.red.shade900,
                          fontWeight: FontWeight.bold)),
                ),
              _stepCard(
                step: '1',
                title: 'اسم البندل وسعره',
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                        labelText: 'اسم البندل',
                        hintText: 'مثال: بندل العائلة'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'أدخل اسم البندل' : null,
                  ),
                  SizedBox(height: 1.5.h),
                  TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'السعر الإجمالي للبندل (ج.م)',
                        hintText: 'مثال: 500'),
                    validator: (v) {
                      final d = double.tryParse((v ?? '').trim());
                      if (d == null || d <= 0) return 'أدخل سعرًا صحيحًا';
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
              _stepCard(
                step: '2',
                title: 'اختيار المنتجات (${_picked.length}/5)',
                subtitle: 'التجربة الطبيعية: 3 منتجات. من كتالوجك فقط.',
                children: [
                  if (_catalog.isEmpty)
                    const Text('لا توجد عروض نشطة في كتالوجك بعد.'),
                  for (final r in _catalog)
                    CheckboxListTile(
                      value: _isPicked(r),
                      onChanged: (_) => _togglePick(r),
                      title: Text(
                          '${r.productName} — ${r.unitName}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          'فعلي: ${r.physicalStock} | محجوز لبندلات: ${r.bundleReserved} | '
                          'متاح: ${r.availableStock} | سعر: ${r.price} ج.م'),
                      dense: true,
                    ),
                ],
              ),
              _stepCard(
                step: '3',
                title: 'كميات المكونات',
                children: [
                  if (_picked.isEmpty) const Text('اختر منتجين على الأقل.'),
                  for (int i = 0; i < _picked.length; i++)
                    _qtyRow(i),
                ],
              ),
              _stepCard(
                step: '4',
                title: 'معاينة البندل',
                children: [
                  for (final p in _picked)
                    Text(
                        '• ${p.row.productName} (${p.row.unitName}) × ${p.qty} '
                        '— متاح: ${p.row.availableStock}، سيُحجز: ${p.qty}'),
                  SizedBox(height: 1.h),
                  if (pricing != null) ...[
                    Text(
                        'مجموع الأسعار الأصلية: ${pricing.originalTotal.toStringAsFixed(2)} ج.م'),
                    Text(
                        'سعر البندل: ${pricing.bundlePrice.toStringAsFixed(2)} ج.م',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                        'التوفير: ${pricing.saving.toStringAsFixed(2)} ج.م',
                        style: TextStyle(
                            color: pricing.saving >= 0
                                ? Colors.green.shade800
                                : Colors.red,
                            fontWeight: FontWeight.bold)),
                  ],
                  SizedBox(height: 1.h),
                  Text(
                    validation.canCreate
                        ? 'يمكن تكوين ${validation.maxBundles} بندل بهذه الكميات.'
                        : (validation.message ?? 'غير ممكن حاليًا.'),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: validation.canCreate
                            ? Colors.green.shade800
                            : Colors.red.shade800),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'تنبيه: الحساب معاينة فقط وليس ضمانًا للمخزون. يتم الحجز الحقيقي في الدالة الخلفية.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              SizedBox(height: 1.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isSubmitting || !validation.canCreate)
                      ? null
                      : _submit,
                  child: Text(_isSubmitting
                      ? 'جارٍ الإنشاء والحجز...'
                      : 'إنشاء البندل وحجز المخزون'),
                ),
              ),
              SizedBox(height: 5.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _qtyRow(int index) {
    final p = _picked[index];
    final avail = p.row.availableStock;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text('${p.row.productName} (${p.row.unitName})\n'
                'فعلي ${p.row.physicalStock} • محجوز ${p.row.bundleReserved} • متاح $avail'),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: p.qty > 1
                ? () => setState(() => p.qty--)
                : null,
          ),
          Text('${p.qty}',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => setState(() => p.qty++),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => setState(() => _picked.removeAt(index)),
          ),
        ],
      ),
    );
  }

  Widget _stepCard(
      {required String step,
      required String title,
      String? subtitle,
      required List<Widget> children}) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 2.h),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFF2D9E68),
                  child: Text(step,
                      style: const TextStyle(color: Colors.white))),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 16))),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle,
                style:
                    const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }
}
