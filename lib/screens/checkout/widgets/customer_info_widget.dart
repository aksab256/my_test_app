// المسار: lib/screens/checkout/widgets/customer_info_widget.dart
import 'package:flutter/material.dart';

// 🎨 تعريف الألوان بناءً على CSS
const Color kCardBg = Colors.white;
const Color kShadowColor = Color.fromRGBO(0, 0, 0, 0.08);
const Color kSectionTitleColor = Color(0xFF4CAF50);
const Color kLabelColor = Color(0xFF555555);
const Color kDisabledInputBg = Color(0xFFE9ECEF); 

class CustomerInfoWidget extends StatelessWidget {
  final Map<String, dynamic> loggedUser;

  const CustomerInfoWidget({super.key, required this.loggedUser});

  // دالة مساعدة لبناء حقل الإدخال المعطل
  Widget _buildDisabledInput({required String label, required String value, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: kLabelColor,
              fontSize: 14,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: kDisabledInputBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.grey.shade600, size: 18),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    value.isNotEmpty ? value : 'غير متوفر',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade800,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: kShadowColor,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'معلومات العميل',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kSectionTitleColor,
            ),
            textAlign: TextAlign.right,
          ),
          const Divider(height: 25, thickness: 1),
          
          _buildDisabledInput(
            label: 'الاسم الكامل:',
            value: loggedUser['fullname'] ?? '',
            icon: Icons.person,
          ),
          
          _buildDisabledInput(
            label: 'رقم الهاتف:',
            value: loggedUser['phone'] ?? '',
            icon: Icons.phone,
          ),
          
          _buildDisabledInput(
            label: 'البريد الإلكتروني (اختياري):',
            value: loggedUser['email'] ?? '',
            icon: Icons.email,
          ),
          
          _buildDisabledInput(
            label: 'العنوان:',
            value: loggedUser['address'] ?? '',
            icon: Icons.location_on,
          ),
        ],
      ),
    );
  }
}
