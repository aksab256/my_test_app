// lib/screens/auth/client_selection_step.dart
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

typedef SelectionCompleted = void Function({required String country, required String userType});

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
    return Padding(
      // زيادة المسافات الجانبية لتوسيع الكروت
      padding: EdgeInsets.symmetric(horizontal: 5.w),
      child: Column(
        children: [
          SizedBox(height: 3.h),
          Text(
            stepNumber == 1 ? 'أين يقع نشاطك التجاري؟' : 'ما هو دورك في المنصة؟',
            // ✅ تكبير عنوان الصفحة الرئيسي
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w900, color: const Color(0xFF1A1A1A)),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 1.h),
          Text(
            stepNumber == 1 ? 'اختر الدولة لبدء تخصيص تجربتك' : 'اختر نوع الحساب المناسب لطبيعة عملك',
            style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4.h),

          Expanded(
            child: stepNumber == 1
                ? _buildCountrySelection(context)
                : _buildAccountTypeSelection(context),
          ),

          if (stepNumber == 2 && onGoBack != null)
            Padding(
              padding: EdgeInsets.only(bottom: 3.h),
              child: TextButton.icon(
                onPressed: onGoBack,
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 20),
                label: Text('العودة للخطوة السابقة', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCountrySelection(BuildContext context) {
    return ListView(
      children: [
        _OptionCard(
          title: 'جمهورية مصر العربية',
          subtitle: 'ادعم التجارة المحلية والنمو الاقتصادي في مصر',
          icon: Icons.flag_rounded,
          flagColors: const [Colors.red, Colors.white, Colors.black],
          isActive: initialCountry == 'egypt',
          onTap: () => onCountrySelected('egypt'),
        ),
        SizedBox(height: 3.h),
        // ✅ كارت السعودية (قريباً) بتصميم باهت وغير قابل للضغط
        Opacity(
          opacity: 0.6,
          child: _OptionCard(
            title: 'المملكة العربية السعودية',
            subtitle: 'انتظرونا قريباً.. نتوسع لنخدم الخليج العربي',
            icon: Icons.flag_circle_rounded,
            flagColors: const [Color(0xFF006C35), Colors.white],
            isActive: false,
            onTap: () {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text("خدماتنا ستتوفر قريباً في المملكة العربية السعودية"))
               );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAccountTypeSelection(BuildContext context) {
    return ListView(
      children: [
        _OptionCard(
          title: 'تاجر تجزئة (سوبر ماركت)',
          subtitle: 'اطلب بضاعتك بأسعار الجملة مباشرةً، ووفر مجهودك وزود أرباحك.',
          icon: Icons.storefront_rounded,
          iconColor: const Color(0xFF4A69BD),
          isActive: initialUserType == 'buyer',
          onTap: () => onCompleted!(country: initialCountry, userType: 'buyer'),
        ),
        SizedBox(height: 2.5.h),
        _OptionCard(
          title: 'موردين (شركات ومصانع)',
          subtitle: 'افتح سوقاً جديداً لمنتجاتك، وأوصل لآلاف المحلات بضغطة زر واحدة.',
          icon: Icons.local_shipping_rounded,
          iconColor: const Color(0xFFE67E22),
          isActive: initialUserType == 'seller',
          onTap: () => onCompleted!(country: initialCountry, userType: 'seller'),
        ),
        SizedBox(height: 2.5.h),
        _OptionCard(
          title: 'مستهلك (مشتري)',
          subtitle: 'تسوق بذكاء، قارن الأسعار في منطقتك، واجمع نقاط المكافآت مع كل شروة.',
          icon: Icons.person_pin_rounded,
          iconColor: const Color(0xFFE74C3C),
          isActive: initialUserType == 'consumer',
          onTap: () => onCompleted!(country: initialCountry, userType: 'consumer'),
        ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;
  final Color? iconColor;
  final List<Color>? flagColors;

  const _OptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.isActive = false,
    this.iconColor,
    this.flagColors,
  });

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF2D9E68);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.all(2.h), // زيادة الحشو الداخلي للكارت
        decoration: BoxDecoration(
          color: isActive ? primary.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(25), // حواف دائرية أكثر احترافية
          border: Border.all(
            color: isActive ? primary : Colors.grey.shade300,
            width: isActive ? 3 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // أيقونة كبيرة وواضحة
            flagColors != null
              ? _buildFlagIcon(flagColors!)
              : Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: (iconColor ?? primary).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(icon, color: iconColor ?? primary, size: 35),
                ),
            SizedBox(width: 5.w),
            // نصوص الكارت
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    // ✅ الخط هنا 18 (معدل ليتناسب مع sizer)
                    style: TextStyle(
                      fontWeight: FontWeight.w900, 
                      fontSize: 15.sp, // يعادل تقريباً 19-20 بكسل
                      color: isActive ? primary : const Color(0xFFDEDEDE),

                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    subtitle,
                    // ✅ خط الشرح واضح ومقروء
                    style: TextStyle(
                      fontSize: 11.sp, 
                      color: Colors.grey.shade700,
                      height: 1.3, // زيادة المسافة بين السطور لسهولة القراءة
                    ),
                  ),
                ],
              ),
            ),
            if (isActive)
              const Icon(Icons.check_circle_rounded, color: primary, size: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildFlagIcon(List<Color> colors) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade100, width: 3),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)],
      ),
      child: ClipOval(
        child: Column(
          children: colors.map((c) => Expanded(child: Container(color: c))).toList(),
        ),
      ),
    );
  }
}
