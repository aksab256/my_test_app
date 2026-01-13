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
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('إدارة قائمة الأسعار', 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
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
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
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

  Widget _buildHeader(int count) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: const BoxDecoration(
        color: AppTheme.primaryGreen,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30), 
          bottomRight: Radius.circular(30)
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_welcomeMessage, 
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('عروضك المتاحة', 
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2), 
                  borderRadius: BorderRadius.circular(15)
                ),
                child: Text('$count منتج', 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // الإصلاح الجذري لمشكلة الـ boxShadow في الـ TextField
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, -20, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: TextField(
          onChanged: (v) => setState(() => _searchTerm = v),
          decoration: InputDecoration(
            hintText: 'ابحث في منتجاتك...',
            prefixIcon: const Icon(Icons.search, color: AppTheme.primaryGreen),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildOffersList(List<ProductOffer> offers) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: offers.length,
      itemBuilder: (context, index) {
        final offer = offers[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      offer.productDetails.imageUrls.isNotEmpty ? offer.productDetails.imageUrls.first : '',
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => const Icon(Icons.fastfood, color: Colors.grey),
                    ),
                  ),
                ),
                title: Text(offer.productDetails.name, 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                subtitle: Text('تحديث: ${DateFormat('dd/MM/yyyy').format(offer.createdAt)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 28),
                  onPressed: () => _confirmDelete(offer.id),
                ),
              ),
              const Divider(height: 1, indent: 20, endIndent: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20), 
                    bottomRight: Radius.circular(20)
                  ),
                ),
                child: Column(
                  children: offer.units.asMap().entries.map((entry) {
                    final unitIndex = entry.key;
                    final unit = entry.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.label_outline, size: 16, color: AppTheme.primaryGreen),
                          const SizedBox(width: 8),
                          Text(unit.unitName, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Text('${unit.price} ج.م', 
                            style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(width: 15),
                          TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.blue.withOpacity(0.1),
                              minimumSize: const Size(60, 30),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                            ),
                            onPressed: () => _showEditPriceModal(offer, unitIndex),
                            child: const Text('تعديل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('حذف المنتج', textAlign: TextAlign.right),
        content: const Text('هل تريد إزالة هذا المنتج من قائمة أسعارك؟ سيختفي من متجر العملاء أيضاً.', textAlign: TextAlign.right),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, elevation: 0),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (res == true) {
      await Provider.of<ProductOfferProvider>(context, listen: false).deleteOffer(id);
      _showSnackBar('تم الحذف بنجاح', Colors.green);
    }
  }

  Future<void> _showEditPriceModal(ProductOffer offer, int index) async {
    final controller = TextEditingController(text: offer.units[index].price.toString());
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, 
          left: 25, right: 25, top: 20
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Text('تعديل سعر ${offer.units[index].unitName}', 
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
            const SizedBox(height: 10),
            Text(offer.productDetails.name, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 25),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
              decoration: InputDecoration(
                suffixText: 'جنيه مصري',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 0
                ),
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
                child: const Text('حفظ السعر الجديد', 
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
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
          Icon(Icons.search_off_rounded, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 20),
          const Text('لم نجد هذا المنتج في قائمتك', 
            style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      height: 75,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavBtn(context, FontAwesomeIcons.chartPie, 'الإحصائيات', Colors.blueGrey, DeliveryMerchantDashboardScreen.routeName),
          _buildNavBtn(context, FontAwesomeIcons.shop, 'عرض المتجر', Colors.blue, BuyerHomeScreen.routeName),
        ],
      ),
    );
  }

  Widget _buildNavBtn(BuildContext context, IconData icon, String label, Color color, String route) {
    return InkWell(
      onTap: () => Navigator.pushReplacementNamed(context, route),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FaIcon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
