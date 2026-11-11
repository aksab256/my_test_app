// lib/screens/buyer/gifts_tab.dart
//
// تبويب «هدايا المنطقة»: أهلية موحدة عبر GiftEligibilityService
// (BuyerAreaResolver + effectiveLat/effectiveLng + صلاحية + متبقٍ +
// تغطية التاجر + صلاحية عروض المحفز والهدية).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';
import 'package:my_test_app/services/gift_eligibility_service.dart';
import 'package:my_test_app/widgets/gift_promo_card.dart';

class GiftsTab extends StatelessWidget {
  const GiftsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const _GiftsTabBody();
  }
}

class _GiftsTabBody extends StatefulWidget {
  const _GiftsTabBody();

  @override
  State<_GiftsTabBody> createState() => _GiftsTabBodyState();
}

class _GiftsTabBodyState extends State<_GiftsTabBody> {
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  List<EnrichedGift> _gifts = [];
  int _queryLimit = 40;
  bool _hasMore = false;
  String _locKey = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final buyer = Provider.of<BuyerDataProvider>(context);
    final key = GiftEligibilityService.cacheKeyFor(
      buyer.effectiveLat,
      buyer.effectiveLng,
      const [],
    );
    // إعادة التحميل عند تغير الموقع الفعلي فقط.
    if (_locKey.isEmpty) {
      _locKey = key;
      _load();
    } else if (_locKey != key) {
      _locKey = key;
      GiftEligibilityService.clearCache();
      _load();
    }
  }

  Future<void> _load({bool more = false}) async {
    if (more) {
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final buyer = Provider.of<BuyerDataProvider>(context, listen: false);
      final gifts = await GiftEligibilityService.fetchAllEligible(
        db: FirebaseFirestore.instance,
        lat: buyer.effectiveLat,
        lng: buyer.effectiveLng,
        queryLimit: more ? _queryLimit + 40 : _queryLimit,
        useCache: !more,
      );
      if (!mounted) return;
      setState(() {
        if (more) _queryLimit += 40;
        _gifts = gifts;
        // حد تصاعدي: إن امتلأ الحد فقد يوجد المزيد.
        _hasMore = gifts.length >= _queryLimit;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل الهدايا. تحقق من الاتصال وحاول مجدداً.';
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _refresh() async {
    GiftEligibilityService.clearCache();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(30.sp),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 60.sp, color: Colors.grey[400]),
              SizedBox(height: 12.sp),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style:
                    GoogleFonts.cairo(fontSize: 15.sp, color: Colors.grey[700]),
              ),
              SizedBox(height: 12.sp),
              ElevatedButton(
                onPressed: _refresh,
                child: Text('إعادة المحاولة', style: GoogleFonts.cairo()),
              ),
            ],
          ),
        ),
      );
    }
    if (_gifts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: 12.h),
            Icon(Icons.location_searching,
                size: 60.sp, color: Colors.grey[300]),
            SizedBox(height: 15.sp),
            Center(
              child: Text(
                'لا توجد هدايا متاحة لمنطقتك حالياً.',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                    fontSize: 15.sp, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 10.sp, vertical: 15.sp),
        itemCount: _gifts.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _gifts.length) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 10.sp),
              child: Center(
                child: _loadingMore
                    ? const CircularProgressIndicator()
                    : OutlinedButton(
                        onPressed: () => _load(more: true),
                        child: Text('عرض المزيد',
                            style: GoogleFonts.cairo()),
                      ),
              ),
            );
          }
          return GiftPromoCard(gift: _gifts[index]);
        },
      ),
    );
  }
}
