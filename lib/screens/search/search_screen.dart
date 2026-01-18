// lib/screens/search/search_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:async'; 

import 'package:my_test_app/models/user_role.dart';
import 'package:my_test_app/models/category_model.dart';
import 'package:my_test_app/models/product_model.dart' hide CategoryModel;
import 'package:my_test_app/repositories/product_repository.dart';

// ✅ استيراد الشريط السفلي
import 'package:my_test_app/widgets/category_bottom_nav_bar.dart';

class SearchScreen extends StatefulWidget {
  static const String routeName = '/search';
  final UserRole userRole;

  const SearchScreen({super.key, required this.userRole});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  // حالة الفلاتر
  String? _selectedMainCategory;
  String? _selectedSubCategory;
  ProductSortOption _selectedSort = ProductSortOption.nameAsc;

  // قوائم التصنيفات
  List<CategoryModel> _mainCategories = [];
  List<CategoryModel> _subCategories = [];
  
  // حالة البحث
  List<ProductModel> _searchResults = [];
  bool _isLoading = false;
  bool _isInitial = true;
  
  // ✅ مؤقت لتأخير البحث أثناء الكتابة (Debounce) لتقليل استهلاك السيرفر
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    // ✅ تفعيل مستمع الكتابة
    _searchController.addListener(_onSearchChanged);
  }

  // ✅ تفعيل الـ dispose بشكل كامل لتنظيف الذاكرة
  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ✅ دالة مراقبة الكتابة
  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchController.text.isNotEmpty) {
        _performSearch();
      }
    });
  }

  // --- دوال جلب البيانات ---
  Future<void> _fetchCategories() async {
    final repo = ProductRepository();
    try {
      final main = await repo.fetchMainCategories();
      if (mounted) {
        setState(() {
          _mainCategories = main;
          _fetchSubCategories(null);
        });
      }
    } catch (e) {
      debugPrint("Error fetching categories: $e");
    }
  }

  Future<void> _fetchSubCategories(String? mainCatId) async {
    final repo = ProductRepository();
    try {
      final sub = await repo.fetchSubCategories(mainCatId);
      if (mounted) {
        setState(() {
          _subCategories = sub;
        });
      }
    } catch (e) {
      debugPrint("Error fetching sub categories: $e");
    }
  }

  Future<void> _performSearch() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _isInitial = false;
    });

    final repo = ProductRepository();
    final searchTerm = _searchController.text.trim();
    
    try {
      final results = await repo.searchProducts(
        userRole: widget.userRole,
        searchTerm: searchTerm,
        mainCategoryId: _selectedMainCategory,
        subCategoryId: _selectedSubCategory,
        sortOption: _selectedSort,
      );

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error searching products: $e");
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isLoading = false;
        });
      }
    }
  }

  // --- بناء المكونات ---
  Widget _buildProductCard(ProductModel product) {
    final displayPrice = product.displayPrice != null 
        ? '${product.displayPrice!.toStringAsFixed(2)} ج' 
        : 'غير متوفر';
    
    final imageUrl = product.imageUrls.isNotEmpty 
        ? product.imageUrls.first 
        : 'https://via.placeholder.com/100'; 
    
    final linkTarget = widget.userRole == UserRole.consumer
        ? '/product-offer-details/${product.id}'             
        : '/product-details/${product.id}';                                                                   
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, linkTarget),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.image, size: 50),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                product.name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                displayPrice,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown<T>({
    required T? value,
    required String hintText,
    required List<T> items,
    required String Function(T) itemLabel,
    required T Function(T) itemValue,
    required void Function(T?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          hint: Text(hintText, style: const TextStyle(fontSize: 13)),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: itemValue(item),
              child: Text(itemLabel(item), style: const TextStyle(fontSize: 13)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('البحث عن المنتجات', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // شريط البحث الثابت
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'اكتب اسم المنتج هنا...',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search, color: Colors.green),
                suffixIcon: _searchController.text.isNotEmpty 
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear())
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),

          // منطقة الفلاتر
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                SizedBox(
                  width: 160,
                  child: _buildFilterDropdown<CategoryModel>(
                    value: _selectedMainCategory != null && _mainCategories.any((c) => c.id == _selectedMainCategory)
                        ? _mainCategories.firstWhere((c) => c.id == _selectedMainCategory) : null,
                    hintText: 'القسم الرئيسي',
                    items: _mainCategories,
                    itemLabel: (cat) => cat.name,
                    itemValue: (cat) => cat,
                    onChanged: (cat) {
                      setState(() {
                        _selectedMainCategory = cat?.id;
                        _selectedSubCategory = null;
                      });
                      _fetchSubCategories(cat?.id);
                      _performSearch();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 160,
                  child: _buildFilterDropdown<CategoryModel>(
                    value: _selectedSubCategory != null && _subCategories.any((c) => c.id == _selectedSubCategory)
                        ? _subCategories.firstWhere((c) => c.id == _selectedSubCategory) : null,
                    hintText: 'القسم الفرعي',
                    items: _subCategories,
                    itemLabel: (cat) => cat.name,
                    itemValue: (cat) => cat,
                    onChanged: (cat) {
                      setState(() => _selectedSubCategory = cat?.id);
                      _performSearch();
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),

          // النتائج
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
                            const SizedBox(height: 10),
                            Text(
                              _isInitial ? 'ابدأ البحث الآن' : 'لم نجد نتائج لهذا البحث',
                              style: TextStyle(color: Colors.grey[600], fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) => _buildProductCard(_searchResults[index]),
                      ),
          ),
        ],
      ),
      // ✅ إضافة الشريط السفلي وربطه بأيقونة البحث (Index 3)
      bottomNavigationBar: const CategoryBottomNavBar(),
    );
  }
}
