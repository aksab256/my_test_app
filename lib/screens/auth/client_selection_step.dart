// lib/screens/auth/client_selection_step.dart - الكود الكامل للتعديل

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart'; // ⭐️⭐️ تم إضافة Sizer ⭐️⭐️

// تعريف الـ Callbacks
typedef SelectionCompleted = void Function({required String country, required String userType});
typedef CountrySelected = void Function(String country);
typedef GoBack = void Function();

class ClientSelectionStep extends StatelessWidget {
  final int stepNumber;
  final Function(String country) onCountrySelected;
  final Function({required String country, required String userType})? onCompleted;
  final VoidCallback? onGoBack;
  final String initialCountry;
  final String initialUserType;

  const ClientSelectionStep({
    super.key,
    required this.stepNumber,
    required this.initialCountry,
    required this.initialUserType,
    required this.onCountrySelected,
    this.onCompleted,
    this.onGoBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          stepNumber == 1 ? 'اختر بلدك' : 'اختر نوع حسابك',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 3.h), // 🎯 ارتفاع نسبي

        // 💡 استخدام Expanded لضمان أن الجزء الأوسط يأخذ المساحة المتبقية
        Expanded(
          child: stepNumber == 1
            ? _buildCountrySelection(context)
            : _buildAccountTypeSelection(context),
        ),

        if (stepNumber == 2 && onGoBack != null)
          Padding(
            padding: EdgeInsets.only(top: 2.h), // 🎯 مسافة نسبية
            child: TextButton.icon(
              onPressed: onGoBack,
              icon: Icon(Icons.arrow_back_rounded, color: Colors.grey, size: 2.5.h), // 🎯 حجم أيقونة نسبي
              label: Text('العودة', style: TextStyle(color: Colors.grey, fontSize: 10.sp)), // 🎯 حجم خط نسبي
            ),
          ),
      ],
    );
  }

  Widget _buildCountrySelection(BuildContext context) {
    // ⭐️ ويدجت اختيار البلد (الخطوة 1) ⭐️
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 2.w), // 🎯 عرض نسبي
        child: ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _OptionCard(
              title: 'جمهورية مصر العربية',
              icon: Icons.flag_rounded,
              iconColor: Colors.red.shade700,
              flagColors: const [Colors.red, Colors.white, Colors.black],
              value: 'egypt',
              isActive: initialCountry == 'egypt',
              onTap: () {
                onCountrySelected('egypt');
              },
            ),
            SizedBox(height: 3.h), // 🎯 ارتفاع نسبي
            _OptionCard(
              title: 'المملكة العربية السعودية',
              icon: Icons.flag_circle_rounded,
              iconColor: Colors.green.shade700,
              flagColors: const [Colors.green, Colors.white],
              value: 'saudi',
              isDisabled: false,
              onTap: () {
                onCountrySelected('saudi');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountTypeSelection(BuildContext context) {
    // ⭐️ ويدجت اختيار نوع الحساب (الخطوة 2) ⭐️

    // 🎯 التعديل 1: تحديد عدد الأعمدة بناءً على عرض الشاشة
    // (يمكن استخدام SizerUtil هنا بشكل غير مباشر أو الاعتماد على MediaQuery مع Sizer)
    final screenWidth = MediaQuery.of(context).size.width;
    // عمود واحد للشاشات الأصغر من 450 (الهاتف)، وعمودين أو ثلاثة للأكبر
    final crossAxisCount = screenWidth > 600 ? 3 : (screenWidth > 450 ? 2 : 1);

    // 🎯 التعديل 2: تعديل نسبة العرض إلى الارتفاع:
    // نستخدم الـ 'h' للحصول على طول متناسب بدلاً من قيمة ثابتة (1.35)
    final aspectRatio = crossAxisCount == 1 ? 3.5 : 1.35; 

    return GridView.count(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 3.w, // 🎯 تباعد نسبي
      mainAxisSpacing: 3.h, // 🎯 تباعد نسبي
      shrinkWrap: true,
      childAspectRatio: aspectRatio,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _OptionCard(
          title: 'تاجر تجزئة',
          icon: Icons.store_mall_directory_rounded,
          iconColor: Colors.indigo.shade600,
          value: 'buyer',
          isActive: initialUserType == 'buyer',
          onTap: () => onCompleted!(country: initialCountry, userType: 'buyer'),
        ),
        _OptionCard(
          title: 'موردين',
          icon: Icons.local_shipping_rounded,
          iconColor: Colors.orange.shade700,
          value: 'seller',
          isActive: initialUserType == 'seller',
          onTap: () => onCompleted!(country: initialCountry, userType: 'seller'),
        ),
        _OptionCard(
          title: 'مستهلك',
          icon: Icons.person_rounded,
          iconColor: Colors.red.shade400,
          value: 'consumer',
          isActive: initialUserType == 'consumer',
          onTap: () => onCompleted!(country: initialCountry, userType: 'consumer'),
        ),
      ],
    );
  }
}

// ----------------------------------------------------
// 💡 ويدجت البطاقة المُستخدمة في الاختيار - تصميم مُكبر وبدون وصف مع تأثيرات
// ----------------------------------------------------
class _OptionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String value;
  final VoidCallback? onTap;
  final bool isActive;
  final bool isDisabled;
  final Color? iconColor;
  final List<Color>? flagColors;

  const _OptionCard({
    required this.title,
    required this.icon,
    required this.value,
    this.onTap,
    this.isActive = false,
    this.isDisabled = false,
    this.iconColor,
    this.flagColors,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final borderColor = isActive
        ? primaryColor
        : isDisabled ? Colors.grey.shade200 : Colors.grey.shade300;

    return Opacity(
      opacity: isDisabled ? 0.4 : 1.0,
      child: Card( 
        elevation: isActive ? 6 : 2,
        shadowColor: isActive ? primaryColor.withOpacity(0.4) : Colors.grey.shade300,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: borderColor,
            width: isActive ? 2.5 : 1.0,
          ),
        ),
        child: InkWell(
          onTap: isDisabled ? null : onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: EdgeInsets.all(3.w), // 🎯 مسافة داخلية نسبية
            decoration: BoxDecoration(
              color: isActive ? primaryColor.withOpacity(0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 💡 عرض العلم والأيقونة
                if (flagColors != null && flagColors!.length > 1)
                  Center(
                    child: Container(
                      width: 6.h, // 🎯 حجم نسبي
                      height: 6.h, // 🎯 حجم نسبي
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: Colors.grey.shade200, width: 1),
                      ),
                      child: ClipOval(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: flagColors!.map((color) => Expanded(
                            child: Container(
                              color: color,
                            ),
                          )).toList(),
                        ),
                      ),
                    ),
                  )
                else
                  Center(
                    child: Icon(icon, size: 5.h, color: iconColor ?? primaryColor), // 🎯 حجم أيقونة نسبي
                  ),

                SizedBox(height: 1.5.h), // 🎯 ارتفاع نسبي

                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.sp, // 🎯 حجم خط نسبي
                    fontWeight: FontWeight.w700,
                    color: isActive ? primaryColor : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
