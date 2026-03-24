// المسار: lib/widgets/manufacturers_banner.dart        
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/providers/manufacturers_provider.dart';
import 'package:my_test_app/models/manufacturer_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

class ManufacturersBanner extends StatefulWidget {
  final Function(String? id) onManufacturerSelected;
  // استقبال معرف القسم الفرعي لفلترة الشركات
  final String? subCategoryId;

  const ManufacturersBanner({
    super.key,
    required this.onManufacturerSelected,
    this.subCategoryId, 
  });

  @override
  State<ManufacturersBanner> createState() => _ManufacturersBannerState();
}

class _ManufacturersBannerState extends State<ManufacturersBanner> {

  @override
  void initState() {
    super.initState();                                      
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // تمرير المعرف للـ Provider لفلترة الشركات عند بدء الشاشة
      Provider.of<ManufacturersProvider>(context, listen: false)
          .fetchManufacturers(subCategoryId: widget.subCategoryId);                          
    });
  }

  // دالة بناء الكارت الفردي لكل شركة مصنعة
  Widget _buildManufacturerCard(ManufacturerModel manufacturer) {
    final bool isAllOption = manufacturer.id == 'ALL';  
    final Color primaryColor = Theme.of(context).primaryColor;
                                                            
    final double radius = 9.w; 
    final double iconSize = 0.5 * radius;
                                                                                                                    
    final Widget iconContent;
    
    if (isAllOption) {
      // خيار عرض "الكل"
      iconContent = Icon(
        Icons.filter_list_alt,                          
        size: iconSize,
        color: primaryColor,                                                                                          
      );
    } else {
      // فحص توافر الصورة في الحقول المحددة (imageUrl أو imagePublicId)
      // ملاحظة: تأكد أن الموديل ManufacturerModel يحتوي على هذه الحقول
      bool hasImage = (manufacturer.imageUrl != null && manufacturer.imageUrl!.isNotEmpty) || 
                      (manufacturer.imagePublicId != null && manufacturer.imagePublicId!.isNotEmpty);

      if (hasImage) {
        // تحديد الرابط المتاح (الأولوية لـ imageUrl)
        String imagePath = (manufacturer.imageUrl != null && manufacturer.imageUrl!.isNotEmpty) 
            ? manufacturer.imageUrl! 
            : manufacturer.imagePublicId!;

        iconContent = ClipOval(
          child: Image.network(
            imagePath,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            // في حالة فشل تحميل الصورة من الرابط، يتم عرض أول حرف كبديل (Fallback)
            errorBuilder: (context, error, stackTrace) => Text(
              manufacturer.name.isNotEmpty ? manufacturer.name[0] : "?",
              style: GoogleFonts.cairo(
                fontSize: 16.sp, 
                fontWeight: FontWeight.w700,                            
                color: primaryColor,                                  
              ),
            ),
          ),
        );
      } else {
        // في حال عدم وجود أي بيانات صور، يتم عرض أول حرف من الاسم
        iconContent = manufacturer.name.isNotEmpty
            ? Text(
                manufacturer.name[0],                                   
                style: GoogleFonts.cairo(
                  fontSize: 16.sp, 
                  fontWeight: FontWeight.w700,                            
                  color: primaryColor,                                  
                ),
              )
            : Icon(Icons.business, size: iconSize, color: primaryColor);
      }
    }

    return InkWell(                                           
      onTap: () => widget.onManufacturerSelected(manufacturer.id),                                                      
      child: Container(
        width: 25.w,                                            
        margin: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [                                              
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),                                                                           
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],                                                    
              ),
              child: CircleAvatar(
                radius: radius, 
                backgroundColor: Colors.white,                          
                child: iconContent,
              ),                                                    
            ),
            const SizedBox(height: 2),
            Text(                                                                                                             
              manufacturer.name,
              textAlign: TextAlign.center,              
              maxLines: 2,                                                                                                    
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),                                                    
      ),                                                    
    );
  }

  @override
  Widget build(BuildContext context) {                      
    final double bannerHeight = 11.h;
                                                          
    return Container(
      color: Colors.white,                                    
      padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),                                                                                                                
      child: Consumer<ManufacturersProvider>(
        builder: (context, provider, child) {
          // حالة التحميل
          if (provider.isLoading) {
            return SizedBox(                            
              height: bannerHeight,                                   
              child: const Center(child: CircularProgressIndicator())
            );                                          
          }
                                                        
          // حالة وجود خطأ
          if (provider.errorMessage != null) {
            return SizedBox(
              height: bannerHeight,                     
              child: Center(
                child: Text(
                  'خطأ في التحميل: ${provider.errorMessage}',
                  style: const TextStyle(color: Colors.red, fontFamily: 'Cairo')
                )
              )
            );
          }
                                                        
          // حالة عدم وجود شركات تابعة لهذا القسم
          if (provider.manufacturers.isEmpty) {
            return const SizedBox.shrink();                                                                               
          }
                                                                  
          return SizedBox(                                          
            height: bannerHeight,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,                                                                               
              padding: const EdgeInsets.symmetric(horizontal: 8.0),                                                                                                                   
              itemCount: provider.manufacturers.length,
              itemBuilder: (context, index) {           
                return _buildManufacturerCard(provider.manufacturers[index]);
              },                                        
            ),
          );                                            
        },                                                    
      ),                                                                                                            
    );
  }
}
