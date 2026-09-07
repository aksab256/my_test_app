// lib/screens/seller/widgets/promo_card_widget.dart

import 'package:flutter/material.dart';

class PromoCardWidget extends StatelessWidget {
  final String promoId;
  final String promoName;
  final String giftText;
  final String triggerText;
  final String expiryDate;
  final num maxQuantity;
  final num usedQuantity;
  final num totalGiftValue;
  final num totalOrderValue;
  final VoidCallback onDisable;
  final VoidCallback onEdit;

  const PromoCardWidget({
    Key? key,
    required this.promoId,
    required this.promoName,
    required this.giftText,
    required this.triggerText,
    required this.expiryDate,
    required this.maxQuantity,
    required this.usedQuantity,
    required this.totalGiftValue,
    required this.totalOrderValue,
    required this.onDisable,
    required this.onEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // حساب المقاييس
    final percentage = maxQuantity > 0 ? (usedQuantity / maxQuantity) * 100 : 0.0;
    final costOfOrdersRatio = totalOrderValue > 0 
        ? (totalGiftValue / totalOrderValue) * 100 
        : 0.0;

    // تحديد ألوان الشريط
    Color barColor = Colors.green;
    if (percentage >= 80) {
      barColor = Colors.red;
    } else if (percentage > 0) {
      barColor = Colors.orange;
    }
    
    // الألوان
    const Color primaryColor = Color(0xff28a745);
    const Color dangerColor = Color(0xffdc3545);
    const Color secondaryColor = Color(0xff007bff);

    return Card(
      elevation: 5,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header (Name & Status)
            Row(
              children: [
                const Chip(
                  label: Text('نشط', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  backgroundColor: primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    promoName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // 2. Details (Gift, Trigger, Expiry)
            _buildDetailRow(context, Icons.card_giftcard, 'الهدية:', giftText),
            _buildDetailRow(context, Icons.ads_click, 'المشغل:', triggerText),
            _buildDetailRow(context, Icons.calendar_today, 'ينتهي في:', expiryDate),
            
            const SizedBox(height: 15),
            const Divider(color: Color(0xffe9ecef), thickness: 1),

            // 3. Metrics Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.5, // لضبط ارتفاع المربعات
              children: [
                _buildMetricItem('قيمة الهدايا المصروفة', '${totalGiftValue.toStringAsFixed(0)} ج.م', Colors.grey.shade700),
                _buildMetricItem('قيمة الطلبات المُرتبطة', '${totalOrderValue.toStringAsFixed(0)} ج.م', Colors.grey.shade700),
              ],
            ),
            
            const SizedBox(height: 10),
            // Metric Danger Ratio
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              decoration: BoxDecoration(
                color: dangerColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: dangerColor.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('تكلفة الهدية من قيمة المبيعات المرتبطة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: dangerColor)),
                  Text('${costOfOrdersRatio.toStringAsFixed(2)}%', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: dangerColor)),
                ],
              ),
            ),
            const SizedBox(height: 15),

            // 4. Usage Bar
            Text(
              'استهلاك المخزون المخصص: (${usedQuantity.toInt()} من ${maxQuantity.toInt()})',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
                minHeight: 18,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                '${percentage.toStringAsFixed(1)}% مستهلك',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: barColor),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 5. Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 18, color: Colors.white),
                    label: const Text('تعديل', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: secondaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onDisable,
                    icon: const Icon(Icons.cancel, size: 18, color: Colors.white),
                    label: const Text('تعطيل', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: dangerColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: color)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

