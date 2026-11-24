// lib/screens/seller/manage_bundles_screen.dart
//
// Bundle lifecycle UI: active list, disable/enable (release/re-reserve),
// delete (release), and sale consumption. All mutations go through backend
// callables; the screen only streams `sellerBundles`.

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import 'package:my_test_app/data_sources/bundle_cover_service.dart';
import 'package:my_test_app/data_sources/bundle_data_source.dart';
import 'package:my_test_app/models/bundle_model.dart';
import 'package:my_test_app/screens/seller/create_bundle_screen.dart';
import 'package:my_test_app/utils/bundle_cover_layout.dart';

class ManageBundlesScreen extends StatefulWidget {
  final String sellerId;
  const ManageBundlesScreen({super.key, required this.sellerId});

  @override
  State<ManageBundlesScreen> createState() => _ManageBundlesScreenState();
}

class _ManageBundlesScreenState extends State<ManageBundlesScreen> {
  final _dataSource = BundleDataSource();
  final _coverService = BundleCoverService();

  Future<void> _setStatus(SellerBundleModel b, String status) async {
    try {
      await _dataSource.setBundleStatus(
          bundleId: b.id ?? '', status: status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم تحديث حالة "${b.bundleName}"')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  Future<void> _consumeSale(SellerBundleModel b) async {
    final ctrl = TextEditingController(text: '1');
    final count = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل بيع بندل'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration:
              const InputDecoration(labelText: 'عدد البندلات المباعة'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () => Navigator.pop(
                  ctx, int.tryParse(ctrl.text.trim()) ?? 0),
              child: const Text('تأكيد')),
        ],
      ),
    );
    if (count == null || count <= 0) return;
    // Unique per confirmed sale: retries with the same id never double-sell.
    final saleId = 'sale-${DateTime.now().microsecondsSinceEpoch}';
    try {
      final result = await _dataSource.consumeBundleSale(
          bundleId: b.id ?? '', bundleCount: count, saleId: saleId);
      if (mounted) {
        final remaining = result['remainingCount'];
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result['alreadyProcessed'] == true
                ? 'هذه العملية مسجلة مسبقًا — لم يحدث خصم جديد.'
                : 'تم استهلاك $count من الحجز دون إعادة للمتاح.'
                    '${remaining != null ? ' المتبقي للبيع: $remaining.' : ''}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('البندلات',
            style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const CreateBundleScreen())),
        label: const Text('بندل جديد'),
        icon: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<SellerBundleModel>>(
        stream: _dataSource.streamSellerBundles(widget.sellerId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('خطأ: ${snap.error}'));
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const Center(
                child: Text('لا توجد بندلات بعد — أنشئ أول بندل.'));
          }
          return ListView.builder(
            padding: EdgeInsets.all(12.sp),
            itemCount: items.length,
            itemBuilder: (_, i) => _card(items[i]),
          );
        },
      ),
    );
  }

  Widget _coverThumb(SellerBundleModel b) {
    final url = b.coverImageUrl ?? '';
    if (url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          height: 120,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _coverFallback(b),
        ),
      );
    }
    return _coverFallback(b);
  }

  Widget _coverFallback(SellerBundleModel b) {
    return Container(
      height: 72,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1B5E20),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        b.coverStatus == 'upload_failed'
            ? 'تعذر رفع الغلاف — تُعرض المكونات كمرجع'
            : b.coverStatus == 'missing'
                ? 'بدون غلاف بعد — المكونات هي المرجع'
                : 'غلاف ${b.coverStatus}',
        style: const TextStyle(color: Colors.white, fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _card(SellerBundleModel b) {
    final isActive = b.status == 'active';
    return Card(
      margin: EdgeInsets.only(bottom: 12.sp),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(12.sp),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _coverThumb(b),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: Text(b.bundleName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 16))),
                Switch(
                  value: isActive,
                  onChanged: (v) => _setStatus(
                      b, v ? 'active' : 'disabled'),
                ),
              ],
            ),
            if (b.description.isNotEmpty)
              Text(b.description,
                  style: const TextStyle(color: Colors.black54)),
            Text(
                'الحالة: ${b.status} • الحجز: ${b.reservationStatus} • '
                'محجوز: ${b.reservedCount} • مستهلك: ${b.consumedCount} • محرر: ${b.releasedCount}'),
            Text(
                'الإجمالي: ${b.totalPrice} ج.م • الأصلي: ${b.originalTotal} ج.م • التوفير: ${b.saving.toStringAsFixed(2)}'),
            Text(
                'البندلات: متاح ${b.remainingCount} من ${b.bundleCount} • مباع: ${b.soldCount}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
                'الغلاف: ${b.coverStatus} • إصدار ${b.coverVersion}'
                '${b.coverImagePath != null ? ' • ${b.coverImagePath}' : ''}'),
            Text(
              b.deliveryZones.isEmpty
                  ? 'التوصيل: يُتحقق وقت الشراء من ملف التاجر'
                  : 'التوصيل (${b.deliveryZones.length}): ${b.deliveryZones.take(6).join('، ')}',
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const Divider(),
            for (final it in b.items)
              Text('• ${it.productName} (${it.unitName}) × ${it.qtyRequired}'),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _consumeSale(b),
                  icon: const Icon(Icons.point_of_sale),
                  label: const Text('بيع'),
                ),
                TextButton.icon(
                  onPressed: () => _editQuantities(b),
                  icon: const Icon(Icons.edit),
                  label: const Text('تعديل الكميات'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _confirmDelete(b),
                  icon: const Icon(Icons.delete_forever,
                      color: Colors.red),
                  label: const Text('حذف وتحرير الحجز',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editQuantities(SellerBundleModel b) async {
    if (b.status != 'active') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('التعديل متاح للبندلات النشطة فقط.')));
      return;
    }
    final ctrls = {
      for (final it in b.items)
        '${it.offerId}||${it.unitIndex}':
            TextEditingController(text: '${it.qtyRequired}')
    };
    final countCtrl = TextEditingController(text: '${b.bundleCount}');
    final priceCtrl =
        TextEditingController(text: b.totalPrice.toStringAsFixed(2));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل البندل'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              TextField(
                controller: countCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText:
                        'عدد البندلات المتاحة (لا يقل عن المباع: ${b.soldCount})'),
              ),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'السعر النهائي للبندل الواحد (ج.م)'),
              ),
              const Divider(),
              Text('مباع حتى الآن: ${b.soldCount} — المكونات والكميات '
                  'مقفلة بعد أول بيع.'),
              for (final it in b.items)
                TextField(
                  controller: ctrls[
                      '${it.offerId}||${it.unitIndex}'],
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText:
                          '${it.productName} (${it.unitName})'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حفظ')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final items = b.items.map((it) {
        final q = int.tryParse(
                (ctrls['${it.offerId}||${it.unitIndex}']?.text ?? '')
                    .trim()) ??
            0;
        return {
          'offerId': it.offerId,
          'unitIndex': it.unitIndex,
          'qtyRequired': q,
        };
      }).toList();
      final newCount = int.tryParse(countCtrl.text.trim());
      final newPrice = double.tryParse(priceCtrl.text.trim());
      await _dataSource.updateBundleItems(
        bundleId: b.id ?? '',
        items: items,
        bundleCount: newCount,
        totalPrice: (newPrice != null && newPrice > 0) ? newPrice : null,
      );
      // Recompose the cover after any component change (best effort:
      // the reservation update above already succeeded).
      await _recomposeCover(b, items);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تم تعديل الحجز ذريًا وإعادة تركيب الغلاف.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  /// Rebuild the cover from the bundle's own original images and persist
  /// the new path/metadata. Never throws: failures are recorded as
  /// `upload_failed` so the components stay the source of truth.
  Future<void> _recomposeCover(
      SellerBundleModel b, List<Map<String, dynamic>> items) async {
    final bundleId = b.id ?? '';
    if (bundleId.isEmpty || b.items.length < 2 || b.items.length > 5) return;
    final inputs = b.items
        .map((it) => CoverInput(
              offerId: it.offerId,
              unitIndex: it.unitIndex,
              imageUrl: it.imageUrl,
              label: it.productName,
            ))
        .toList();
    try {
      final cover = await _coverService.composeAndUpload(
        bundleDocId: bundleId,
        inputs: inputs,
        version: b.coverVersion + 1,
      );
      await _dataSource.updateBundleItems(
        bundleId: bundleId,
        items: items,
        coverImagePath: cover.coverImagePath,
        coverImageUrl: cover.coverImageUrl,
        coverUpdatedAt: cover.coverUpdatedAt.toIso8601String(),
        coverVersion: cover.coverVersion,
        coverStatus: cover.fallbackCount > 0 ? 'fallback' : 'ready',
      );
    } on BundleCoverException {
      try {
        await _dataSource.updateBundleItems(
          bundleId: bundleId,
          items: items,
          coverVersion: b.coverVersion,
          coverStatus: 'upload_failed',
        );
      } catch (_) {}
    } catch (_) {}
  }

  void _confirmDelete(SellerBundleModel b) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف؟'),
        content: const Text(
            'سيتم تحرير الكميات المحجوزة وإرجاعها للمتاح ثم حذف البندل.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _setStatus(b, 'deleted');
            },
            child: const Text('حذف',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
