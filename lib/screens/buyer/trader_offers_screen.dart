import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 🎯 تم الإضافة
import 'package:my_test_app/theme/app_theme.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:my_test_app/widgets/trader_offer_card.dart';
import 'package:my_test_app/widgets/buyer_mobile_nav_widget.dart';

class TraderOffersScreen extends StatefulWidget {
  static const String routeName = '/traderOffers';
  final String sellerId;
  
  const TraderOffersScreen({super.key, required this.sellerId});

  @override
  State<TraderOffersScreen> createState() => _TraderOffersScreenState();
}

class _TraderOffersScreenState extends State<TraderOffersScreen> {
  final int _selectedIndex = 0; 
  String _userRole = 'consumer'; // 🎯 الرتبة الافتراضية للأمان

  @override
  void initState() {
    super.initState();
    _getUserRole(); // 🎯 جلب الرتبة عند التشغيل
  }

  // 🎯 دالة جلب الرتبة من التخزين المحلي
  Future<void> _getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('loggedUser');
    if (userJson != null) {
      final user = json.decode(userJson);
      if (mounted) {
        setState(() {
          _userRole = user['role'] ?? 'consumer';
        });
      }
    }
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex && index == 0) {
       Navigator.pushReplacementNamed(context, '/traders');
       return;
    }

    switch (index) {
      case 0: 
        Navigator.pushReplacementNamed(context, '/traders'); 
        break;
      case 1: 
        Navigator.of(context).pushNamedAndRemoveUntil('/buyerHome', (route) => false);
        break;
      case 2: 
        Navigator.pushReplacementNamed(context, '/myOrders'); 
        break;
      case 3: 
        Navigator.pushReplacementNamed(context, '/wallet'); 
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        automaticallyImplyLeading: false, 
        toolbarHeight: 65,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                isDarkMode ? const Color(0xff34495e) : const Color(0xff74d19c),
                isDarkMode ? const Color(0xff1e2a3b) : AppTheme.primaryGreen,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
              onPressed: () => Navigator.of(context).pop(), // 🎯 يرجع للصحفة السابقة (التجار)
            ),
            const Text(
              'عروض التاجر',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Tajawal'),
            ),
          ],
        ),
        elevation: 0,
      ),

      floatingActionButton: Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
          final cartCount = cartProvider.cartTotalItems; 
          return Stack(
            alignment: Alignment.topRight,
            children: [
              FloatingActionButton(
                onPressed: () => Navigator.of(context).pushNamed('/cart'),
                backgroundColor: AppTheme.primaryGreen, 
                elevation: 6,
                child: const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 28),
              ),
              if (cartCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                    child: Text(
                      '$cartCount',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          );
        },
      ),

      // 🎯 إضافة SafeArea لضمان بقاء المحتوى بعيداً عن حواف الشاشة بعد إخفاء الشريط
      body: SafeArea(child: OffersDataFetcher(sellerId: widget.sellerId)), 
      
      // 🎯 الشرط الذكي: بناء الشريط فقط للـ buyer
      bottomNavigationBar: _userRole == 'buyer' 
        ? Consumer<CartProvider>(
            builder: (context, cart, child) => BuyerMobileNavWidget(
              selectedIndex: _selectedIndex,
              onItemSelected: _onItemTapped,
              cartCount: cart.cartTotalItems,
              ordersChanged: false,
            ),
          )
        : null, // يختفي تماماً للـ consumer
    );
  }
}

class OffersDataFetcher extends StatefulWidget {
  final String sellerId;
  const OffersDataFetcher({super.key, required this.sellerId});

  @override
  State<OffersDataFetcher> createState() => _OffersDataFetcherState();
}

class _OffersDataFetcherState extends State<OffersDataFetcher> {
  String _sellerName = "التاجر";
  late Future<List<Map<String, dynamic>>> _offersFuture;

  @override
  void initState() {
    super.initState();
    _offersFuture = _loadOffersWithProductData();
  }

  Future<List<Map<String, dynamic>>> _loadOffersWithProductData() async {
    final db = FirebaseFirestore.instance;
    try {
      final sellerDoc = await db.collection("sellers").doc(widget.sellerId).get();
      if (sellerDoc.exists && mounted) {
        setState(() => _sellerName = sellerDoc.data()?['fullname'] ?? "التاجر");
      }
    } catch (e) {
      debugPrint("Error: $e");
    }

    final offersSnapshot = await db.collection("productOffers")
              .where("sellerId", isEqualTo: widget.sellerId)
              .get();
    
    if (offersSnapshot.docs.isEmpty) return [];

    final List<Map<String, dynamic>> results = [];
    for (var doc in offersSnapshot.docs) {
      final data = doc.data();
      final pId = data['productId']?.toString();
      if (pId != null) {
        final pSnap = await db.collection("products").doc(pId).get();
        if (pSnap.exists) {
          results.add({
            ...data,
            'offerDocId': doc.id,
            'productName': pSnap.data()?['name'] ?? 'منتج غير معروف',
            'imageUrls': pSnap.data()?['imageUrls'],
          });
        }
      }
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _offersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));
        }
        
        final offers = snapshot.data ?? [];
        if (offers.isEmpty) {
          return const Center(child: Text('لا توجد عروض متاحة حالياً.', style: TextStyle(fontFamily: 'Tajawal')));
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.storefront_rounded, color: AppTheme.primaryGreen, size: 28), 
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'عروض $_sellerName',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, 
                  childAspectRatio: 0.7, 
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: offers.length,
                itemBuilder: (context, index) {
                  return TraderOfferCard(
                    offerData: offers[index],
                    offerDocId: offers[index]['offerDocId'],
                    onTap: () {
                      debugPrint("تم تعطيل الانتقال لصفحة التفاصيل");
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
