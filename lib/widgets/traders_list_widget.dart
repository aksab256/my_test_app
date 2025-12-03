// المسار: lib/widgets/traders_list_widget.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TradersListWidget extends StatelessWidget {
  // استقبال قائمة DocumentSnapshot
  final List<DocumentSnapshot> traders;
  // الدالة تستقبل الـ DocumentSnapshot عند الضغط
  final ValueChanged<DocumentSnapshot> onTraderTap;

  const TradersListWidget({
    super.key,
    required this.traders,
    required this.onTraderTap,
  });

  // 💡 بناء كارت التاجر الواحد
  Widget _buildTraderCard(BuildContext context, DocumentSnapshot doc) {
    // استخدام data()!. لتسهيل الوصول، مع افتراض أن البيانات موجودة
    final data = doc.data() as Map<String, dynamic>;

    final String merchantName = data['merchantName']?.toString() ?? "تاجر غير معروف";
    final String businessType = data['businessType']?.toString() ?? "غير محدد";
    final String address = data['address']?.toString() ?? "بدون عنوان";
    final String? merchantLogoUrl = data['merchantLogoUrl']?.toString();
    final num? minOrderTotal = data['minOrderTotal'] as num?;

    // محاكاة لتقييم افتراضي
    final double rating = (data['rating'] as num?)?.toDouble() ?? 4.0;

    // افتراض وجود حقل isActive للدلالة على حالة التوصيل
    final bool isDeliveryActive = data['isDeliveryActive'] ?? true;


    return InkWell(
      onTap: () => onTraderTap(doc),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. الشعار والاسم والتقييم
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // الشعار (مع استخدام الصورة الافتراضية)
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0xFFddd), width: 2),
                      color: const Color(0xFFf5f7fa),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: merchantLogoUrl != null
                          ? Image.network(
                              merchantLogoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.storefront_rounded, color: Color(0xFF2c3e50), size: 30),
                            )
                          : const Icon(Icons.storefront_rounded, color: Color(0xFF2c3e50), size: 30),
                    ),
                  ),
                  const SizedBox(width: 15),
                  // تفاصيل التاجر
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          merchantName,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2c3e50)),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1), // تنسيق التقييم
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                            const SizedBox(width: 15),
                          ],
                        ),
                        // نوع النشاط
                         Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                                children: [
                                    // 🟢 تم التصحيح: استبدال 'briefcase_rounded' بـ 'business_center_rounded'
                                    const Icon(Icons.business_center_rounded, color: Color(0xFF4CAF50), size: 16),
                                    const SizedBox(width: 5),
                                    Text(businessType, style: const TextStyle(fontSize: 14, color: Color(0xFF4CAF50))),
                                ],
                            ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 2. العنوان وحالة التوصيل والحد الأدنى للطلب
              const SizedBox(height: 15),
              // العنوان
              Row(
                children: [
                    const Icon(Icons.location_on_rounded, color: Color(0xFF777777), size: 16),
                    const SizedBox(width: 5),
                    Expanded(child: Text(address, style: const TextStyle(fontSize: 14, color: Color(0xFF777777)))),
                ],
              ),
              const SizedBox(height: 8),

              // حالة التوصيل والحد الأدنى
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // حالة التوصيل
                  Row(
                    children: [
                      Icon(Icons.local_shipping_rounded, color: isDeliveryActive ? const Color(0xFF4CAF50) : Colors.red, size: 16),
                      const SizedBox(width: 5),
                      Text(
                        isDeliveryActive ? 'توصيل متاح' : 'التوصيل غير متاح حاليًا',
                        style: TextStyle(fontSize: 14, color: isDeliveryActive ? const Color(0xFF4CAF50) : Colors.red),
                      ),
                    ],
                  ),
                  // الحد الأدنى للطلب
                  if (minOrderTotal != null)
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                       decoration: BoxDecoration(
                         color: const Color(0xFFf0f8f0),
                         borderRadius: BorderRadius.circular(15),
                         border: Border.all(color: const Color(0xFFe0eee0)),
                       ),
                       child: Text(
                         'الحد الأدنى: ${minOrderTotal.toStringAsFixed(0)} جنيه',
                         style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF388e3c)),
                       ),
                     ),
                ],
              ),

              // 3. زر عرض العروض
              const SizedBox(height: 15),
              ElevatedButton.icon(
                onPressed: () => onTraderTap(doc),
                icon: const Icon(Icons.local_offer_rounded, size: 20),
                label: const Text('عرض عروض التاجر', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  elevation: 5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (traders.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(30.0),
          child: Text(
            'لا توجد نتائج مطابقة لفلتر البحث!',
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 10.0, bottom: 20.0),
      itemCount: traders.length,
      itemBuilder: (context, index) {
        return _buildTraderCard(context, traders[index]);
      },
    );
  }
}
