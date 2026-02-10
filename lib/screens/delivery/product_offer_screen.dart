// lib/screens/delivery/product_offer_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/product_offer_provider.dart';
import '../../theme/app_theme.dart';

class ProductOfferScreen extends StatelessWidget {
  static const routeName = '/product_management';
  const ProductOfferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('إضافة عرض جديد', 
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppTheme.primaryGreen,
        centerTitle: true,
        elevation: 0,
        // ✅ تأمين ظهور أيقونات الساعة والرجوع باللون الأبيض
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // 🛡️ تأمين الشريط السفلي من حواف الشاشة السفلية (Gesture Bar)
      bottomNavigationBar: SafeArea(
        top: false, // لا نريد حماية من الأعلى هنا لأن الـ Body يتكفل بذلك
        child: const _BottomBarButtons(),
      ),
      body: Consumer<ProductOfferProvider>(
        builder: (context, provider, child) {
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 20), // تقليل الـ bottom padding لعدم الحاجة لـ 200 بعد نقل البار
                  child: Column(
                    children: [
                      _NotificationMessage(provider: provider),
                      _buildStepHeader(context, "1", "البحث والتصنيف"),
                      _CategoryAndSearchSection(provider: provider),
                      
                      if (provider.selectedProduct != null) ...[
                        const SizedBox(height: 24),
                        _buildStepHeader(context, "2", "تأكيد المنتج المختار"),
                        const _SelectedProductDetailsSection(),
                        
                        const SizedBox(height: 24),
                        _buildStepHeader(context, "3", "تحديد أسعار الوحدات"),
                        const _ProductUnitsAndPriceSection(),
                        
                        const SizedBox(height: 30),
                        _buildSubmitButton(provider),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStepHeader(BuildContext context, String step, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppTheme.primaryGreen,
            child: Text(step, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(ProductOfferProvider provider) {
    bool canSubmit = provider.selectedProduct != null && provider.selectedUnitPrices.isNotEmpty;
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: canSubmit 
            ? const LinearGradient(colors: [AppTheme.primaryGreen, Color(0xFF2E7D32)])
            : const LinearGradient(colors: [Colors.grey, Colors.blueGrey]),
        boxShadow: [
          if (canSubmit) BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: ElevatedButton(
        onPressed: canSubmit ? provider.submitOffer : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: provider.isLoading 
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text('اعتماد وإضافة العرض للمتجر', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }
}

// --- ويدجت الرسائل بتصميم أنيق ---
class _NotificationMessage extends StatelessWidget {
  final ProductOfferProvider provider;
  const _NotificationMessage({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.message == null) return const SizedBox.shrink();

    final isSuccess = provider.isSuccess;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isSuccess ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSuccess ? Colors.green : Colors.red, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(isSuccess ? Icons.check_circle_outline : Icons.error_outline, 
               color: isSuccess ? Colors.green[700] : Colors.red[700]),
          const SizedBox(width: 12),
          Expanded(child: Text(provider.message!, style: TextStyle(color: isSuccess ? Colors.green[900] : Colors.red[900], fontWeight: FontWeight.w500))),
          IconButton(icon: const Icon(Icons.close, size: 20), onPressed: provider.clearNotification),
        ],
      ),
    );
  }
}

// --- قسم البحث والكارتات الذكية ---
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
    _searchController.addListener(() => widget.provider.searchProducts(_searchController.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.provider;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildDropdown("القسم الرئيسي", p.selectedMainId, p.mainCategories, (id) => p.setSelectedMainCategory(id)),
          const SizedBox(height: 16),
          _buildDropdown("القسم الفرعي", p.selectedSubId, p.subCategories, 
              p.subCategories.isEmpty ? null : (id) => p.setSelectedSubCategory(id)),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            enabled: p.selectedSubId != null,
            decoration: InputDecoration(
              labelText: 'ابحث عن منتج بالاسم...',
              prefixIcon: const Icon(Icons.search, color: AppTheme.primaryGreen),
              filled: true,
              fillColor: p.selectedSubId != null ? Colors.white : Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[200]!)),
            ),
          ),
          if (p.searchResults.isNotEmpty) _buildSearchResults(p),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String? value, List items, Function(String?)? onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
      items: items.map<DropdownMenuItem<String>>((cat) => DropdownMenuItem(value: cat.id, child: Text(cat.name))).toList(),
    );
  }

  Widget _buildSearchResults(ProductOfferProvider p) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey[200]!), borderRadius: BorderRadius.circular(15)),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: p.searchResults.length,
        itemBuilder: (context, i) {
          final prod = p.searchResults[i];
          return ListTile(
            leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(prod.imageUrls.first, width: 45, height: 45, fit: BoxFit.cover)),
            title: Text(prod.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            onTap: () { p.selectProduct(prod); _searchController.clear(); p.searchProducts(''); FocusScope.of(context).unfocus(); },
          );
        },
      ),
    );
  }
}

// --- كارت المنتج المختار (الاحترافي) ---
class _SelectedProductDetailsSection extends StatelessWidget {
  const _SelectedProductDetailsSection();

  @override
  Widget build(BuildContext context) {
    final p = Provider.of<ProductOfferProvider>(context);
    final prod = p.selectedProduct;
    if (prod == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.network(prod.imageUrls.first, width: 80, height: 80, fit: BoxFit.cover),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(prod.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(prod.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.change_circle, color: Colors.blue), onPressed: () => p.selectProduct(null)),
            ],
          ),
        ],
      ),
    );
  }
}

// --- تسعير الوحدات بتصميم كروت تفاعلية ---
class _ProductUnitsAndPriceSection extends StatelessWidget {
  const _ProductUnitsAndPriceSection();

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductOfferProvider>(
      builder: (context, p, child) {
        final units = p.selectedProduct?.units ?? [];
        return Column(
          children: units.map((unit) {
            final name = unit['unitName'];
            final isSelected = p.selectedUnitPrices.containsKey(name);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.grey[50],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: isSelected ? AppTheme.primaryGreen : Colors.grey[300]!, width: isSelected ? 2 : 1),
                boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)] : [],
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    activeColor: AppTheme.primaryGreen,
                    onChanged: (val) => p.setSelectedUnitPrice(name, val == true ? 0.0 : null),
                  ),
                  Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? AppTheme.primaryGreen : Colors.black87)),
                  const Spacer(),
                  if (isSelected)
                    SizedBox(
                      width: 120,
                      child: TextFormField(
                        keyboardType: TextInputType.number,
                        initialValue: p.selectedUnitPrices[name] == 0.0 ? '' : p.selectedUnitPrices[name].toString(),
                        onChanged: (v) => p.setSelectedUnitPrice(name, double.tryParse(v)),
                        decoration: InputDecoration(
                          hintText: 'السعر',
                          suffixText: 'ج.م',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// --- الشريط السفلي المطور ---
class _BottomBarButtons extends StatelessWidget {
  const _BottomBarButtons();

  @override
  Widget build(BuildContext context) {
    // 💡 تم تحويل الـ Align إلى Container بسيط ليتم تغليفه بـ SafeArea في الـ Scaffold
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Row(
        children: [
          _buildNavButton(context, Icons.storefront, "المتجر", Colors.blue, '/buyer_home'),
          const SizedBox(width: 15),
          _buildNavButton(context, Icons.dashboard_customize, "لوحة التحكم", Colors.blueGrey, '/deliveryPrices'),
        ],
      ),
    );
  }

  Widget _buildNavButton(BuildContext context, IconData icon, String label, Color color, String route) {
    return Expanded(
      child: OutlinedButton.icon(
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => Navigator.pushReplacementNamed(context, route),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
