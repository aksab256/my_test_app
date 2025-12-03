// المسار: lib/screens/checkout/widgets/payment_and_final_widget.dart
import 'package:flutter/material.dart';

// 🎨 تعريف الألوان الثابتة (نحتفظ بها لما لا يمكن استبداله بـ Theme مباشرة)
const Color kTotalAmountColor = Color(0xFFE74C3C); // Primary Red/Error
const Color kGiftBgColor = Color(0xFFE6FFE6); // لون أخضر خفيف للخلفية المحددة (سابقا kPaymentOptionSelectedBg)

class PaymentAndFinalWidget extends StatelessWidget {
  final double originalOrderTotal;
  final double currentCashback;
  final double finalTotalAmount;
  final bool useCashback;
  final String selectedPaymentMethod;
  
  // دمج التخصيصات في القائمة
  final ValueChanged<String> onPaymentMethodChanged;
  final ValueChanged<bool> onCashbackToggle;
  final VoidCallback onPlaceOrder;

  const PaymentAndFinalWidget({
    super.key,
    required this.originalOrderTotal,
    required this.currentCashback,
    required this.finalTotalAmount,
    required this.useCashback,
    required this.selectedPaymentMethod,
    required this.onPaymentMethodChanged,
    required this.onCashbackToggle,
    required this.onPlaceOrder,
  });
  
  // دالة مساعدة لبناء خيار الدفع (تم تحسينها لـ M3)
  Widget _buildPaymentOption({
    required BuildContext context, // نحتاج Context لاستخدام Theme
    required String value,
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    
    return GestureDetector(
      onTap: () => onPaymentMethodChanged(value),
      child: Container( // احتفظنا بالـ Container للتحكم الدقيق في الخلفية والحدود
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(top: 10),
        decoration: BoxDecoration(
          color: isSelected ? kGiftBgColor : colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outline.withOpacity(0.5),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // استخدام Radio List Tile الخاص بـ M3 لإظهار حالة الاختيار
            Radio<String>(
              value: value,
              groupValue: selectedPaymentMethod,
              onChanged: (val) => onPaymentMethodChanged(val!),
              activeColor: colorScheme.primary,
            ),
            // نستخدم الايقونة والعنوان فقط كمرئيات إضافية
            const SizedBox(width: 10),
            Icon(icon, color: isSelected ? colorScheme.primary : colorScheme.onSurface, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                    fontSize: 15, 
                    color: colorScheme.onSurface, 
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // دالة مساعدة لبناء قسم البطاقة الرئيسي (لتقليل التكرار)
  Widget _buildCardSection({
    required BuildContext context,
    required String title,
    required Widget child,
    required bool showDivider,
  }) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      elevation: 1, // ظل خفيف ليتوافق مع M3
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), // زوايا M3
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold, 
                color: colorScheme.primary,
              ),
              textAlign: TextAlign.right,
            ),
            if (showDivider) const Divider(height: 20, thickness: 1),
            child,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    // تحديد ما إذا كان قسم الكاش باك سيظهر
    final bool showCashbackSection = currentCashback > 0;
    
    // حساب الفرق بين الإجمالي الأصلي والنهائي لمعرفة قيمة الخصم المطبق
    final double cashbackApplied = originalOrderTotal - finalTotalAmount;
    final bool hasCashbackApplied = useCashback && cashbackApplied > 0;
    
    return Column(
      children: [
        // 1. قسم الكاش باك/المكافآت
        if (showCashbackSection)
          _buildCardSection(
            context: context,
            title: 'استخدام رصيد النقاط/المكافآت',
            showDivider: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'رصيدك الحالي: ${currentCashback.toStringAsFixed(2)} جنيه',
                  style: TextStyle(fontSize: 15, color: colorScheme.onSurface),
                  textAlign: TextAlign.right,
                ),

                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  textDirection: TextDirection.rtl,
                  children: [
                    Text('استخدام الرصيد في هذا الطلب', style: TextStyle(fontSize: 15, color: colorScheme.onSurface)),
                    Switch(
                      value: useCashback,
                      onChanged: onCashbackToggle,
                      activeColor: colorScheme.primary,
                      inactiveTrackColor: colorScheme.surfaceVariant, // لون M3 أفضل للتبديل
                    ),
                  ],
                ),
              ],
            ),
          ),

        // 2. الإجمالي النهائي
        _buildCardSection(
          context: context,
          title: 'الإجمالي النهائي',
          showDivider: true,
          child: Column(
            children: [
                // سطر الخصم (يظهر فقط إذا تم تطبيق الخصم)
                if (hasCashbackApplied)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            textDirection: TextDirection.rtl,
                            children: [
                                Text(
                                    'خصم رصيد المكافآت:',
                                    style: TextStyle(fontSize: 15, color: colorScheme.primary, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                    '${cashbackApplied.toStringAsFixed(2)} جنيه -', // علامة السالب للخصم
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colorScheme.primary),
                                    textDirection: TextDirection.ltr,
                                ),
                            ],
                        ),
                    ),
                    
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    textDirection: TextDirection.rtl,
                    children: [
                        Text(
                            'المبلغ المطلوب دفعه:',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                        ),
                        Text(
                            '${finalTotalAmount.toStringAsFixed(2)} جنيه',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTotalAmountColor),
                            textDirection: TextDirection.ltr,
                        ),
                    ],
                ),
            ],
          ),
        ),

        // 3. طريقة الدفع
        _buildCardSection(
          context: context,
          title: 'طريقة الدفع',
          showDivider: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // خيارات الدفع
              _buildPaymentOption(
                context: context,
                value: 'cash_on_delivery',
                label: 'الدفع عند الاستلام',
                icon: Icons.money,
                isSelected: selectedPaymentMethod == 'cash_on_delivery',
              ),
              // يمكن إضافة خيارات دفع أخرى هنا
            ],
          ),
        ),

        // 4. زر تأكيد الطلب
        Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: FilledButton.icon( // استخدام FilledButton ليتوافق مع M3 بشكل ممتاز
              onPressed: finalTotalAmount >= 0 ? onPlaceOrder : null, 
              icon: const Icon(Icons.check_circle),
              label: const Text('تأكيد الطلب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                minimumSize: const Size.fromHeight(50), // لجعل الزر يأخذ عرض الشاشة بالكامل
              ),
            ),
        ),
      ],
    );
  }
}
