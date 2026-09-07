import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:provider/provider.dart';
// ✅ التأكد من المسار الصحيح للـ Provider
import '../../providers/buyer_data_provider.dart';

class GiftsTab extends StatelessWidget {
  const GiftsTab({super.key});

  // دالة فحص المضلع الجغرافي
  bool _checkIfInZone(double lat, double lng, List<dynamic> polygonPoints) {
    bool isInside = false;
    var j = polygonPoints.length - 1;
    for (var i = 0; i < polygonPoints.length; i++) {
      if (((polygonPoints[i]['lng'] > lng) != (polygonPoints[j]['lng'] > lng)) &&
          (lat < (polygonPoints[j]['lat'] - polygonPoints[i]['lat']) * (lng - polygonPoints[i]['lng']) / (polygonPoints[j]['lng'] - polygonPoints[i]['lng']) + polygonPoints[i]['lat'])) {
        isInside = !isInside;
      }
      j = i;
    }
    return isInside;
  }

  Future<List<Map<String, dynamic>>> _fetchGiftsWithLocationFilter(BuildContext context) async {
    final buyerProv = Provider.of<BuyerDataProvider>(context, listen: false);
    
    // ✅ التصحيح الحقيقي بناءً على ملف BuyerDataProvider الأصلي:
    final userLat = buyerProv.userLat ?? 0.0;
    final userLng = buyerProv.userLng ?? 0.0;

    final giftsSnap = await FirebaseFirestore.instance
        .collection('giftPromos')
        .where('status', isEqualTo: 'active')
        .get();

    List<Map<String, dynamic>> finalGifts = [];
    Set<String> uniqueSellerIds = giftsSnap.docs.map((d) => d['sellerId'] as String).toSet();
    Map<String, List<dynamic>> sellerZones = {};

    for (var sId in uniqueSellerIds) {
      final sDoc = await FirebaseFirestore.instance.collection('sellers').doc(sId).get();
      if (sDoc.exists && sDoc.data()?['deliveryAreas'] != null) {
        try {
          sellerZones[sId] = jsonDecode(sDoc.data()!['deliveryAreas']);
        } catch (e) {
          debugPrint("JSON Decode Error for seller $sId: $e");
        }
      }
    }

    for (var doc in giftsSnap.docs) {
      final data = doc.data();
      final sId = data['sellerId'];

      if (sellerZones.containsKey(sId)) {
        bool isServiced = false;
        for (var zone in sellerZones[sId]!) {
          if (_checkIfInZone(userLat, userLng, zone['coords'])) {
            isServiced = true;
            break;
          }
        }
        if (isServiced) {
          finalGifts.add(data);
        }
      }
    }
    return finalGifts;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchGiftsWithLocationFilter(context),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final gifts = snapshot.data ?? [];
        if (gifts.isEmpty) {
          return _buildNoGiftsView();
        }

        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 10.sp, vertical: 15.sp),
          itemCount: gifts.length,
          itemBuilder: (context, index) => _buildGiftTile(gifts[index]),
        );
      },
    );
  }

  Widget _buildGiftTile(Map<String, dynamic> gift) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.sp),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(12.sp),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: (gift['giftProductImage'] != null && gift['giftProductImage'].isNotEmpty)
              ? Image.network(gift['giftProductImage'], width: 60.sp, height: 60.sp, fit: BoxFit.cover)
              : Icon(Icons.redeem, size: 40.sp, color: Colors.orange),
        ),
        title: Text(gift['giftProductName'] ?? 'هدية مجانية',
            style: GoogleFonts.cairo(fontSize: 16.sp, fontWeight: FontWeight.bold)),
        subtitle: Text(
          gift['trigger']?['type'] == 'min_order'
              ? "عند طلب بـ ${gift['trigger']['value']} ج أو أكثر"
              : "هدية عند شراء منتجات محددة",
          style: GoogleFonts.cairo(fontSize: 13.sp, color: Colors.grey[600]),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 14.sp, color: Colors.grey),
      ),
    );
  }

  Widget _buildNoGiftsView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(30.sp),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_searching, size: 60.sp, color: Colors.grey[300]),
            SizedBox(height: 15.sp),
            Text(
              "لا توجد هدايا متاحة لمنطقتك حالياً.",
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(fontSize: 15.sp, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

