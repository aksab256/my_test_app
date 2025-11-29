import 'package:flutter/material.dart';

// ----------------------------------------------------------------------
// Custom Input Field (حقل إدخال مُخصَّص)
// ----------------------------------------------------------------------                       
class CustomInputField extends StatelessWidget {
  final String label;                             
  final String? hintText;                         
  final TextEditingController? controller;        
  final bool isPassword;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;     
  final Function(String)? onChanged;
  final bool isReadOnly;                          
  final Widget? suffixIcon;
  // 💡 تم إضافة خاصية الأيقونة (icon) الجديدة
  final IconData? icon;

  const CustomInputField({
    super.key,                                      
    required this.label,
    this.hintText,                                  
    this.controller,
    this.isPassword = false,                        
    this.keyboardType = TextInputType.text,         
    this.validator,                                 
    this.onChanged,
    this.isReadOnly = false,                        
    this.suffixIcon,
    // 💡 تم إضافة الأيقونة هنا
    this.icon,
  });
                                                  
  @override
  Widget build(BuildContext context) {              
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [                                       
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),                                                    
          child: Text(                                      
            label,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),                                              
        TextFormField(
          controller: controller,
          obscureText: isPassword,                        
          keyboardType: keyboardType,
          readOnly: isReadOnly,                           
          validator: validator,
          onChanged: onChanged,                           
          decoration: InputDecoration(
            hintText: hintText,                             
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),                                              
            // 💡 استخدام الأيقونة كـ prefixIcon
            prefixIcon: icon != null ? Icon(icon, color: Colors.grey.shade600) : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),                       
            suffixIcon: suffixIcon,
          ),                                            
        ),
      ],                                            
    );                                            
  }                                             
}
                                                
// ----------------------------------------------------------------------                       
// Custom Select Box (قائمة مُنسدلة مُخصَّصة)
// 🛠️ تم إضافة دعم Validator
// ----------------------------------------------------------------------
class CustomSelectBox<T, V> extends StatelessWidget {
  final String label;                             
  final String hintText;                          
  final List<T> items;
  final V? selectedValue;                         
  final String Function(T) itemLabel;             
  final V Function(T)? itemValueGetter;
  final Function(V?) onChanged;                   
  // 🆕 حقل التحقق من الصحة
  final String? Function(V?)? validator;

  const CustomSelectBox({                           
    super.key,                                      
    required this.label,
    required this.hintText,
    required this.items,                            
    this.selectedValue,                             
    required this.itemLabel,                        
    this.itemValueGetter,
    required this.onChanged,
    this.validator, // 🆕 أصبح مدعوماً             
  });
                                                  
  @override
  Widget build(BuildContext context) {              
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(                                      
            label,
            style: Theme.of(context).textTheme.titleSmall,
          ),                                            
        ),
        DropdownButtonFormField<V>(
          value: selectedValue,                           
          validator: validator, // تم تمرير الـ Validator هنا
          decoration: InputDecoration(
            hintText: hintText,                             
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),                     
          ),
          items: items.map((T item) {
            final V value = itemValueGetter != null ? itemValueGetter!(item) : item as V;                                                                   
            return DropdownMenuItem<V>(
              value: value,                                   
              child: Text(itemLabel(item)),
            );                                            
          }).toList(),
          onChanged: onChanged,
        ),
      ],                                            
    );
  }                                             
}
