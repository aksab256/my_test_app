// المسار: lib/widgets/traders_list_widget.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TradersListWidget extends StatelessWidget {
  final List<DocumentSnapshot> traders;
  final ValueChanged<DocumentSnapshot> onTraderTap;

  const TradersListWidget({
    super.key,
    required this.traders,
    required this.onTraderTap,
  });

  Widget _buildTraderCard(BuildContext context, DocumentSnapshot doc) {
    // تأمين جلب البيانات وتحويلها لـ Map
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final String merchantName = data['merchantName']?.toString() ?? "تاجر غير معروف";
    final String businessType = data['businessType']?.toString() ?? "غير محدد";
    final String address = data['address']?.toString() ?? "بدون عنوان";
    final String? merchantLogoUrl = data['merchantLogoUrl']?.toString();
    final num? minOrderTotal = data['minOrderTotal'] as num?;
    
    // 🎯 [التعديل الرئيسي]: جلب مدة التوصيل من حقل deliveryDuration
    // تم التأمين باستخدام ?? لضمان عدم ضرب الكود إذا كان الحقل null أو فارغ
    final String deliveryDuration = (data['deliveryDuration'] != null && data['deliveryDuration'].toString().isNotEmpty)
        ? data['deliveryDuration'].toString()
        : "قيد التحديد"; // القيمة الافتراضية في حال عدم وجود بيانات

    final bool isDeliveryActive = data['isDeliveryActive'] ?? true;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: () => onTraderTap(doc),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 65,
                      height: 65,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Colors.grey[100]!, Colors.grey[50]!],
                        ),
                        border: Border.all(color: Colors.green.withOpacity(0.1), width: 2),
                      ),
                      child: ClipOval(
                        child: merchantLogoUrl != null
                            ? Image.network(
                                merchantLogoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.store_mall_directory_rounded, color: Color(0xFF4CAF50), size: 30),
                              )
                            : const Icon(Icons.store_mall_directory_rounded, color: Color(0xFF4CAF50), size: 30),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            merchantName,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF2D3142)),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.business_center_rounded, color: Color(0xFF4CAF50), size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  businessType,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 15),
                  child: Divider(height: 1, color: Color(0xFFEEEEEE)),
                ),

                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, color: Colors.grey, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        address,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF7B7F91), fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isDeliveryActive ? Icons.check_circle_rounded : Icons.pause_circle_filled_rounded,
                          color: isDeliveryActive ? const Color(0xFF4CAF50) : Colors.orange,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isDeliveryActive ? 'توصيل متاح' : 'التوصيل متوقف',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDeliveryActive ? const Color(0xFF4CAF50) : Colors.orange,
                          ),
                        ),
                        // 🎯 عرض مدة التوصيل بشكل مؤمن
                        if (isDeliveryActive) ...[
                          const SizedBox(width: 10),
                          const Icon(Icons.access_time_filled_rounded, color: Colors.blueGrey, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            deliveryDuration,
                            style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                    if (minOrderTotal != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('أقل طلب', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          Text(
                            '${minOrderTotal.toStringAsFixed(0)} جنيه',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF2D3142)),
                          ),
                        ],
                      ),
                  ],
                ),

                const SizedBox(height: 18),
                
                ElevatedButton(
                  onPressed: () => onTraderTap(doc),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D3142), 
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('استكشف العروض الآن', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (traders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 70, color: Colors.grey[300]),
            const SizedBox(height: 15),
            const Text(
              'لا توجد نتائج مطابقة لبحثك!',
              style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 10.0, bottom: 100.0),
      itemCount: traders.length,
      itemBuilder: (context, index) {
        return _buildTraderCard(context, traders[index]);
      },
    );
  }
}
