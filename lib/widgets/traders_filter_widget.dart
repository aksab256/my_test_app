// المسار: lib/widgets/traders_filter_widget.dart

import 'package:flutter/material.dart';

class TradersFilterWidget extends StatelessWidget {
  final List<String> categories; // القائمة الديناميكية الجديدة
  final String currentFilter; 
  final ValueChanged<String> onFilterSelected; 

  const TradersFilterWidget({
    super.key,
    required this.categories,
    required this.currentFilter,
    required this.onFilterSelected,
  });

  Widget _buildFilterChip(String label, String value, Color primaryColor) {
    final isSelected = currentFilter == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ActionChip(
        label: Text(label),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : primaryColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: isSelected ? primaryColor : Colors.white,
        side: BorderSide(color: primaryColor, width: 1.5),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
        ),
        onPressed: () => onFilterSelected(value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF4CAF50); // لون التمييز
    final List<Widget> filterChips = [
      _buildFilterChip('الكل', 'all', primaryColor),
    ];
    
    // إضافة الأزرار بناءً على الفئات المستخلصة من بيانات التجار
    for (var cat in categories) {
      filterChips.add(_buildFilterChip(cat, cat, primaryColor));
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      color: const Color(0xFFf5f7fa),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true, // للبدء من اليمين
        child: Row(
          children: filterChips,
        ),
      ),
    );
  }
}
