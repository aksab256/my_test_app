// المسار: lib/widgets/quantity_control.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; 
import 'package:sizer/sizer.dart'; // 🚀 استيراد Sizer


class QuantityControl extends StatefulWidget {
  // 🟢 [تصحيح 1-5]: إعادة تعريف الحقول الأساسية هنا (في StatefulWidget)
  final int initialQuantity;
  final int minQuantity;
  final int maxStock;
  final ValueChanged<int> onQuantityChanged;
  final bool isDisabled;

  const QuantityControl({
    super.key,                                              
    required this.initialQuantity, // تم تصحيح هذا
    required this.minQuantity,     // تم تصحيح هذا
    required this.maxStock,        // تم تصحيح هذا
    required this.onQuantityChanged, // تم تصحيح هذا
    this.isDisabled = false,       // تم تصحيح هذا
  });

  @override
  State<QuantityControl> createState() => _QuantityControlState();
}

class _QuantityControlState extends State<QuantityControl> {
  late int _quantity;

  @override
  void initState() {
    super.initState();                                      
    _quantity = widget.initialQuantity;
    // التأكد من تطبيق المنطق الأولي                        
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateQuantity(widget.initialQuantity);              
    });
  }

  @override
  void didUpdateWidget(covariant QuantityControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuantity != widget.initialQuantity || oldWidget.maxStock != widget.maxStock || oldWidget.minQuantity != widget.minQuantity) {
      _updateQuantity(widget.initialQuantity);
    }
  }

  void _updateQuantity(int newQty) {
    // 🟢 الآن يمكن الوصول إلى الحقول عبر widget.
    int max = widget.maxStock;
    int min = widget.minQuantity;
    int calculatedQty = newQty;

    if (calculatedQty > max || max == 0 || widget.isDisabled) {
      calculatedQty = 0;
    } else if (calculatedQty < min) {
      calculatedQty = min;
    }

    if (_quantity != calculatedQty) {
      setState(() {
        _quantity = calculatedQty;
      });
      widget.onQuantityChanged(calculatedQty);
    }
  }

  // 🟢 [تصحيح 12 و 14]: إعادة تعريف دالة الإنقاص
  void _increment() {
    if (_quantity < widget.maxStock && !widget.isDisabled) {
      _updateQuantity(_quantity + 1);
    }
  }

  // 🟢 [تصحيح 13 و 15]: إعادة تعريف دالة الزيادة
  void _decrement() {
    if (_quantity > widget.minQuantity && !widget.isDisabled) {
      _updateQuantity(_quantity - 1);
    }
  }                                                     
  
  @override
  Widget build(BuildContext context) {
    // 🟢 [تصحيح 6-11]: الآن الحقول موجودة ويمكن الوصول إليها عبر widget.
    final bool canDecrease = _quantity > widget.minQuantity && !widget.isDisabled;                                  
    final bool canIncrease = _quantity < widget.maxStock && !widget.isDisabled;
    final bool isZeroStock = widget.maxStock == 0 || widget.isDisabled;

    // 💡 [M3]: جلب مخطط الألوان
    final colorScheme = Theme.of(context).colorScheme;
    
    // 💡 [تحسين 1]: تغيير الـ Container ليكون شريحة موحدة بارزة (Pill Shape)
    return Container(                                         
      decoration: BoxDecoration(
        color: isZeroStock ? Colors.grey.shade200 : colorScheme.surfaceContainerLow,                                        
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: Colors.grey.shade300, width: 1), 
      ),
      height: 5.h, 
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.max, 
        children: [
          // 1. زر الإنقاص (-)
          _buildButton(
            context,                                                
            icon: Icons.remove,
            onPressed: _decrement, // 🟢 تم تصحيح هذا
            isEnabled: canDecrease,
            isStart: true, 
          ),

          // 2. قيمة الكمية (Text)
          Expanded( 
            child: Center(
              child: isZeroStock
                  ? FittedBox(                                                
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [                                               
                          Icon(
                            Icons.error_outline, 
                            size: 16,
                            color: colorScheme.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'غير متوفر',
                            style: GoogleFonts.cairo(
                              fontSize: 11.sp, 
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Text(
                      '$_quantity',
                      style: GoogleFonts.cairo(
                        fontSize: 14.sp, 
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onSurface, 
                      ),
                    ),
            ),
          ),                                            
          // 3. زر الزيادة (+)
          _buildButton(                                             
            context,
            icon: Icons.add,
            onPressed: _increment, // 🟢 تم تصحيح هذا
            isEnabled: canIncrease,                                 
            isStart: false,
          ),                                                    
        ],
      ),
    );                                                    
  }
                                                          
  // 💡 دالة بناء الأزرار بتصميم موحد مع الـ Container
  Widget _buildButton(
      BuildContext context, {
        required IconData icon,
        required VoidCallback onPressed,
        required bool isEnabled,                                
        required bool isStart, 
      }) {                                                  
    final Color primaryColor = Theme.of(context).primaryColor;                                                      
    final Color disabledColor = Colors.grey.shade400;
    
    final double buttonWidth = 12.w; 
                                                            
    return ClipRRect(
      borderRadius: isStart
          ? const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12))
          : const BorderRadius.only(topRight: Radius.circular(12), bottomRight: Radius.circular(12)),                 
      child: Material(
        color: isEnabled ? primaryColor : Colors.grey.shade300, 
        child: InkWell(                                           
          onTap: isEnabled ? onPressed : null,                    
          child: SizedBox(
            width: buttonWidth, 
            height: double.infinity, 
            child: Icon(
              icon,
              size: 20,
              color: isEnabled ? Colors.white : disabledColor.withOpacity(0.8), 
            ),
          ),
        ),
      ),
    );                                                    
  }
}
