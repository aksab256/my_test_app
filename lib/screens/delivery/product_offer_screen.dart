// lib/screens/delivery/product_offer_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/product_offer_provider.dart';
import '../../theme/app_theme.dart';

// -------------------------------------------------------------
// الشاشة الرئيسية
// -------------------------------------------------------------
class ProductOfferScreen extends StatelessWidget {
  static const routeName = '/product_management';
  const ProductOfferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة عرض لمنتج موجود'),
        backgroundColor: AppTheme.primaryGreen,
      ),
      body: Consumer<ProductOfferProvider>(
        builder: (context, provider, child) {
          return Stack(
            children: [
              SingleChildScrollView(
                // ترك مساحة لزر الإرسال وشريط الأزرار السفلي
                padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 180),
                child: Column(
                  children: [
                    _NotificationMessage(provider: provider),
                    _CategoryAndSearchSection(provider: provider),
                    const SizedBox(height: 30),
                    // 💡 تم استخدام Consumer داخلي هنا لتفعيل زر الإلغاء
                    const _SelectedProductDetailsSection(), 
                    const SizedBox(height: 30),
                    // 💡 تم تعديل المنطق هنا ليطابق منطق الـ JS (الوحدات فقط)
                    const _ProductUnitsAndPriceSection(),
                    const SizedBox(height: 30),
                    _ActionButtonsSection(provider: provider), // زر الإرسال
                  ],
                ),
              ),
              const _BottomBarButtons(), // شريط الأزرار السفلي
            ],
          );
        },
      ),
    );
  }
}

// ---
// ويدجت داخلي 1: رسائل النظام (Success/Error)
// ---
class _NotificationMessage extends StatelessWidget {
  final ProductOfferProvider provider;
  const _NotificationMessage({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.message == null) return const SizedBox.shrink();

    final Color bgColor = provider.isSuccess ? Colors.green.shade50 : Colors.red.shade50;
    final Color textColor = provider.isSuccess ? AppTheme.primaryGreen : Colors.red.shade700;
    final IconData icon = provider.isSuccess ? Icons.check_circle : Icons.error;

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: textColor, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              provider.message!,
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: textColor),
            onPressed: provider.clearNotification,
          ),
        ],
      ),
    );
  }
}

// ---
// ويدجت داخلي 2: الأقسام والبحث
// ---
class _CategoryAndSearchSection extends StatefulWidget {
  final ProductOfferProvider provider;
  const _CategoryAndSearchSection({required this.provider});

  @override
  State<_CategoryAndSearchSection> createState() => _CategoryAndSearchSectionState();
}

class _CategoryAndSearchSectionState extends State<_CategoryAndSearchSection> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchInputChanged);
  }

  void _onSearchInputChanged() {
    // نستخدم الـ debounce في الـ Provider أو Controller لتجنب الاستدعاءات المتكررة للـ API
    widget.provider.searchProducts(_searchController.text.trim());
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchInputChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'اختر المنتج وأدخل تفاصيل العرض',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryGreen,
              ),
            ),
            const Divider(height: 30),

            // القسم الرئيسي
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'القسم الرئيسي', border: OutlineInputBorder()),
              value: provider.selectedMainId,
              items: provider.mainCategories.map((cat) => DropdownMenuItem(
                value: cat.id,
                child: Text(cat.name),
              )).toList(),
              onChanged: (id) => provider.setSelectedMainCategory(id),
              hint: const Text('اختر القسم الرئيسي'),
            ),
            const SizedBox(height: 20),

            // القسم الفرعي
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'القسم الفرعي', border: OutlineInputBorder()),
              value: provider.selectedSubId,
              items: provider.subCategories.map((cat) => DropdownMenuItem(
                value: cat.id,
                child: Text(cat.name),
              )).toList(),
              onChanged: provider.subCategories.isEmpty ? null : (id) => provider.setSelectedSubCategory(id),
              hint: const Text('اختر القسم الفرعي'),
              disabledHint: const Text('اختر قسم رئيسي أولاً'),
            ),
            const SizedBox(height: 20),

            // البحث عن المنتج
            TextFormField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'ابحث عن المنتج (ضمن القسم الفرعي المختار):',
                hintText: 'اكتب اسم المنتج للبحث...',
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(Icons.search),
                enabled: provider.selectedSubId != null,
              ),
              enabled: provider.selectedSubId != null,
            ),

            // نتائج البحث (Autocomplete dropdown)
            if (provider.searchResults.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).cardColor,
                ),
                margin: const EdgeInsets.only(top: 8),
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: provider.searchResults.length,
                  itemBuilder: (context, index) {
                    final product = provider.searchResults[index];
                    return ListTile(
                      leading: (product.imageUrls.isNotEmpty)
                          ? Image.network(
                              product.imageUrls.first,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 50, height: 50, color: Colors.grey.shade200, child: const Icon(Icons.error_outline),
                              ),
                            )
                          : const Icon(Icons.image, size: 40, color: Colors.grey),
                      title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('القسم: ${product.mainId}/${product.subId}'),
                      onTap: () {
                        provider.selectProduct(product);
                        // مسح قائمة البحث عند الاختيار
                        provider.searchProducts('');
                        _searchController.text = product.name;
                      },
                    );
                  },
                  separatorBuilder: (context, index) => const Divider(height: 0),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 💡 ويدجت داخلي 3: تفاصيل المنتج المختار (تم تعديله ليصبح Consumer مع زر إلغاء)
// -------------------------------------------------------------
class _SelectedProductDetailsSection extends StatelessWidget {
  const _SelectedProductDetailsSection();

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductOfferProvider>(
      builder: (context, p, child) {
        final selectedProduct = p.selectedProduct;

        if (selectedProduct == null) {
          return const SizedBox.shrink();
        }
        
        const Color accentColor = Colors.blue;
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(25.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'تفاصيل المنتج المختار',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: accentColor),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        // استخدام دالة selectProduct(null) لمسح المنتج
                        p.selectProduct(null); 
                      }, 
                      icon: const Icon(Icons.close, color: Colors.red), 
                      label: const Text('إلغاء الاختيار/تغيير المنتج', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ],
                ),
                const Divider(height: 20),
                // اسم المنتج
                TextFormField(
                  initialValue: selectedProduct.name,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'المنتج المختار',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: AppTheme.scaffoldLight,
                  ),
                ),
                const SizedBox(height: 15),
                // وصف المنتج
                TextFormField(
                  initialValue: selectedProduct.description,
                  readOnly: true,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'وصف المنتج',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: AppTheme.scaffoldLight,
                  ),
                ),
                const SizedBox(height: 15),
                // صور المنتج
                const Text('صور المنتج:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: selectedProduct.imageUrls.map((url) => Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 100,
                            height: 100,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// -------------------------------------------------------------
// 💡 ويدجت داخلي 4: الوحدات والأسعار (النسخة النهائية المطابقة لمنطق الـ JS)
// -------------------------------------------------------------
class _ProductUnitsAndPriceSection extends StatelessWidget {
  const _ProductUnitsAndPriceSection();

  @override
  Widget build(BuildContext context) {
    // استخدام Consumer داخلياً لضمان قراءة الحالة المحدثة عند تغيير selectedProduct
    return Consumer<ProductOfferProvider>(
      builder: (context, p, child) {
        final selectedProduct = p.selectedProduct;
        final units = selectedProduct?.units; // القراءة من الـ p المحدث

        const Color accentColor = Colors.blue;

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(25.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'الوحدات المتاحة للعرض',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: accentColor),
                ),
                const Divider(height: 20),

                if (selectedProduct == null) 
                  const Text(
                    'اختر منتجًا لعرض وحداته المتاحة.',
                    style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                  )
                else if (units == null || units.isEmpty) 
                  const Text(
                    '⚠️ لا توجد وحدات متاحة لهذا المنتج في الكتالوج.',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  )
                else
                  ...units.map((unit) {
                    // التأكد من أن الوحدة هي Map<String, dynamic> قبل القراءة
                    if (unit is! Map<String, dynamic>) return const SizedBox.shrink();

                    final String unitName = unit['unitName'] ?? 'وحدة غير مسماة';
                    // 🚨 تم إزالة أي قراءة لـ 'price' الافتراضي من الكتالوج (منطق JS)
                    
                    final bool isSelected = p.selectedUnitPrices.containsKey(unitName);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryGreen.withOpacity(0.05) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: isSelected,
                              onChanged: (bool? checked) {
                                if (checked == true) {
                                  // عند التحديد، استخدم القيمة الحالية إذا كانت موجودة، وإلا استخدم 0.0 لتمكين الحقل
                                  final priceToUse = p.selectedUnitPrices.containsKey(unitName)
                                      ? p.selectedUnitPrices[unitName]
                                      : 0.0;
                                  p.setSelectedUnitPrice(unitName, priceToUse);
                                } else {
                                  // عند إلغاء التحديد، قم بإزالة الوحدة
                                  p.setSelectedUnitPrice(unitName, null);
                                }
                              },
                              activeColor: AppTheme.primaryGreen,
                            ),
                            Expanded(
                              child: Text(
                                unitName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? AppTheme.primaryGreen : Theme.of(context).textTheme.bodyLarge?.color,
                                ),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                keyboardType: TextInputType.number,
                                // 💡 العرض: إذا كانت الوحدة مختارة، اعرض السعر الذي أدخله التاجر، وإلا اجعله فارغاً.
                                initialValue: isSelected 
                                    ? (p.selectedUnitPrices[unitName] == 0.0 ? '' : p.selectedUnitPrices[unitName]?.toStringAsFixed(2))
                                    : '', // فارغ لطلب إدخال السعر
                                enabled: isSelected,
                                decoration: const InputDecoration(
                                  labelText: 'السعر',
                                  suffixText: 'ر.س',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                                  contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                ),
                                onChanged: (value) {
                                  final price = double.tryParse(value);
                                  if (isSelected) {
                                    // تخزين القيمة المدخلة في الـ Provider
                                    p.setSelectedUnitPrice(unitName, price);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---
// ويدجت داخلي 5: زر الإرسال
// ---
class _ActionButtonsSection extends StatelessWidget {
  final ProductOfferProvider provider;
  const _ActionButtonsSection({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.add_box_rounded, color: Colors.white),
        label: const Text(
          'إضافة العرض',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryGreen,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: provider.selectedProduct == null || provider.selectedUnitPrices.isEmpty
            ? null // تعطيل الزر إذا لم يتم اختيار منتج أو وحدة
            : provider.submitOffer,
      ),
    );
  }
}

// ---
// ويدجت داخلي 6: الشريط السفلي (Bottom Bar)
// ---
class _BottomBarButtons extends StatelessWidget {
  const _BottomBarButtons();

  @override
  Widget build(BuildContext context) {
    // 💡 تصحيح الخطأ: تم تحديد درجات اللون مباشرة كـ Color لتجنب خطأ shade600
    const Color buttonColor1 = Colors.blue;
    const Color buttonColor2 = Color(0xFF757575); // تم استخدام قيمة لون ثابتة لـ Colors.grey.shade600

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.shopping_basket),
                  label: const Text('العودة للمتجر'),
                  onPressed: () {
                    // التوجيه إلى شاشة المشترين (BuyerHomeScreen)
                    Navigator.of(context).pushReplacementNamed('/buyer_home');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor1, // استخدام اللون المُعرف
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.settings),
                  label: const Text('لوحة التحكم'),
                  onPressed: () {
                    // التوجيه إلى شاشة لوحة التحكم الخاصة بالدليفري
                    Navigator.of(context).pushReplacementNamed('/deliveryPrices');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor2, // استخدام اللون المُعرف
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

