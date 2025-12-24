import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sizer/sizer.dart';
import 'package:intl/intl.dart' as intl;

class ManageGiftPromosScreen extends StatefulWidget {
  final String currentSellerId;
  const ManageGiftPromosScreen({super.key, required this.currentSellerId});

  @override
  State<ManageGiftPromosScreen> createState() => _ManageGiftPromosScreenState();
}

class _ManageGiftPromosScreenState extends State<ManageGiftPromosScreen> {
  bool _isLoading = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5),
      appBar: AppBar(
        title: Text('إدارة عروض الهدايا', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1B5E20),
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // جلب العروض النشطة الخاصة بالمورد
        stream: FirebaseFirestore.instance
            .collection('giftPromos')
            .where('sellerId', isEqualTo: widget.currentSellerId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.green));
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
    
    // فك تشفير الـ Trigger
    String triggerDesc = "";
    if (data['trigger']['type'] == 'min_order') {
      triggerDesc = "طلب بقيمة ${data['trigger']['value']} ج.م";
    } else {
      triggerDesc = "شراء ${data['trigger']['triggerQuantityBase']} من ${data['trigger']['productName'] ?? 'منتج محدد'}";
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
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, color: Colors.green.shade900)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 5.sp),
                _iconText(Icons.bolt, "الشرط: $triggerDesc"),
                _iconText(Icons.card_giftcard, "الهدية: ${data['giftQuantityPerBase']} ${data['giftUnitName']} ${data['giftProductName']}"),
                _iconText(Icons.timer, "ينتهي في: ${_formatTimestamp(data['expiryDate'])}"),
              ],
            ),
            trailing: Switch(
              value: isActive,
              activeColor: Colors.green,
              onChanged: (val) => _toggleStatus(docId, val, data),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.sp, vertical: 8.sp),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(15), bottomRight: Radius.circular(15))
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("الموزع: ${data['usedQuantity']} / ${data['maxQuantity']}", 
                    style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold)),
                LinearProgressIndicator(
                  value: (data['usedQuantity'] ?? 0) / (data['maxQuantity'] ?? 1),
                  backgroundColor: Colors.grey.shade300,
                  color: Colors.orange,
                  minHeight: 5,
                ).p(w: 30.w), // إضافة padding عرضي
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _iconText(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 11.sp, color: Colors.grey.shade600),
        SizedBox(width: 5.sp),
        Expanded(child: Text(text, style: TextStyle(fontSize: 10.sp, color: Colors.black87))),
      ],
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "غير محدد";
    DateTime date = (timestamp as Timestamp).toDate();
    return intl.DateFormat('yyyy-MM-dd').format(date);
  }

  Future<void> _toggleStatus(String id, bool current, Map<String, dynamic> data) async {
    // منطق التبديل بين نشط ومعطل
    await FirebaseFirestore.instance.collection('giftPromos').doc(id).update({
      'status': current ? 'active' : 'disabled'
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.redeem_outlined, size: 60.sp, color: Colors.grey.shade300),
          Text("لا توجد عروض هدايا حالياً", style: TextStyle(color: Colors.grey, fontSize: 12.sp)),
        ],
      ),
    );
  }
}

// Extension بسيط للـ Padding لتسهيل الكود
extension PaddingHelper on Widget {
  Widget p({double? w}) => Padding(padding: EdgeInsets.symmetric(horizontal: w ?? 0), child: this);
}

