import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// استيراد الشريط السفلي الموحد
import 'package:my_test_app/widgets/category_bottom_nav_bar.dart';

class MyOrdersScreen extends StatelessWidget {
  static const String routeName = '/my_orders';
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: const Text('طلباتي'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF74D19C), Color(0xFF4CAF50)]),
          ),
        ),
      ),
      // 🎯 الشريط السفلي الموحد لضمان التنقل السهل
      bottomNavigationBar: const CategoryBottomNavBar(),
      
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('buyer.id', isEqualTo: user?.uid)
              .orderBy('orderDate', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.green));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text("لا توجد طلبات سابقة"));
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 100), // مساحة إضافية للسكرول فوق الشريط
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                var doc = snapshot.data!.docs[index];
                var data = doc.data() as Map<String, dynamic>;
                
                return _OrderCard(
                  status: data['status'] ?? 'new-order',
                  total: (data['total'] as num?)?.toDouble() ?? 0.0,
                  orderId: doc.id,
                  orderDate: (data['orderDate'] is Timestamp) 
                      ? (data['orderDate'] as Timestamp).toDate() 
                      : DateTime.now(),
                  items: data['items'] as List? ?? [],
                  sellerId: data['sellerId'] ?? '',
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final String status;
  final double total;
  final String orderId;
  final DateTime orderDate;
  final List items;
  final String sellerId;

  const _OrderCard({
    required this.status,
    required this.total,
    required this.orderId,
    required this.orderDate,
    required this.items,
    required this.sellerId,
  });

  // 🎯 دالة لجلب اسم التاجر من مجموعة sellers
  Future<String> _getMerchantName(String id) async {
    if (id.isEmpty) return "تاجر غير معروف";
    try {
      var doc = await FirebaseFirestore.instance.collection('sellers').doc(id).get();
      if (doc.exists) {
        return doc.data()?['merchantName'] ?? "تاجر بدون اسم";
      }
    } catch (e) {
      debugPrint("Error fetching merchant: $e");
    }
    return "تاجر جملة";
  }

  @override
  Widget build(BuildContext context) {
    bool isActive = ['new-order', 'processing', 'shipped'].contains(status);

    return Card(
      elevation: isActive ? 4 : 1,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: isActive ? const BorderSide(color: Colors.green, width: 1.2) : BorderSide.none,
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        leading: Icon(
          status == 'cancelled' ? Icons.cancel : FontAwesomeIcons.fileInvoice,
          color: status == 'cancelled' ? Colors.red : (isActive ? Colors.green : Colors.grey),
        ),
        title: Text("طلب #${orderId.substring(0, 8)}", 
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("التاريخ: ${DateFormat('yyyy-MM-dd').format(orderDate)}", 
              style: const TextStyle(fontSize: 12)),
            
            // 🎯 FutureBuilder لعرض اسم التاجر الحقيقي
            FutureBuilder<String>(
              future: _getMerchantName(sellerId),
              builder: (context, snapshot) {
                return Text(
                  "التاجر: ${snapshot.data ?? 'جاري التحميل...'}",
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 12),
                );
              },
            ),
          ],
        ),
        children: [
          const Divider(),
          ...items.map((item) => ListTile(
            dense: true,
            title: Text(item['name'] ?? 'منتج', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("الكمية: ${item['quantity']} | ${item['unit'] ?? ''}"),
            trailing: Text("${item['price']} ج", style: const TextStyle(color: Colors.blueGrey)),
          )),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("إجمالي الفاتورة:", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("$total جنيه", 
                  style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

