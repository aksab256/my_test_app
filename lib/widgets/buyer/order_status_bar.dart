// lib/widgets/buyer/order_status_bar.dart
import 'package:flutter/material.dart';
import 'package:my_test_app/utils/order_status_progress.dart';

/// Horizontal tracker shown on every buyer order: the path from a new
/// order to delivery with the order's current stage reflected, plus a
/// distinct red state for cancelled orders.
class OrderStatusBar extends StatelessWidget {
  final String status;

  const OrderStatusBar({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    if (isOrderCancelled(status)) {
      return Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cancel_outlined, size: 16, color: Colors.red.shade700),
            const SizedBox(width: 6),
            Text(
              'ملغي — تم إلغاء هذا الطلب',
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    final int current = orderProgressIndex(status);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF4CAF50)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_shipping_outlined,
                        size: 14, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 4),
                    Text(
                      orderStatusLabel(status),
                      style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: orderProgressFraction(status),
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            textDirection: TextDirection.rtl,
            children: [
              for (int i = 0; i < orderProgressSteps.length; i++)
                Expanded(
                  child: Text(
                    orderProgressSteps[i].label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          i <= current ? FontWeight.bold : FontWeight.normal,
                      color: i <= current
                          ? const Color(0xFF2E7D32)
                          : Colors.grey,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
