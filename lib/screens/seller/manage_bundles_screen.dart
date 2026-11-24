// lib/screens/seller/manage_bundles_screen.dart
//
// Bundle lifecycle UI: active list, disable/enable (release/re-reserve),
// delete (release), and sale consumption. All mutations go through backend
// callables; the screen only streams `sellerBundles`.

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import 'package:my_test_app/data_sources/bundle_data_source.dart';
import 'package:my_test_app/models/bundle_model.dart';
import 'package:my_test_app/screens/seller/create_bundle_screen.dart';

class ManageBundlesScreen extends StatefulWidget {
  final String sellerId;
  const ManageBundlesScreen({super.key, required this.sellerId});

  @override
  State<ManageBundlesScreen> createState() => _ManageBundlesScreenState();
}

class _ManageBundlesScreenState extends State<ManageBundlesScreen> {
  final _dataSource = BundleDataSource();

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
    try {
      await _dataSource.consumeBundleSale(
          bundleId: b.id ?? '', bundleCount: count);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم استهلاك الحجز وخصم المكونات')));
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
            Text(
                'الحالة: ${b.status} • الحجز: ${b.reservationStatus} • '
                'محجوز: ${b.reservedCount} • مستهلك: ${b.consumedCount} • محرر: ${b.releasedCount}'),
            Text(
                'الإجمالي: ${b.totalPrice} ج.م • الأصلي: ${b.originalTotal} ج.م • التوفير: ${b.saving.toStringAsFixed(2)}'),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل كميات المكونات'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
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
      await _dataSource.updateBundleItems(
          bundleId: b.id ?? '', items: items);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تم تعديل الحجز ذريًا.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
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
