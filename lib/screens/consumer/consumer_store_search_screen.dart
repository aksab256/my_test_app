// lib/screens/consumer/consumer_store_search_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart'; // 💡 تم استبدال Google Maps بـ Flutter Map
// 💡 لاستخدام LatLng و Distance الخاصة بـ flutter_map
import 'package:latlong2/latlong.dart' show LatLng, Distance;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart'; // لفتح الروابط والهاتف
// ⭐️ استيراد FontAwesomeIcons لأيقونة واتساب
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';


class ConsumerStoreSearchScreen extends StatefulWidget {
  static const routeName = '/consumerStoreSearch';

  const ConsumerStoreSearchScreen({super.key});

  @override
  State<ConsumerStoreSearchScreen> createState() => _ConsumerStoreSearchScreenState();
}

class _ConsumerStoreSearchScreenState extends State<ConsumerStoreSearchScreen> {

  // 💡 استخدام LatLng من مكتبة latlong2
  LatLng? _currentSearchLocation;
  bool _isLoading = false;
  String _loadingMessage = 'اضغط على بحث لبدء البحث عن المتاجر';
  List<Map<String, dynamic>> _nearbySupermarkets = [];
  List<Marker> _mapMarkers = []; // قائمة المؤشرات الخاصة بـ flutter_map
  final MapController _mapController = MapController(); // للتحكم بالخريطة
  final double _searchRadiusKm = 5.0; // نطاق البحث كما في HTML

  // 💡 الموقع الافتراضي (الإسكندرية)
  final LatLng _defaultLocation = const LatLng(31.2001, 29.9187);

  // 💡 [إضافة]: كائن Distance لحساب المسافات
  final Distance distance = const Distance();


  // --- دوال المساعدة ---

  // 💡 الحصول على موقع المستخدم الفعلي
  Future<Position?> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'جاري تحديد موقعك الفعلي...';
    });
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          throw Exception('تم رفض الوصول إلى الموقع. يرجى منحه الإذن يدوياً.');
        }
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      return position;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: ${e.toString()}')));
      return null;
    } finally {
      // إزالة شاشة التحميل فقط بعد تحديد الخيار (تم نقلها إلى _searchAndDisplayStores)
    }
  }

  // 🚀 صندوق حوار لاختيار نوع الموقع
  Future<void> _promptLocationSelection() async {
    final buyerDataProvider = Provider.of<BuyerDataProvider>(context, listen: false);
    // 💡 نستخدم LatLng من latlong2 لبيانات المستخدم
    // تم حل خطأ userLat/userLng بإضافتهما في BuyerDataProvider سابقاً
    final LatLng? registeredLocation = (buyerDataProvider.userLat != null && buyerDataProvider.userLng != null)
      ? LatLng(buyerDataProvider.userLat!, buyerDataProvider.userLng!)
      : null;

    final isRegisteredLocationAvailable = registeredLocation != null;

    // إظهار Dialog
    final selectedOption = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حدد موقع البحث'),
        content: const Text('هل تريد البحث حول موقعك الحالي الفعلي، أم حول عنوانك المُسجّل؟'),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          // الخيار الأول: الموقع الفعلي
          TextButton.icon(
            icon: const Icon(Icons.my_location),
            label: const Text('الموقع الحالي'),
            onPressed: () => Navigator.of(context).pop('current'),
          ),
          // الخيار الثاني: الموقع المسجل
          if (isRegisteredLocationAvailable)
            TextButton.icon(
              icon: const Icon(Icons.home),
              label: const Text('العنوان المسجل'),
              onPressed: () => Navigator.of(context).pop('registered'),
            ),
          // خيار الإلغاء
          TextButton(
            child: const Text('إلغاء'),
            onPressed: () => Navigator.of(context).pop(null),
          ),
        ],
      ),
    );

    if (selectedOption == 'current') {
      final position = await _getCurrentLocation();
      if (position != null) {
        _currentSearchLocation = LatLng(position.latitude, position.longitude);
        _searchAndDisplayStores(_currentSearchLocation!);
      }
    } else if (selectedOption == 'registered' && isRegisteredLocationAvailable) {
      _currentSearchLocation = registeredLocation!;
      _searchAndDisplayStores(_currentSearchLocation!);
    } else {
      // لا يوجد اختيار أو فشل في الموقع الفعلي
      _mapController.move(_defaultLocation, 12);
      setState(() {
        _isLoading = false;
        _loadingMessage = 'اضغط على زر البحث لتحديد موقعك.';
      });
    }
  }

  // 🎯 وظيفة البحث عن المتاجر وعرضها (قلب المنطق)
  Future<void> _searchAndDisplayStores(LatLng location) async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'جاري البحث عن المتاجر في نطاق ${_searchRadiusKm} كم...';
      _nearbySupermarkets = [];
      _mapMarkers = [];
    });

    try {
      // 1. تحديث الخريطة والمؤشر
      _mapController.move(location, 14);

      // إضافة مؤشر الموقع الحالي
      _mapMarkers.add(Marker(
        point: location,
        width: 30,
        height: 30,
        builder: (context) => const Icon(
          Icons.circle,
          color: Colors.blue,
          size: 15,
        ),
      ));

      // 2. جلب المتاجر من Firestore
      // 💡 استخدام اسم الـ collection الثابت والمحفوظ: deliverySupermarkets
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('deliverySupermarkets')
          .where('completedDetails', isEqualTo: true)
          .get();

      final List<Map<String, dynamic>> allSupermarkets = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;

        // التعامل مع صيغ الموقع المختلفة
        LatLng storeLocation;
        if (data['location'] is GeoPoint) {
          storeLocation = LatLng(data['location'].latitude, data['location'].longitude);
        } else if (data['location'] is Map && data['location']['lat'] != null) {
           storeLocation = LatLng(data['location']['lat'] as double, data['location']['lng'] as double);
        } else {
           // تخطي المتاجر التي لا تحتوي على موقع صالح
           return null;
        }

        return {
          'id': doc.id,
          ...data,
          'location': storeLocation,
        };
      }).where((data) => data != null).cast<Map<String, dynamic>>().toList();


      List<Map<String, dynamic>> foundStores = [];
      List<String> nearbyStoreIds = [];

      // 3. حساب المسافة والتصفية
      for (var store in allSupermarkets) {
        final storeLocation = store['location'] as LatLng;

        // ✅ التصحيح: استخدام دالة distance() من كائن Distance بدلاً من distanceTo
        final distanceInMeters = distance(location, storeLocation);
        final distanceInKm = distanceInMeters / 1000;

        if (distanceInKm <= _searchRadiusKm) {
          store['distance'] = distanceInKm.toStringAsFixed(2);
          foundStores.add(store);
          nearbyStoreIds.add(store['id']);

          // إضافة مؤشر المتجر
          _mapMarkers.add(Marker(
            point: storeLocation,
            width: 40,
            height: 40,
            builder: (context) => GestureDetector(
              onTap: () {
                _showStoreDetailsBottomSheet(store);
                _mapController.move(storeLocation, 16);
              },
              child: const Icon(
                Icons.store,
                color: Colors.green,
                size: 35,
              ),
            ),
          ));
        }
      }

      // 4. الفرز وتحديث الحالة
      foundStores.sort((a, b) =>
        (a['distance'] is String ? double.tryParse(a['distance']) : a['distance'])!.compareTo(
        (b['distance'] is String ? double.tryParse(b['distance']) : b['distance'])!
      ));

      setState(() {
        _nearbySupermarkets = foundStores;
        _isLoading = false;
        _loadingMessage = foundStores.isEmpty
            ? 'لا توجد متاجر في نطاق ${_searchRadiusKm} كم.'
            : 'تم العثور على ${foundStores.length} متجراً قريباً.';
      });

      // 5. استدعاء جلب البانرات (يجب تطبيق هذه الدالة لاحقاً)
      // loadConsumerBanners(nearbyStoreIds);

    } catch (e) {
      setState(() {
        _isLoading = false;
        _loadingMessage = 'حدث خطأ أثناء جلب البيانات. يرجى المحاولة مرة أخرى.';
      });
      // رسالة خطأ للمستخدم
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في البحث: ${e.toString()}')));
    }
  }

  // 💡 دالة عرض تفاصيل المتجر في Bottom Sheet
  void _showStoreDetailsBottomSheet(Map<String, dynamic> store) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StoreDetailsBottomSheet(store: store);
      },
    );
  }

  @override
  void initState() {
    super.initState();
    // ابدأ باختيار الموقع
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _promptLocationSelection();
    });
  }


  @override
  Widget build(BuildContext context) {

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('اكتشف المتاجر القريبة'),
          centerTitle: true,
          backgroundColor: Theme.of(context).primaryColor,
        ),

        body: Column(
          children: [
            // 1. قسم الخريطة (45% من ارتفاع الشاشة)
            Container(
              height: MediaQuery.of(context).size.height * 0.45,
              decoration: BoxDecoration(
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
              ),
              child: Stack(
                children: [
                  // 1.1 الخريطة (Flutter Map)
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      // ✅ التصحيح: تغيير initialCenter إلى center
                      center: _currentSearchLocation ?? _defaultLocation,
                      // ✅ التصحيح: تغيير initialZoom إلى zoom
                      zoom: 12.0,
                      maxZoom: 18.0,
                      onMapReady: () {
                         // التأكد من أن الخريطة جاهزة قبل أي حركة
                      },
                    ),
                    children: [
                      // Tile Layer (يمكنك استخدام Mapbox tiles إذا كان لديك API Key، أو OpenStreetMap كافتراضي)
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.my_test_app',
                      ),

                      // طبقة المؤشرات
                      MarkerLayer(
                        markers: _mapMarkers,
                      ),
                    ],
                  ),

                  // 1.2 زر البحث العائم
                  Positioned(
                    top: 15,
                    left: 20,
                    right: 20,
                    child: Center(
                      child: SizedBox(
                        width: 350,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _promptLocationSelection,
                          icon: const Icon(Icons.search, color: Colors.white),
                          label: Text(_isLoading ? 'جاري البحث...' : 'ابحث عن متاجر قريبة', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 1.3 زر الموقع الفعلي (FAB)
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: FloatingActionButton(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      onPressed: _isLoading ? null : () async {
                        final location = await _getCurrentLocation();
                        if (location != null) {
                           _currentSearchLocation = LatLng(location.latitude, location.longitude);
                           _mapController.move(_currentSearchLocation!, 14);
                           _searchAndDisplayStores(_currentSearchLocation!);
                        }
                      },
                      child: const Icon(Icons.location_searching, color: Colors.white),
                    ),
                  ),

                  // 1.4 شاشة التحميل
                  if (_isLoading)
                    Positioned.fill(
                      child: Container(
                        color: Colors.white.withOpacity(0.85),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 10),
                              Text(_loadingMessage),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
              ),
            ),

            // 2. قسم القائمة السفلية
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2.1 عنوان قائمة المتاجر
                    Padding(
                      padding: const EdgeInsets.only(right: 5, bottom: 10, top: 10),
                      child: Text(
                        'المتاجر المتاحة',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),

                    // 2.2 قائمة المتاجر
                    if (_nearbySupermarkets.isEmpty && !_isLoading)
                      Center(
                        child: Text(
                          _loadingMessage,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    else if (!_isLoading) // لا تعرض القائمة أثناء التحميل إلا إذا كانت فارغة
                      ListView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: _nearbySupermarkets.length,
                        itemBuilder: (context, index) {
                          final store = _nearbySupermarkets[index];
                          return StoreCard(
                            store: store,
                            onTap: () {
                              _showStoreDetailsBottomSheet(store);
                              final LatLng storeLoc = store['location'] as LatLng;
                              _mapController.move(storeLoc, 16);
                            },
                          );
                        },
                      ),

                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 💡 ودجت بطاقة المتجر (Store Card Widget) - كما هو
class StoreCard extends StatelessWidget {
  final Map<String, dynamic> store;
  final VoidCallback onTap;

  const StoreCard({super.key, required this.store, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Row(
            children: [
              // الأيقونة
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).primaryColorDark, width: 1),
                ),
                child: const Icon(Icons.store, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 15),
              // المعلومات
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store['supermarketName'] ?? 'سوبر ماركت غير معروف',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColorDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      store['address'] ?? 'العنوان غير متاح',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 15),
              // المسافة
              Text(
                '${store['distance']} كم',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 💡 ودجت تفاصيل المتجر في Bottom Sheet - تم تعديل استخدام url_launcher
class StoreDetailsBottomSheet extends StatelessWidget {
  final Map<String, dynamic> store;

  const StoreDetailsBottomSheet({super.key, required this.store});

  // دالة مساعدة لفتح الروابط
  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    // 💡 هنا يتم تحويل تصميم الـ Modal في HTML إلى شيت فلاتر
    final String whatsapp = store['whatsappNumber'] ?? 'غير متاح';
    final String phone = store['deliveryPhone'] ?? 'غير متاح';
    final String distance = store['distance'] ?? 'غير محددة';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 10,
      ),
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface, // استخدام لون الثيم
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle (مقبض السحب)
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 15),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  store['supermarketName'] ?? 'اسم المتجر',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColorDark),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // Details List
            _buildDetailItem(context, Icons.location_on, store['address'] ?? 'العنوان غير متاح'),
            _buildDetailItem(context, Icons.near_me, '$distance كم من موقعك'),
            _buildDetailLinkItem(
              context,
              // ✅ التصحيح: استخدام FontAwesomeIcons.whatsapp
              FontAwesomeIcons.whatsapp,
              whatsapp,
              // رابط الواتساب: whatsapp://send?phone=[number] أو https://wa.me/[number]
              whatsapp != 'غير متاح' ? 'https://wa.me/${whatsapp.replaceAll(RegExp(r'\s+'), '').replaceAll(RegExp(r'^\+'), '')}' : null,
            ),
            _buildDetailLinkItem(
              context,
              Icons.phone,
              phone,
              // رابط الهاتف
              phone != 'غير متاح' ? 'tel:${phone.replaceAll(RegExp(r'\s+'), '')}' : null,
            ),

            const SizedBox(height: 30),

            // CTA Button
            ElevatedButton.icon(
              icon: const Icon(Icons.shopping_basket, color: Colors.white),
              label: const Text('تصفح عروض المتجر', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              onPressed: () {
                // 💡 التوجيه إلى شاشة العروض
                Navigator.of(context).pop(); // إغلاق الشيت
                // 🛑 هنا يجب تطبيق منطق التخزين والتوجيه (marketOffer.html)
                // يمكن استخدام Shared Preferences لتخزين ID المتجر
                // Navigator.of(context).pushNamed('/marketOffer', arguments: store['id']);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم اختيار متجر ${store['supermarketName']}. سيتم التوجيه لصفحة العروض.')));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // دالة مساعدة لبناء عنصر تفصيلي
  Widget _buildDetailItem(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 20),
          const SizedBox(width: 15),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color)),
          ),
        ],
      ),
    );
  }

  // دالة مساعدة لبناء عنصر تفصيلي يمكن النقر عليه (Link)
  Widget _buildDetailLinkItem(BuildContext context, IconData icon, String text, String? url) {
    final isAvailable = url != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 20),
          const SizedBox(width: 15),
          isAvailable
              ? InkWell(
                  onTap: () => _launchURL(url!),
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).primaryColorDark,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                )
              : Text(
                  text,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
        ],
      ),
    );
  }
}
