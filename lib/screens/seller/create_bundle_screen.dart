// lib/screens/seller/create_bundle_screen.dart
//
// Bundle creation (preview-only stock math; real reservation is backend-only).
// Catalog is restricted to the current seller's own `productOffers`.

import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import 'package:my_test_app/data_sources/bundle_cover_service.dart';
import 'package:my_test_app/data_sources/bundle_data_source.dart';
import 'package:my_test_app/screens/seller/manage_bundles_screen.dart';
import 'package:my_test_app/utils/bundle_cover_layout.dart';
import 'package:my_test_app/utils/bundle_stock.dart';

class _PickedLine {
  final BundleCatalogRow row;
  int qty;
  _PickedLine({required this.row, this.qty = 1});
}

class CreateBundleScreen extends StatefulWidget {
  final String? sellerId;
  final BundleServiceGateway? gateway;
  final BundleCoverService? coverService;

  const CreateBundleScreen(
      {super.key, this.sellerId, this.gateway, this.coverService});

  @override
  State<CreateBundleScreen> createState() => _CreateBundleScreenState();
}

class _CreateBundleScreenState extends State<CreateBundleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _countController = TextEditingController(text: '1');

  late final BundleServiceGateway _gateway;
  late final BundleCoverService _coverService;

  /// Injected in tests; otherwise the signed-in seller.
  String get _sellerId =>
      widget.sellerId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
  BundleServiceGateway get _dataSource => _gateway;
  List<BundleCatalogRow> _catalog = [];
  final List<_PickedLine> _picked = [];

  /// The 3-product trial preselect runs only on the very first catalog load,
  /// so a post-submit refresh never resurrects the cleared selection.
  bool _didInitialPreselect = false;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _message;
  bool _isSuccess = false;

  // Seller snapshot (real source: sellers/{sellerId}) for the bundle record.
  String _sellerName = '';
  String _sellerPhone = '';
  List<String> _deliveryZones = const [];
  String? _deliveryZonesSource;

  // Cover preview memoization: recompose only when the fingerprint changes.
  String? _previewFingerprint;
  Future<List<int>>? _previewFuture;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? BundleDataSource();
    _coverService = widget.coverService ?? BundleCoverService();
    _loadCatalog();
    _loadSellerProfile();
  }

  Future<void> _loadSellerProfile() async {
    if (_sellerId.isEmpty) return;
    try {
      final profile = await _dataSource.loadSellerProfile(_sellerId);
      if (!mounted) return;
      setState(() {
        _sellerName = (profile['sellerName'] ?? '').toString();
        _sellerPhone = (profile['sellerPhone'] ?? '').toString();
        final zones = profile['deliveryAreas'];
        _deliveryZones =
            zones is List ? zones.map((e) => e.toString()).toList() : const [];
        _deliveryZonesSource = profile['deliveryZonesSource']?.toString();
      });
    } catch (_) {
      // Bundle creation still works; zones stay empty and purchase-time
      // checks must re-read the live sellers doc.
    }
  }

  /// Original component images only — the cover never invents imagery.
  List<CoverInput> _coverInputs() => _picked
      .map((p) => CoverInput(
            offerId: p.row.offerId,
            unitIndex: p.row.unitIndex,
            imageUrl: p.row.imageUrl,
            label: p.row.productName,
          ))
      .toList();

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _countController.dispose();
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
        // Natural 3-product trial: preselect the first 3 distinct offers,
        // once per screen lifetime (never after a successful submit).
        if (!_didInitialPreselect &&
            _picked.isEmpty &&
            rows.length >= 3) {
          _didInitialPreselect = true;
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

  int get _requestedCount =>
      int.tryParse(_countController.text.trim()) ?? 0;

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
    final requested = _requestedCount;
    setState(() {
      _isSubmitting = true;
      _message = null;
    });
    String bundleId = '';
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
      // Requested unit count vs the live computable maximum (fresh data).
      final countCheck =
          validateBundleCount(lines: recheck, requested: requested);
      if (!countCheck.ok) {
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
          _message = countCheck.message;
          _isSuccess = false;
        });
        final refreshedCatalog =
            await _dataSource.loadSellerCatalog(_sellerId);
        if (!mounted) return;
        setState(() => _catalog = refreshedCatalog);
        return;
      }
      // Unique per attempt; retries use a new key (no Firestore dependency).
      final idempotencyKey =
          'b${DateTime.now().microsecondsSinceEpoch}-${_sellerId.hashCode}';
      final itemsPayload = _picked
          .map((p) => {
                'offerId': p.row.offerId,
                'unitIndex': p.row.unitIndex,
                'qtyRequired': p.qty,
              })
          .toList();
      // Step 1: create the bundle + reserve N*Q per line (backend is the
      // only writer of reservations). Cover starts as missing.
      final result = await _dataSource.createBundle(
        bundleName: _nameController.text.trim(),
        description: _descController.text.trim(),
        items: itemsPayload,
        totalPrice: bundlePrice,
        idempotencyKey: idempotencyKey,
        bundleCount: requested,
        sellerName: _sellerName,
        sellerPhone: _sellerPhone,
        deliveryZones: _deliveryZones,
        deliveryZonesSource: _deliveryZonesSource,
        coverStatus: 'missing',
        coverVersion: 0,
      );
      bundleId = (result['bundleId'] ?? '').toString();

      // Step 2: compose + upload the cover. If this stage fails, the
      // bundle and its reservation already exist and stay consistent —
      // the cover simply stays missing and the seller keeps the form.
      if (bundleId.isNotEmpty && _picked.length >= 2) {
        try {
          final cover = await _coverService.composeAndUpload(
            bundleDocId: bundleId,
            inputs: _coverInputs(),
            version: 1,
          );
          await _dataSource.updateBundleItems(
            bundleId: bundleId,
            items: itemsPayload,
            coverImagePath: cover.coverImagePath,
            coverImageUrl: cover.coverImageUrl,
            coverUpdatedAt: cover.coverUpdatedAt.toIso8601String(),
            coverVersion: cover.coverVersion,
            coverStatus: cover.fallbackCount > 0 ? 'fallback' : 'ready',
          );
        } on BundleCoverException catch (e) {
          // Record the failure so the UI shows a fallback, not a cover.
          try {
            await _dataSource.updateBundleItems(
              bundleId: bundleId,
              items: itemsPayload,
              coverVersion: 0,
              coverStatus: 'upload_failed',
            );
          } catch (_) {}
          if (!mounted) return;
          setState(() {
            _isSubmitting = false;
            _isSuccess = false;
            _message =
                'تم إنشاء البندل وحجز $requested بندل ($bundleId)، لكن تعذر رفع الغلاف في هذه المرحلة: $e — اختياراتك محفوظة ويمكن إعادة المحاولة من إدارة البندلات.';
          });
          return;
        }
      }
      if (!mounted) return;
      final pricingSnapshot = _pricing;
      final savingText = pricingSnapshot == null
          ? ''
          : ' • التوفير: ${pricingSnapshot.saving.toStringAsFixed(2)} ج.م';
      final createdName = _nameController.text.trim();
      setState(() {
        _isSubmitting = false;
        _isSuccess = true;
        _message = 'تم إنشاء البندل بنجاح: "$createdName" — '
            'عدد البندلات المتاحة للبيع: $requested • '
            'السعر النهائي: ${bundlePrice.toStringAsFixed(2)} ج.م$savingText';
      });
      _formKey.currentState!.reset();
      _nameController.clear();
      _descController.clear();
      _priceController.clear();
      setState(() {
        _countController.text = '1';
        _picked.clear();
        _previewFingerprint = null;
        _previewFuture = null;
      });
      await _loadCatalog();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _isSuccess = false;
        // A bundle created before the failure keeps its reservation; the
        // seller keeps the form and can retry or inspect the bundle.
        _message = bundleId.isNotEmpty
            ? 'تم إنشاء البندل ($bundleId) وحجز مخزونه، لكن خطوة لاحقة فشلت: $e — اختياراتك محفوظة.'
            : 'فشل الإنشاء: $e';
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
                    controller: _descController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'وصف البندل (اختياري)',
                        hintText: 'مثال: كل احتياجات الفطار في عرض واحد'),
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
                  TextFormField(
                    controller: _countController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'عدد البندلات المتاحة للبيع',
                        hintText: 'مثال: 5'),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      if (n == null || n < 1) {
                        return 'أدخل عددًا صحيحًا (1 على الأقل)';
                      }
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                  SizedBox(height: 1.h),
                  if (pricing != null) ...[
                    Text(
                        'مجموع الأسعار الأصلية للبندل الواحد: ${pricing.originalTotal.toStringAsFixed(2)} ج.م'),
                    Text(
                        'سعر البندل الواحد: ${pricing.bundlePrice.toStringAsFixed(2)} ج.م',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                        'التوفير في البندل الواحد: ${pricing.saving.toStringAsFixed(2)} ج.م',
                        style: TextStyle(
                            color: pricing.saving >= 0
                                ? Colors.green.shade800
                                : Colors.red,
                            fontWeight: FontWeight.bold)),
                  ],
                  SizedBox(height: 1.h),
                  _countSummary(validation),
                  const Divider(height: 24),
                  ExpansionTile(
                    title: Text('تفاصيل المنتجات (${_picked.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text(
                        'الصورة والكمية والسعر لكل منتج داخل البندل الواحد'),
                    children: [
                      for (final p in _picked) _productDetailRow(p),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'تنبيه: الحساب معاينة فقط وليس ضمانًا للمخزون. يتم الحجز الحقيقي في الدالة الخلفية.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              _stepCard(
                step: '5',
                title: 'معاينة صورة الغلاف',
                subtitle: 'تُركّب تلقائيًا من الصور الأصلية (1080×1080).',
                children: [
                  _coverPreview(),
                  SizedBox(height: 1.h),
                  Text(
                    _deliveryZones.isEmpty
                        ? 'مناطق التوصيل: ستُقرأ وقت الشراء من ملف التاجر (لا توجد مناطق محفوظة حاليًا).'
                        : 'مناطق التوصيل (${_deliveryZones.length}): ${_deliveryZones.take(6).join('، ')}${_deliveryZones.length > 6 ? '…' : ''}',
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 12),
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

  /// Live cover preview: recomposes automatically when the component
  /// set or any original image changes (fingerprint-keyed).
  Widget _coverPreview() {
    if (_picked.length < 2 || _picked.length > 5) {
      return const Text('اختر من منتجين إلى 5 منتجات لعرض معاينة الغلاف.',
          style: TextStyle(color: Colors.grey));
    }
    List<CoverInput> inputs;
    String fingerprint;
    try {
      inputs = _coverInputs();
      fingerprint = coverFingerprint(inputs);
    } catch (e) {
      return Text('تعذر تجهيز المعاينة: $e',
          style: const TextStyle(color: Colors.red));
    }
    // Recompose only when the inputs actually changed.
    if (_previewFuture == null || _previewFingerprint != fingerprint) {
      _previewFingerprint = fingerprint;
      _previewFuture = _coverService
          .composePreviewBytes(inputs)
          .then((bytes) => bytes.toList());
    }
    return FutureBuilder<List<int>>(
      future: _previewFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const AspectRatio(
            aspectRatio: 1,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError || !snap.hasData) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1B5E20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'تعذر تحميل بعض الصور — سيظهر الغلاف النهائي ببدائل محايدة.',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          );
        }
        final bytes = snap.data!;
        return Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                Uint8List.fromList(bytes),
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'معاينة تقريبية بالصور الأصلية — قد تظهر بدائل محايدة عند غياب صورة.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }

  /// Requested-count summary against the live computable maximum.
  Widget _countSummary(BundleValidation validation) {
    final requested = _requestedCount;
    if (!validation.canCreate) {
      return Text(
        validation.message ?? 'غير ممكن حاليًا.',
        style: TextStyle(
            fontWeight: FontWeight.bold, color: Colors.red.shade800),
      );
    }
    final check =
        validateBundleCount(lines: _stockLines, requested: requested);
    if (check.ok) {
      return Text(
        'يمكن إتاحة $requested بندل للبيع (الحد الأقصى ${check.maxBundles}).',
        style: TextStyle(
            fontWeight: FontWeight.bold, color: Colors.green.shade800),
      );
    }
    return Text(
      check.message ?? 'العدد المطلوب يتجاوز الحد الأقصى.',
      style:
          TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade800),
    );
  }

  /// One product row inside the «تفاصيل المنتجات» dropdown.
  Widget _productDetailRow(_PickedLine p) {
    final lineTotal = p.row.price * p.qty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: (p.row.imageUrl != null && p.row.imageUrl!.isNotEmpty)
                ? Image.network(
                    p.row.imageUrl!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _productImageFallback(),
                  )
                : _productImageFallback(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${p.row.productName} (${p.row.unitName})',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                    'الكمية داخل البندل الواحد: ${p.qty} • سعر الوحدة: ${p.row.price.toStringAsFixed(2)} ج.م'),
                Text(
                    'إجمالي الكمية: ${lineTotal.toStringAsFixed(2)} ج.م • المتاح للحجز: ${p.row.availableStock}',
                    style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _productImageFallback() => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF1B5E20),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported,
            color: Colors.white, size: 28),
      );

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
