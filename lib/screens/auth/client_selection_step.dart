import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

typedef SelectionCompleted = void Function({required String country, required String userType});
typedef CountrySelected = void Function(String country);

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
      padding: EdgeInsets.symmetric(horizontal: 2.w),
      child: Column(
        children: [
          Text(
            stepNumber == 1 ? 'أين يقع نشاطك التجاري؟' : 'ما هو دورك في المنصة؟',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1A1A),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 1.h),
          Text(
            stepNumber == 1 ? 'اختر الدولة لبدء تخصيص تجربتك' : 'اختر نوع الحساب المناسب لطبيعة عملك',
            style: TextStyle(fontSize: 9.sp, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4.h),
          
          Expanded(
            child: stepNumber == 1
                ? _buildCountrySelection(context)
                : _buildAccountTypeSelection(context),
          ),

          if (stepNumber == 2 && onGoBack != null)
            TextButton.icon(
              onPressed: onGoBack,
              icon: Icon(Icons.keyboard_arrow_right_rounded, size: 20),
              label: const Text('العودة للخطوة السابقة'),
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
            ),
        ],
      ),
    );
  }

  Widget _buildCountrySelection(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: [
        _OptionCard(
          title: 'جمهورية مصر العربية',
          subtitle: 'ادعم التجارة المحلية في مصر',
          icon: Icons.flag_rounded,
          flagColors: const [Colors.red, Colors.white, Colors.black],
          isActive: initialCountry == 'egypt',
          onTap: () => onCountrySelected('egypt'),
        ),
        SizedBox(height: 2.h),
        _OptionCard(
          title: 'المملكة العربية السعودية',
          subtitle: 'توسع في أسواق الخليج العربي',
          icon: Icons.flag_circle_rounded,
          flagColors: const [Color(0xFF006C35), Colors.white],
          isActive: initialCountry == 'saudi',
          onTap: () => onCountrySelected('saudi'),
        ),
      ],
    );
  }

  Widget _buildAccountTypeSelection(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: [
        _OptionCard(
          title: 'تاجر تجزئة (سوبر ماركت)',
          subtitle: 'أطلب بضاعتك بأسعار الجملة',
          icon: Icons.storefront_rounded,
          iconColor: const Color(0xFF4A69BD),
          isActive: initialUserType == 'buyer',
          onTap: () => onCompleted!(country: initialCountry, userType: 'buyer'),
        ),
        SizedBox(height: 2.h),
        _OptionCard(
          title: 'موردين (شركات ومصانع)',
          subtitle: 'اعرض منتجاتك وزود مبيعاتك',
          icon: Icons.local_shipping_rounded,
          iconColor: const Color(0xFFE67E22),
          isActive: initialUserType == 'seller',
          onTap: () => onCompleted!(country: initialCountry, userType: 'seller'),
        ),
        SizedBox(height: 2.h),
        _OptionCard(
          title: 'مستهلك (مشتري)',
          subtitle: 'تسوق أفضل العروض من حولك',
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
    final primary = const Color(0xFF2D9E68);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: isActive ? primary.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? primary : Colors.grey.shade200,
          width: isActive ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
        leading: flagColors != null 
          ? _buildFlagIcon(flagColors!)
          : Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (iconColor ?? primary).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor ?? primary, size: 28),
            ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.sp, color: isActive ? primary : Colors.black87),
        ),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 8.5.sp, color: Colors.grey.shade500)),
        trailing: isActive 
          ? Icon(Icons.check_circle_rounded, color: primary) 
          : Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Colors.grey.shade300),
      ),
    );
  }

  Widget _buildFlagIcon(List<Color> colors) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade100, width: 2),
      ),
      child: ClipOval(
        child: Column(
          children: colors.map((c) => Expanded(child: Container(color: c))).toList(),
        ),
      ),
    );
  }
}
