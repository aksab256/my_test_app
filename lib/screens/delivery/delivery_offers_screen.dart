// lib/screens/delivery/delivery_offers_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:my_test_app/providers/product_offer_provider.dart';
import 'package:my_test_app/models/logged_user.dart';
import 'package:my_test_app/models/product_offer.dart';
import '../../theme/app_theme.dart';

import 'package:my_test_app/screens/buyer/buyer_home_screen.dart';
import 'package:my_test_app/screens/delivery_merchant_dashboard_screen.dart';

class DeliveryOffersScreen extends StatefulWidget {
  static const routeName = '/delivery-offers';
  const DeliveryOffersScreen({super.key});

  @override
  State<DeliveryOffersScreen> createState() => _DeliveryOffersScreenState();
}

class _DeliveryOffersScreenState extends State<DeliveryOffersScreen> {
  String? _statusMessage;
  String _searchTerm = '';
  String _welcomeMessage = 'مرحباً بك..';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadUserInfoAndFetchOffers());
  }

  Future<void> _loadUserInfoAndFetchOffers() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedUserString = prefs.getString('loggedUser');
    
    if (!mounted) return;
    final provider = Provider.of<ProductOfferProvider>(context, listen: false);

    if (loggedUserString != null) {
      try {
        final loggedUser = LoggedInUser.fromJson(jsonDecode(loggedUserString));
        if (loggedUser.id != null) {
          setState(() => _welcomeMessage = 'أهلاً، ${loggedUser.fullname ?? 'تاجرنا'}');
          await provider.initializeData(loggedUser.id!);
          await provider.fetchOffers(loggedUser.id!);
        }
      } catch (e) {
        _showSnackBar('خطأ في تحميل البيانات', Colors.red);
      }
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('إدارة عروضي الحالية', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primaryGreen,
        centerTitle: true,
        elevation: 0,
      ),
      bottomNavigationBar: _buildBottomBar(context),
      body: Consumer<ProductOfferProvider>(
        builder: (context, provider, child) {
          final offers = provider.offers.where((o) {
            return o.productDetails.name.toLowerCase().contains(_searchTerm.toLowerCase());
          }).toList();

          return Column(
            children: [
              _buildHeader(offers.length),
              _buildSearchBar(),
              Expanded(
                child: provider.isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : offers.isEmpty 
                    ? _buildEmptyState()
                    : _buildOffersList(offers),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- الهيدر الاحترافي ---
  Widget _buildHeader(int count) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppTheme.primaryGreen,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_welcomeMessage, style: const TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('قائمة منتجاتك النشطة', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                child: Text('$count منتج', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: TextField(
        onChanged: (v) => setState(() => _searchTerm = v),
        decoration: InputDecoration(
          hintText: 'ابحث في عروضك...',
          prefixIcon: const Icon(Icons.search, color: AppTheme.primaryGreen),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
      ),
    );
  }

  // --- قائمة العروض بنظام البطاقات ---
  Widget _buildOffersList(List<ProductOffer> offers) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: offers.length,
      itemBuilder: (context, index) {
        final offer = offers[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    offer.productDetails.imageUrls.first,
                    width: 60, height: 60, fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => const Icon(Icons.image_not_supported, size: 40),
                  ),
                ),
                title: Text(offer.productDetails.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text('تاريخ الإضافة: ${DateFormat('yyyy/MM/dd').format(offer.createdAt)}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _confirmDelete(offer.id),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: offer.units.asMap().entries.map((entry) {
                    final unitIndex = entry.key;
                    final unit = entry.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                            child: Text(unit.unitName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 10),
                          Text('${unit.price} ج.م', style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          InkWell(
                            onTap: () => _showEditPriceModal(offer, unitIndex),
                            child: const Text('تعديل السعر', style: TextStyle(color: Colors.blue, fontSize: 12, decoration: TextDecoration.underline)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(String id) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف العرض'),
        content: const Text('هل أنت متأكد من حذف هذا المنتج من قائمة أسعارك؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (res == true) {
      await Provider.of<ProductOfferProvider>(context, listen: false).deleteOffer(id);
      _showSnackBar('تم حذف العرض بنجاح', Colors.green);
    }
  }

  Future<void> _showEditPriceModal(ProductOffer offer, int index) async {
    final controller = TextEditingController(text: offer.units[index].price.toString());
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('تعديل سعر الوحدة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'السعر الجديد لـ (${offer.units[index].unitName})',
                suffixText: 'ج.م',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: () async {
                  final price = double.tryParse(controller.text);
                  if (price != null) {
                    await Provider.of<ProductOfferProvider>(context, listen: false).updateUnitPrice(
                      offerId: offer.id, unitIndex: index, newPrice: price,
                    );
                    Navigator.pop(ctx);
                    _showSnackBar('تم تحديث السعر بنجاح', Colors.blue);
                  }
                },
                child: const Text('حفظ التعديل', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('لا توجد عروض حالياً', style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('ابدأ بإضافة منتجاتك من شاشة الإضافة', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavBtn(context, Icons.dashboard, 'لوحة التحكم', Colors.blueGrey, DeliveryMerchantDashboardScreen.routeName),
          _buildNavBtn(context, Icons.store, 'المتجر', Colors.blue, BuyerHomeScreen.routeName),
        ],
      ),
    );
  }

  Widget _buildNavBtn(BuildContext context, IconData icon, String label, Color color, String route) {
    return InkWell(
      onTap: () => Navigator.pushReplacementNamed(context, route),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
