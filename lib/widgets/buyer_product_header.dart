import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// 🚀 استيراد مكتبة Sizer
import 'package:sizer/sizer.dart'; 

class BuyerProductHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isLoading;

  const BuyerProductHeader({
    super.key,
    required this.title,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ تم تثبيت اللون الأخضر الموحد للتطبيق
    const Color primaryGreen = Color(0xFF4CAF50);

    return AppBar(
      automaticallyImplyLeading: true, 
      backgroundColor: primaryGreen,
      foregroundColor: Colors.white,
      elevation: 0, // جعلناه مسطحاً ليتماشى مع تصميم الأقسام
      titleSpacing: 0, 

      // شكل دائري ناعم للأسفل
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(15),
          bottomRight: Radius.circular(15),
        ),
      ),

      // زر العودة بتنسيق متناسق
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        onPressed: () {
          Navigator.of(context).pop();
        },
      ),

      // العنوان (اسم القسم الفرعي)
      title: isLoading
        ? const SizedBox(
            width: 100,
            child: LinearProgressIndicator(color: Colors.white, backgroundColor: Colors.white38)
          )
        : Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 17.sp, 
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
          ),
      centerTitle: true,

      // ❌ تم حذف قائمة الـ actions (أيقونة السلة والبحث) بالكامل من هنا
      actions: const [
        SizedBox(width: 48), // لموازنة شكل العنوان في المنتصف مع زر الرجوع
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
