import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MerchantPointBalanceScreen extends StatelessWidget {
  // معرف التاجر الحالي (مستخرج من تسجيل الدخول)
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          "إدارة أمانات المتجر", 
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // أولاً: نبحث عن وثيقة السوبر ماركت الخاصة بهذا المستخدم
        stream: FirebaseFirestore.instance
            .collection('deliverySupermarkets')
            .where('ownerId', '==', currentUserId)
            .limit(1)
            .snapshots(),
        builder: (context, merchantSnapshot) {
          if (merchantSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          
          if (!merchantSnapshot.hasData || merchantSnapshot.data!.docs.isEmpty) {
            return Center(child: Text("لم يتم العثور على بيانات المتجر"));
          }

          var merchantDoc = merchantSnapshot.data!.docs.first;
          var merchantData = merchantDoc.data() as Map<String, dynamic>;
          String merchantDocId = merchantDoc.id;

          return SingleChildScrollView(
            child: Column(
              children: [
                // 1. الكارت العلوي المبتكر لعرض الرصيد
                _buildTotalBalanceCard(merchantData['walletBalance'] ?? 0.0),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "آخر عمليات التسوية", 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)
                      ),
                      Icon(Icons.history, color: Colors.grey),
                    ],
                  ),
                ),

                // 2. قائمة السجلات (التسويات) من المجموعة الفرعية
                _buildTransactionHistory(merchantDocId),
              ],
            ),
          );
        },
      ),
    );
  }

  // ويجت عرض الرصيد الإجمالي (نقاط الأمان)
  Widget _buildTotalBalanceCard(double balance) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.green[900]!, Colors.green[600]!],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 8),
          )
        ],
      ),
      child: Column(
        children: [
          Text(
            "رصيد نقاط الأمان (العهدة)",
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
          ),
          SizedBox(height: 12),
          Text(
            "${balance.toStringAsFixed(2)} نقطة",
            style: TextStyle(
              color: Colors.white, 
              fontSize: 40, 
              fontWeight: FontWeight.black,
              letterSpacing: 1.2
            ),
          ),
          SizedBox(height: 20),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user_outlined, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text(
                  "تأمين عمليات النقل نشط",
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ويجت عرض تاريخ العمليات
  Widget _buildTransactionHistory(String docId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('deliverySupermarkets')
          .doc(docId)
          .collection('walletLogs') // السجل اللي السيرفر بيكتب فيه
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, logSnapshot) {
        if (!logSnapshot.hasData) return Center(child: CircularProgressIndicator());

        if (logSnapshot.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 50),
            child: Text("لا توجد عمليات تسوية مسجلة حالياً", style: TextStyle(color: Colors.grey)),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16),
          itemCount: logSnapshot.data!.docs.length,
          separatorBuilder: (context, index) => SizedBox(height: 10),
          itemBuilder: (context, index) {
            var log = logSnapshot.data!.docs[index].data() as Map<String, dynamic>;
            double amount = (log['amount'] ?? 0.0).toDouble();
            
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                leading: CircleAvatar(
                  backgroundColor: amount >= 0 ? Colors.green[50] : Colors.red[50],
                  child: Icon(
                    amount >= 0 ? Icons.arrow_downward : Icons.arrow_upward,
                    color: amount >= 0 ? Colors.green : Colors.red,
                    size: 18,
                  ),
                ),
                title: Text(
                  log['details'] ?? "تحديث عهدة",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  log['timestamp'] != null 
                    ? (log['timestamp'] as Timestamp).toDate().toString().substring(0, 16)
                    : "",
                  style: TextStyle(fontSize: 11),
                ),
                trailing: Text(
                  "${amount >= 0 ? '+' : ''}${amount.toStringAsFixed(1)}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 16,
                    color: amount >= 0 ? Colors.green[700] : Colors.red[700]
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
