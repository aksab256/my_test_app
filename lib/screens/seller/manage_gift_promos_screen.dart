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
          style: _cairoStyle.copyWith(fontSize: 14.sp, color: Colors.white)),
        backgroundColor: const Color(0xFF1B5E20),
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // التأكد من جلب البيانات بناءً على الـ ID الصحيح
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
            return Center(child: Text("حدث خطأ في جلب البيانات: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: EdgeInsets.all(10.sp),
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
    
    // فك تشفير الـ Trigger بأمان
    var trigger = data['trigger'] ?? {};
    if (trigger['type'] == 'min_order') {
      triggerDesc = "طلب بقيمة ${trigger['value']} ج.م";
    } else {
      triggerDesc = "شراء ${trigger['triggerQuantityBase']} من ${trigger['productName'] ?? 'منتج محدد'}";
    }

    return Card(
      margin: EdgeInsets.only(bottom: 12.sp),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 3,
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.all(12.sp),
            title: Text(data['promoName'] ?? 'بدون اسم',
                style: _cairoStyle.copyWith(fontSize: 12.sp, color: Colors.green.shade900)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 5.sp),
                _iconText(Icons.bolt, "الشرط: $triggerDesc"),
                _iconText(Icons.card_giftcard, "الهدية: ${data['giftQuantityPerBase']} ${data['giftUnitName']} ${data['giftProductName']}"),
                // تعديل طريقة عرض التاريخ ليتوافق مع الـ String
                _iconText(Icons.timer, "ينتهي في: ${data['expiryDate']?.toString().split('T')[0] ?? 'غير محدد'}"),
              ],
            ),
            trailing: Switch(
              value: isActive,
              activeColor: Colors.green,
              onChanged: (val) => _toggleStatus(docId, val),
            ),
          ),
          _buildProgressSection(data),
        ],
      ),
    );
  }

  Widget _buildProgressSection(Map<String, dynamic> data) {
    double used = (data['usedQuantity'] ?? 0).toDouble();
    double max = (data['maxQuantity'] ?? 1).toDouble();
    double progress = (used / max).clamp(0.0, 1.0);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.sp, vertical: 8.sp),
      decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(15), bottomRight: Radius.circular(15))),
      child: Row(
        children: [
          Text("الموزع: ${used.toInt()} / ${max.toInt()}",
              style: _cairoStyle.copyWith(fontSize: 9.sp)),
          SizedBox(width: 10.sp),
          Expanded(
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade300,
              color: Colors.orange,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconText(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 11.sp, color: Colors.grey.shade600),
        SizedBox(width: 5.sp),
        Expanded(child: Text(text, style: _cairoStyle.copyWith(fontSize: 9.sp, fontWeight: FontWeight.normal, color: Colors.black87))),
      ],
    );
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
          Icon(Icons.redeem_outlined, size: 60.sp, color: Colors.grey.shade300),
          Text("لا توجد عروض هدايا حالياً", style: _cairoStyle.copyWith(color: Colors.grey, fontSize: 12.sp)),
        ],
      ),
    );
  }
}

