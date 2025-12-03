// lib/widgets/delivery/product_offer/_product_units_section.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/product_offer_provider.dart';
import '../../../utils/form_utils.dart'; // افترض وجود دالة لعرض رسائل النظام (showMessage)

class ProductUnitsSection extends StatelessWidget {
  const ProductUnitsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductOfferProvider>(
      builder: (context, provider, child) {
        final product = provider.selectedProduct;

        if (product == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(30.0),
              child: Text(
                'اختر منتجًا لعرض وحداته المتاحة.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('الوحدات المتاحة للعرض:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
            const SizedBox(height: 15),
            
            // قائمة وحدات المنتج
            ...List.generate(product.units.length, (index) {
              final unit = product.units[index];
              return _UnitCheckboxTile(
                unitName: unit.unitName,
                initialPrice: unit.price, // السعر المسجل في الكتالوج
                unitIndex: index,
              );
            }),
          ],
        );
      },
    );
  }
}

class _UnitCheckboxTile extends StatefulWidget {
  final String unitName;
  final double? initialPrice;
  final int unitIndex;

  const _UnitCheckboxTile({
    required this.unitName,
    required this.initialPrice,
    required this.unitIndex,
  });

  @override
  State<_UnitCheckboxTile> createState() => _UnitCheckboxTileState();
}

class _UnitCheckboxTileState extends State<_UnitCheckboxTile> {
  bool _isChecked = false;
  late TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(text: widget.initialPrice != null ? widget.initialPrice!.toStringAsFixed(2) : '');
  }
  
  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  void _handleCheckboxChanged(bool? value, ProductOfferProvider provider) {
    setState(() {
      _isChecked = value ?? false;
      if (!_isChecked) {
        _priceController.text = ''; // مسح القيمة عند التعطيل
        provider.updateSelectedUnit(widget.unitIndex, false, null);
      } else {
        // إعادة تعيين القيمة الافتراضية إذا كانت موجودة
        if (widget.initialPrice != null) {
             _priceController.text = widget.initialPrice!.toStringAsFixed(2);
        }
        // تحديث حالة الوحدة فور التفعيل (حتى لو لم يدخل المستخدم شيئًا بعد)
        _handlePriceChanged(_priceController.text, provider); 
      }
    });
  }

  void _handlePriceChanged(String value, ProductOfferProvider provider) {
    if (!_isChecked) return; // لا نفعل شيئاً إذا لم يتم تحديد الوحدة

    final price = double.tryParse(value);
    
    // 💡 نستخدم هذا السطر فقط لتسجيل القيمة في البروفايدر
    // التحقق من صحة القيمة الكاملة سيتم في دالة submitOffer
    provider.updateSelectedUnit(widget.unitIndex, true, price);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductOfferProvider>(
      builder: (context, provider, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: _isChecked ? Colors.green.withOpacity(0.1) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _isChecked ? Colors.green : Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Checkbox(
                value: _isChecked,
                onChanged: (value) => _handleCheckboxChanged(value, provider),
                activeColor: Colors.green,
              ),
              Expanded(
                child: Text(
                  widget.unitName,
                  style: TextStyle(fontWeight: FontWeight.bold, color: _isChecked ? Colors.green.shade900 : Colors.black87),
                ),
              ),
              const SizedBox(width: 15),
              
              // حقل السعر
              SizedBox(
                width: 120,
                child: TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  enabled: _isChecked,
                  readOnly: !_isChecked, // للقراءة فقط عند عدم التحديد
                  onChanged: (value) => _handlePriceChanged(value, provider),
                  decoration: InputDecoration(
                    hintText: 'السعر',
                    suffixText: 'ج.م',
                    filled: true,
                    fillColor: _isChecked ? Colors.white : Colors.grey.shade200,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
