// lib/screens/seller/manage_gift_promos_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

class ManageGiftPromosScreen extends StatefulWidget {
  final String currentSellerId;
  const ManageGiftPromosScreen({super.key, required this.currentSellerId});

  @override
  State<ManageGiftPromosScreen> createState() => _ManageGiftPromosScreenState();
}

class _ManageGiftPromosScreenState extends State<ManageGiftPromosScreen> {
  TextStyle get _cairoStyle => GoogleFonts.cairo(fontWeight: FontWeight.bold);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5),
      appBar: AppBar(
        title: Text('إدارة عروض الهدايا',
          style: _cairoStyle.copyWith(fontSize: 16.sp, color: Colors.white)), // تكبير العنوان
        backgroundColor: const Color(0xFF1B5E20),
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('giftPromos')
            .where('sellerId', isEqualTo: widget.currentSellerId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.green));
          }
          if (snapshot.hasError) {
            return Center(child: Text("خطأ: ${snapshot.error}", style: _cairoStyle));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: EdgeInsets.all(12.sp),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              return _buildPromoCard(doc.id, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildPromoCard(String docId, Map<String, dynamic> data) {
    bool isActive = data['status'] == 'active';
    String triggerDesc = "";
    var trigger = data['trigger'] ?? {};
    
    if (trigger['type'] == 'min_order') {
      triggerDesc = "طلب بقيمة ${trigger['value']} ج.م";
    } else {
      triggerDesc = "شراء ${trigger['triggerQuantityBase']} من ${trigger['productName'] ?? 'منتج محدد'}";
    }

    return Card(
      margin: EdgeInsets.only(bottom: 15.sp),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 4,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(12.sp),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(data['promoName'] ?? 'بدون اسم',
                          style: _cairoStyle.copyWith(fontSize: 14.sp, color: Colors.green.shade900)), // خط أكبر
                    ),
                    Switch(
                      value: isActive,
                      activeColor: Colors.green,
                      onChanged: (val) => _toggleStatus(docId, val),
                    ),
                  ],
                ),
                const Divider(),
                _iconText(Icons.bolt, "الشرط: $triggerDesc", Colors.orange.shade800),
                _iconText(Icons.card_giftcard, "الهدية: ${data['giftQuantityPerBase']} ${data['giftUnitName']} ${data['giftProductName']}", Colors.blue.shade800),
                _iconText(Icons.timer, "ينتهي في: ${data['expiryDate']?.toString().split('T')[0] ?? 'غير محدد'}", Colors.red.shade800),
              ],
            ),
          ),
          _buildProgressSection(data),
          // زر الحذف الجديد
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(18), bottomRight: Radius.circular(18))
            ),
            child: TextButton.icon(
              onPressed: () => _confirmDelete(docId, data),
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              label: Text("حذف العرض وإرجاع المخزن", 
                style: _cairoStyle.copyWith(color: Colors.red, fontSize: 11.sp)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildProgressSection(Map<String, dynamic> data) {
    double used = (data['usedQuantity'] ?? 0).toDouble();
    double max = (data['maxQuantity'] ?? 1).toDouble();
    double progress = (used / max).clamp(0.0, 1.0);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 15.sp, vertical: 10.sp),
      color: Colors.grey.shade50,
      child: Row(
        children: [
          Text("الموزع: ${used.toInt()} / ${max.toInt()}",
              style: _cairoStyle.copyWith(fontSize: 11.sp)), // خط أكبر
          SizedBox(width: 12.sp),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade300,
                color: Colors.orange,
                minHeight: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconText(IconData icon, String text, Color iconColor) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.sp),
      child: Row(
        children: [
          Icon(icon, size: 14.sp, color: iconColor), // أيقونة أكبر
          SizedBox(width: 8.sp),
          Expanded(child: Text(text, style: _cairoStyle.copyWith(fontSize: 11.sp, fontWeight: FontWeight.w500, color: Colors.black87))), // خط أكبر
        ],
      ),
    );
  }

  void _confirmDelete(String docId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("تأكيد الحذف؟", style: _cairoStyle),
        content: Text("سيتم حذف العرض وإرجاع الكمية المتبقية لمخزن المنتج الأصلي.", style: _cairoStyle.copyWith(fontWeight: FontWeight.normal)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("إلغاء", style: _cairoStyle)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _deletePromo(docId, data);
            },
            child: Text("حذف", style: _cairoStyle.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePromo(String docId, Map<String, dynamic> data) async {
    try {
      final int remainingToRestore = (data['maxQuantity'] - data['usedQuantity']).toInt();
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final giftRef = FirebaseFirestore.instance.collection('productOffers').doc(data['giftOfferId']);
        final giftDoc = await transaction.get(giftRef);

        if (giftDoc.exists) {
          List units = List.from(giftDoc.data()!['units'] ?? []);
          Map unit0 = Map.from(units[0]);
          
          unit0['availableStock'] = (unit0['availableStock'] ?? 0) + remainingToRestore;
          unit0['reservedForPromos'] = (unit0['reservedForPromos'] ?? 0) - data['maxQuantity'];
          units[0] = unit0;
          
          transaction.update(giftRef, {'units': units});
        }
        transaction.delete(FirebaseFirestore.instance.collection('giftPromos').doc(docId));
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم الحذف بنجاح")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ في الحذف: $e")));
    }
  }

  Future<void> _toggleStatus(String id, bool isNowActive) async {
    await FirebaseFirestore.instance.collection('giftPromos').doc(id).update({
      'status': isNowActive ? 'active' : 'disabled'
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.redeem_outlined, size: 70.sp, color: Colors.grey.shade300),
          Text("لا توجد عروض هدايا حالياً", style: _cairoStyle.copyWith(color: Colors.grey, fontSize: 14.sp)),
        ],
      ),
    );
  }
}

