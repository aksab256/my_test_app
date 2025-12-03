// lib/widgets/delivery/product_offer/_product_search_section.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/product_offer_provider.dart';
import '../../../models/product_model.dart';
import '../../../utils/constants.dart'; // افترض وجود ملف للثوابت مثل الألوان

class ProductSearchSection extends StatefulWidget {
  const ProductSearchSection({super.key});

  @override
  State<ProductSearchSection> createState() => _ProductSearchSectionState();
}

class _ProductSearchSectionState extends State<ProductSearchSection> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchTerm = '';
  // 💡 لإدارة ظهور قائمة البحث التلقائي
  OverlayEntry? _overlayEntry;
  // لعمل Delay للبحث
  VoidCallback? _searchDebounce;

  @override
  void initState() {
    super.initState();
    // 💡 يتم تحميل الأقسام الرئيسية أولاً
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductOfferProvider>(context, listen: false).fetchMainCategories();
    });

    _searchFocusNode.addListener(_handleFocusChange);
    _searchController.addListener(_handleSearchInput);
  }

  // ----------------------------------
  // منطق البحث التلقائي (Autosuggest)
  // ----------------------------------

  void _handleSearchInput() {
    final newSearchTerm = _searchController.text.trim();
    if (newSearchTerm == _searchTerm) return;
    _searchTerm = newSearchTerm;

    if (_searchDebounce != null) {
      // إلغاء البحث السابق
      _searchDebounce!();
    }

    _searchDebounce = () {
      if (_searchTerm.length < 2 && _searchTerm.isNotEmpty) return;
      
      // 💡 تنفيذ البحث بعد 300 مللي ثانية
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_searchTerm == _searchController.text.trim()) {
          Provider.of<ProductOfferProvider>(context, listen: false)
              .searchProducts(_searchTerm);
        }
      });
    };
    
    // تشغيل التأخير (Debounce)
    _searchDebounce!(); 
  }

  void _handleFocusChange() {
    if (_searchFocusNode.hasFocus) {
      // إذا كان هناك نص بحث، اعرض النتائج، وإلا اعرض الكل
      if (_searchTerm.isEmpty) {
        Provider.of<ProductOfferProvider>(context, listen: false)
            .searchProducts(''); // يعرض الكل في القسم الفرعي المختار
      }
    } else {
      // عند فقدان التركيز (الخروج من حقل البحث)، نخفي قائمة النتائج بعد تأخير بسيط
      Future.delayed(const Duration(milliseconds: 200), _hideOverlay);
    }
  }

  void _showOverlay(BuildContext context, List<ProductModel> results) {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }

    if (results.isEmpty && _searchTerm.isNotEmpty) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx,
        top: offset.dy + size.height + 5.0, // أسفل حقل البحث
        width: size.width,
        child: Material(
          elevation: 4.0,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 250),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: results.isEmpty && _searchTerm.isNotEmpty
                  ? 1
                  : results.length,
              itemBuilder: (context, index) {
                if (results.isEmpty && _searchTerm.isNotEmpty) {
                  return const ListTile(title: Text('لا توجد نتائج مطابقة.'));
                }
                final product = results[index];
                return _buildSearchItem(product);
              },
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _searchController.removeListener(_handleSearchInput);
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
    _searchController.addListener(_handleSearchInput);
  }

  // ----------------------------------
  // ويدجت عرض نتيجة البحث الفردية
  // ----------------------------------
  Widget _buildSearchItem(ProductModel product) {
    final provider = Provider.of<ProductOfferProvider>(context, listen: false);
    final mainCategoryName = provider.mainCategories.firstWhere(
        (c) => c.id == product.mainId,
        orElse: () => CategoryModel(id: '', name: 'غير معروف', status: ''));
    final subCategoryName = provider.subCategories.firstWhere(
        (c) => c.id == product.subId,
        orElse: () => CategoryModel(id: '', name: 'غير معروف', status: ''));

    return ListTile(
      leading: product.imageUrls.isNotEmpty
          ? Image.network(
              product.imageUrls.first,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
            )
          : const Icon(Icons.box, size: 40, color: Colors.grey),
      title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('الأقسام: ${mainCategoryName.name} / ${subCategoryName.name}'),
      onTap: () {
        // 💡 اختيار المنتج وتحديث البيانات
        provider.selectProduct(product.id);
        _searchController.text = product.name; // لملء حقل البحث باسم المنتج
        _hideOverlay();
        _searchFocusNode.unfocus(); // إخفاء لوحة المفاتيح
      },
    );
  }
  
  // ----------------------------------
  // بناء الواجهة (Build)
  // ----------------------------------
  @override
  Widget build(BuildContext context) {
    return Consumer<ProductOfferProvider>(
      builder: (context, provider, child) {
        // 💡 تحديث قائمة البحث التلقائي عند تغيير النتائج
        if (_searchFocusNode.hasFocus && provider.selectedSubCategoryId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showOverlay(context, provider.searchResults);
          });
        } else {
            // إخفاء الـ Overlay عندما لا يكون هناك تركيز أو لم يتم اختيار قسم فرعي
            WidgetsBinding.instance.addPostFrameCallback((_) => _hideOverlay());
        }

        // ----------------------------------
        // حقول اختيار الأقسام
        // ----------------------------------
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. القسم الرئيسي
            _buildDropdown(
              label: 'القسم الرئيسي:',
              value: provider.selectedMainCategoryId,
              items: provider.mainCategories,
              onChanged: (value) => provider.selectMainCategory(value),
              hint: 'اختر القسم الرئيسي',
              enabled: !provider.isLoading,
            ),
            const SizedBox(height: 15),

            // 2. القسم الفرعي
            _buildDropdown(
              label: 'القسم الفرعي:',
              value: provider.selectedSubCategoryId,
              items: provider.subCategories,
              onChanged: (value) => provider.selectSubCategory(value),
              hint: 'اختر القسم الفرعي',
              enabled: provider.selectedMainCategoryId != null && !provider.isLoading,
            ),
            const SizedBox(height: 20),

            // 3. حقل البحث عن المنتج
            Text('ابحث عن المنتج (ضمن القسم الفرعي المختار):', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'اكتب اسم المنتج للبحث...',
                suffixIcon: provider.isLoading ? const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ) : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabled: provider.selectedSubCategoryId != null && !provider.isLoading,
              ),
            ),
            const SizedBox(height: 20),

            // 4. عرض بيانات المنتج المختار
            _buildSelectedProductDisplay(provider.selectedProduct),
          ],
        );
      },
    );
  }
  
  // ----------------------------------
  // ويدجت Dropdown (دالة مساعدة)
  // ----------------------------------
  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<CategoryModel> items,
    required ValueChanged<String?> onChanged,
    required String hint,
    required bool enabled,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          ),
          value: value,
          hint: Text(hint),
          items: [
            DropdownMenuItem(value: '', child: Text(hint)),
            ...items.map((item) => DropdownMenuItem(
                  value: item.id,
                  child: Text(item.name),
                )),
          ],
          onChanged: enabled ? onChanged : null,
          isExpanded: true,
        ),
      ],
    );
  }

  // ----------------------------------
  // ويدجت عرض بيانات المنتج المختار (دالة مساعدة)
  // ----------------------------------
  Widget _buildSelectedProductDisplay(SelectedProductData? product) {
    if (product == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // اسم المنتج المختار
        Text('المنتج المختار:', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: product.name,
          readOnly: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 15),

        // وصف المنتج
        Text('وصف المنتج:', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: product.description,
          readOnly: true,
          maxLines: 4,
          minLines: 2,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 15),

        // صور المنتج
        Text('صور المنتج:', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        product.imageUrls.isNotEmpty
            ? SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: product.imageUrls.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          product.imageUrls[index],
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              )
            : const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('لا توجد صور لهذا المنتج.', style: TextStyle(color: Colors.grey)),
              ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.removeListener(_handleFocusChange);
    _searchFocusNode.dispose();
    _hideOverlay(); // التأكد من إزالة الـ Overlay
    if (_searchDebounce != null) {
      _searchDebounce!(); // إلغاء أي تأخير معلق
    }
    super.dispose();
  }
}
