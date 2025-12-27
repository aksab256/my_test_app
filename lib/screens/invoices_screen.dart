// lib/screens/invoices_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:my_test_app/screens/invoice_details_screen.dart';
import 'package:my_test_app/services/user_session.dart'; 
import 'package:sizer/sizer.dart';

class InvoiceScreen extends StatefulWidget {
  final String? sellerId;
  const InvoiceScreen({super.key, this.sellerId});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  Stream<QuerySnapshot> _fetchInvoices() {
    // 🎯 تم تصحيح الفحص هنا ليكون آمناً (Null Safe)
    final String? uid = widget.sellerId ??
        ((UserSession.ownerId != null && UserSession.ownerId!.isNotEmpty)
            ? UserSession.ownerId
            : FirebaseAuth.instance.currentUser?.uid);

    if (uid == null) {
      debugPrint("🚨 Error: No valid sellerId found for fetching invoices");
      return const Stream.empty();
    }

    debugPrint("🔍 Fetching invoices for sellerId: $uid");

    return FirebaseFirestore.instance
        .collection('invoices')
        .where('sellerId', isEqualTo: uid)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text('كشف الفواتير الشهرية',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16.sp)),
        backgroundColor: const Color(0xFF007bff),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _fetchInvoices(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("حدث خطأ: ${snapshot.error}", style: const TextStyle(fontFamily: 'Cairo')));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 50.sp, color: Colors.grey),
                  SizedBox(height: 2.h),
                  Text("لا توجد فواتير سابقة لهذا الحساب",
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 13.sp, color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.symmetric(vertical: 2.h, horizontal: 4.w),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final String docId = docs[index].id;

              return Card(
                elevation: 0.5,
                margin: EdgeInsets.only(bottom: 1.5.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF007bff).withOpacity(0.1),
                    child: const Icon(Icons.receipt_outlined, color: Color(0xFF007bff)),
                  ),
                  title: Text(
                    "فاتورة ${_formatDate(data['creationDate'])}",
                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13.sp),
                  ),
                  subtitle: Text(
                    "المبلغ: ${_formatCurrency(data['finalAmount'])}",
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.green.shade700, fontWeight: FontWeight.w600, fontSize: 11.sp),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => InvoiceDetailsScreen(
                          invoiceId: docId,
                          invoiceData: data,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatCurrency(dynamic amount) {
    return "${(amount as num? ?? 0).toStringAsFixed(2)} ج.م";
  }

  String _formatDate(dynamic dateVal) {
    try {
      if (dateVal is Timestamp) {
        return DateFormat('yyyy/MM', 'ar_EG').format(dateVal.toDate());
      } else if (dateVal is String) {
        DateTime dt = DateTime.parse(dateVal);
        return DateFormat('yyyy/MM', 'ar_EG').format(dt);
      }
    } catch (e) {
      return dateVal.toString();
    }
    return dateVal.toString();
  }
}

