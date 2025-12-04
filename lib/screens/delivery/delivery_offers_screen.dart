// lib/screens/delivery/delivery_offers_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // لتنسيق التاريخ
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:ui'; // 💡 تم الإبقاء عليه لحل خطأ Member not found/TextDirection
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// 💡 يجب استيراد الـ Provider الخاص بإدارة العروض
import 'package:my_test_app/providers/product_offer_provider.dart';
// 💡 استيراد الموديلات اللازمة
import 'package:my_test_app/models/logged_user.dart';
import 'package:my_test_app/models/product_offer.dart';

// 🚀 استيرادات التوجيه (Routes)
import 'package:my_test_app/screens/buyer/buyer_home_screen.dart';
import 'package:my_test_app/screens/delivery_merchant_dashboard_screen.dart';

// ----------------------------------------------------------------------------------
// 1. تعريف الشاشة
// ----------------------------------------------------------------------------------

class DeliveryOffersScreen extends StatefulWidget {
  static const routeName = '/delivery-offers';

  const DeliveryOffersScreen({super.key});

  @override
  State<DeliveryOffersScreen> createState() => _DeliveryOffersScreenState();
}

class _DeliveryOffersScreenState extends State<DeliveryOffersScreen> {
  // حالة لعرض رسائل النظام (مثل الـ message-box في الـ HTML)
  String? _statusMessage;
  MessageType _messageType = MessageType.info;
  String _searchTerm = '';
  String _currentUserId = '';
  String _welcomeMessage = 'جاري تحميل البيانات...';

  // ----------------------------------------------------------------
  // 1.1 تهيئة وحالة المستخدم
  // ----------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _loadUserInfoAndFetchOffers();
  }

  // محاكاة دالة التحقق من المستخدم وجلب اسم السوبر ماركت
  Future<void> _loadUserInfoAndFetchOffers() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedUserString = prefs.getString('loggedUser');
    // Note: Provider access outside build method requires listen: false
    final provider = Provider.of<ProductOfferProvider>(context, listen: false);

    if (loggedUserString != null) {
      try {
        final loggedUser = LoggedInUser.fromJson(jsonDecode(loggedUserString));
        if (loggedUser.id != null && loggedUser.fullname != null) {
          _currentUserId = loggedUser.id!;

          // ⚠️ ملحوظة: سيتم استخدام الـ Provider لجلب اسم السوبر ماركت وتفاصيل المنتج كما هو الحال في الـ JS
          await provider.initializeData(_currentUserId);

          setState(() {
            _welcomeMessage = 'أهلاً بك، ${loggedUser.fullname}${provider.supermarketName != null ? ' من ${provider.supermarketName}' : ''}!';
            _setStatusMessage('جاري تحميل العروض...', MessageType.info);
          });

          // بدء جلب العروض من الـ Provider
          await provider.fetchOffers(_currentUserId);

          if (provider.offers.isNotEmpty) {
            _setStatusMessage('تم تحميل ${provider.offers.length} عرض بنجاح.', MessageType.success);
          } else {
            _setStatusMessage('لا توجد عروض حاليًا لهذا التاجر.', MessageType.info);
          }
        } else {
          _handleLoginRedirect('بيانات المستخدم في الذاكرة المحلية غير مكتملة.');
        }
      } catch (e) {
        _handleLoginRedirect('خطأ في تحليل بيانات المستخدم من الذاكرة المحلية: $e');
      }
    } else {
      _handleLoginRedirect('لا توجد بيانات مستخدم مسجل دخول.');
    }
  }

  void _handleLoginRedirect(String message) {
    _setStatusMessage('❌ $message جاري التوجيه لصفحة تسجيل الدخول.', MessageType.error);
    // ⚠️ يتم التوجيه إلى شاشة تسجيل الدخول الافتراضية هنا
    Future.delayed(const Duration(seconds: 2), () {
      //Navigator.of(context).pushNamedAndRemoveUntil(LoginScreen.routeName, (route) => false);
    });
  }

  void _setStatusMessage(String message, MessageType type) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      _messageType = type;
    });
    if (type != MessageType.info) {
      Future.delayed(const Duration(seconds: 5), () {
        if (!mounted || _statusMessage == null) return;
        setState(() {
          _statusMessage = null; // إخفاء الرسالة بعد 5 ثوانٍ
        });
      });
    }
  }

  // ----------------------------------------------------------------
  // 1.2 التعامل مع منطق التصفية والبحث
  // ----------------------------------------------------------------

  List<ProductOffer> _getFilteredOffers(List<ProductOffer> allOffers) {
    if (_searchTerm.isEmpty) {
      return allOffers;
    }
    final lowerCaseSearchTerm = _searchTerm.toLowerCase().trim();
    return allOffers.where((offer) {
      final productName = offer.productDetails.name.toLowerCase();
      final unitsMatch = offer.units.any((unit) =>
          unit.unitName.toLowerCase().contains(lowerCaseSearchTerm)
      );
      return productName.contains(lowerCaseSearchTerm) || unitsMatch;
    }).toList();
  }

  // ----------------------------------------------------------------
  // 1.3 التعامل مع الإجراءات (حذف/تعديل)
  // ----------------------------------------------------------------

  Future<void> _deleteOffer(String offerId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد أنك تريد حذف هذا العرض؟'),
        actions: <Widget>[
          TextButton(
            child: const Text('إلغاء'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            child: const Text('حذف'),
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    ) ?? false;

    if (confirmed) {
      _setStatusMessage('جاري حذف العرض...', MessageType.info);
      try {
        await Provider.of<ProductOfferProvider>(context, listen: false).deleteOffer(offerId);
        _setStatusMessage('✅ تم حذف العرض بنجاح!', MessageType.success);
      } catch (error) {
        _setStatusMessage('❌ حدث خطأ أثناء حذف العرض: $error', MessageType.error);
      }
    }
  }

  Future<void> _showEditPriceModal(ProductOffer offer, int unitIndex) async {
    // محاكاة لـ Modal/AlertDialog
    final unit = offer.units[unitIndex];
    final TextEditingController priceController = TextEditingController(text: unit.price.toStringAsFixed(2));

    final newPrice = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل سعر الوحدة'),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              TextField(
                decoration: const InputDecoration(labelText: 'المنتج'),
                controller: TextEditingController(text: offer.productDetails.name),
                readOnly: true,
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(labelText: 'الوحدة'),
                controller: TextEditingController(text: unit.unitName),
                readOnly: true,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceController,
                decoration: InputDecoration(
                  labelText: 'السعر الجديد (بالجنيه المصري)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(FontAwesomeIcons.moneyBill),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('إلغاء'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton.icon(
            icon: const Icon(FontAwesomeIcons.save),
            label: const Text('حفظ التغييرات'),
            onPressed: () {
              final price = double.tryParse(priceController.text);
              if (price != null && price >= 0) {
                Navigator.of(ctx).pop(price);
              } else {
                // يمكن إضافة رسالة خطأ هنا
              }
            },
          ),
        ],
      ),
    );

    if (newPrice != null) {
      _setStatusMessage('جاري تحديث السعر...', MessageType.info);
      try {
        await Provider.of<ProductOfferProvider>(context, listen: false).updateUnitPrice(
          offerId: offer.id,
          unitIndex: unitIndex,
          newPrice: newPrice,
        );
        _setStatusMessage('✅ تم تحديث السعر بنجاح!', MessageType.success);
      } catch (error) {
        _setStatusMessage('❌ حدث خطأ أثناء تحديث السعر: $error', MessageType.error);
      }
    }
  }

  // ----------------------------------------------------------------
  // 2. تصميم الواجهة (Widget Build)
  // ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // ⚠️ يتم استخدام Consumer للاستماع إلى تغييرات حالة العروض
    return Consumer<ProductOfferProvider>(
      builder: (context, provider, child) {
        final filteredOffers = _getFilteredOffers(provider.offers);
        final isLoading = provider.isLoading && provider.offers.isEmpty;

        // 🚀 تصميم الـ DataTable يتطلب SingleChildScrollView
        final offersTable = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            // محاكاة لـ .offers-table thead th
            headingRowColor: MaterialStateProperty.all(Theme.of(context).cardColor),
            dataRowMaxHeight: 90, // لتحديد ارتفاع الصفوف
            columnSpacing: 10,
            horizontalMargin: 10,
            columns: const [
              DataColumn(label: Text('صورة المنتج', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('اسم المنتج', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('السوبر ماركت', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('تاريخ الإضافة', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('الوحدات والسعر', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('الإجراءات', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: filteredOffers.map((offer) {
              final product = offer.productDetails;

              // 💡 بناء خلايا الـ DataTable
              return DataRow(cells: [
                // 1. صورة المنتج
                DataCell(
                  product.imageUrls.isNotEmpty
                      ? Image.network(product.imageUrls[0], width: 60, height: 60, fit: BoxFit.cover)
                      : Container(width: 60, height: 60, color: Colors.grey.shade300, child: const Icon(Icons.image_not_supported, size: 30)),
                ),
                // 2. اسم المنتج
                DataCell(Text(product.name, softWrap: true)),
                // 3. السوبر ماركت
                DataCell(Text(offer.supermarketName ?? 'غير معروف')),
                // 4. تاريخ الإضافة
                DataCell(Text(offer.createdAt != null
                    ? DateFormat('yyyy/MM/dd', 'ar').format(offer.createdAt) // تم التصحيح: إزالة .toDate()
                    : 'غير متوفر')),
                // 5. الوحدات والسعر (الـ offer-units-cell)
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: offer.units.map((unit) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(child: Text(unit.unitName, style: const TextStyle(fontWeight: FontWeight.w500))),
                          Text('${unit.price.toStringAsFixed(2)} ج.م', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
                // 6. الإجراءات (الـ actions-cell)
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // أزرار التعديل لكل وحدة
                      ...offer.units.asMap().entries.map((entry) {
                        final index = entry.key;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade400, // محاكاة لـ edit-btn-bg
                              foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                            onPressed: () => _showEditPriceModal(offer, index),
                            icon: const Icon(FontAwesomeIcons.edit, size: 14),
                            label: Text('تعديل ${offer.units[index].unitName.substring(0, 5)}...', style: const TextStyle(fontSize: 12)),
                          ),
                        );
                      }).toList(),
                      // زر الحذف
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600, // محاكاة لـ delete-btn-bg
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        onPressed: () => _deleteOffer(offer.id),
                        icon: const Icon(FontAwesomeIcons.trashAlt, size: 14),
                        label: const Text('حذف', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ]);
            }).toList(),
          ),
        );

        // 💡 هيكل الشاشة الرئيسي
        // ❌ تم حذف Directionality هنا للـ الاعتماد على اتجاه النص في MaterialApp
        return Scaffold(
            appBar: AppBar(
              title: const Text('إدارة عروض المنتجات'),
              backgroundColor: Theme.of(context).primaryColor,
            ),

            // 💡 محاكاة الشريط السفلي (bottom-bar)
            bottomNavigationBar: _buildBottomBar(context),

            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. العنوان ورسالة الترحيب (header)
                    _buildHeader(),

                    // 2. رسائل النظام (message-box)
                    if (_statusMessage != null)
                      _buildMessageBox(context),
                    const SizedBox(height: 20),

                    // 3. شريط البحث (filter-section)
                    _buildSearchFilter(context, provider.offers.isEmpty),

                    const SizedBox(height: 20),

                    // 4. عرض الجدول أو رسالة عدم وجود عروض
                    if (isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (filteredOffers.isNotEmpty)
                      // محاكاة لـ offers-table-container
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(color: Theme.of(context).shadowColor.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2)),
                          ],
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        clipBehavior: Clip.antiAlias, // لضمان الحدود المستديرة للجدول
                        child: offersTable,
                      )
                    else
                      _buildNoOffersMessage(context),
                  ],
                ),
              ),
            ),
          );
      },
    );
  }

  // ----------------------------------------------------------------
  // 3. مكونات الواجهة المساعدة
  // ----------------------------------------------------------------

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FontAwesomeIcons.tags, color: Theme.of(context).primaryColor, size: 32),
            const SizedBox(width: 10),
            Text('إدارة عروض المنتجات', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
          ],
        ),
        const SizedBox(height: 10),
        Text(_welcomeMessage, style: TextStyle(fontSize: 18, color: Theme.of(context).textTheme.bodyLarge?.color)),
      ],
    );
  }

  Widget _buildMessageBox(BuildContext context) {
    Color bgColor;
    Color borderColor;
    IconData icon;

    switch (_messageType) {
      case MessageType.success:
        bgColor = Colors.green.shade100;
        borderColor = Colors.green.shade500;
        icon = FontAwesomeIcons.checkCircle;
        break;
      case MessageType.error:
        bgColor = Colors.red.shade100;
        borderColor = Colors.red.shade500;
        icon = FontAwesomeIcons.timesCircle;
        break;
      case MessageType.info:
      default:
        bgColor = Colors.blue.shade100;
        borderColor = Colors.blue.shade500;
        icon = FontAwesomeIcons.infoCircle;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(15),
      margin: const EdgeInsets.only(top: 15),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: borderColor, size: 20),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              _statusMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, color: borderColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchFilter(BuildContext context, bool isDisabled) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(color: Theme.of(context).shadowColor.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('البحث عن عرض (باسم المنتج أو الوحدة):', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          TextField(
            decoration: InputDecoration(
              hintText: 'اكتب للبحث عن العروض...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon: const Icon(FontAwesomeIcons.search),
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
              enabled: !isDisabled, // محاكاة disabled
            ),
            onChanged: (value) {
              // 💡 يتم استخدام الـ debounce لتقليل عدد مرات التحديث
              // (في Flutter، يمكن استخدام Timer أو Rxdart للـ debounce)
              setState(() {
                _searchTerm = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNoOffersMessage(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        'لا توجد عروض حاليًا لهذا التاجر.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 20, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor, // محاكاة لـ sidebar-bg
        boxShadow: [
          BoxShadow(color: Theme.of(context).shadowColor.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                // ⚠️ التوجيه إلى المتجر (BuyerHomeScreen)
                Navigator.of(context).pushNamed(BuyerHomeScreen.routeName);
              },
              icon: const Icon(FontAwesomeIcons.shoppingBasket),
              label: const Text('العودة للمتجر'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700, // محاكاة لـ return-btn-bg
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                // ⚠️ التوجيه إلى لوحة التحكم (DeliveryMerchantDashboardScreen)
                Navigator.of(context).pushNamed(DeliveryMerchantDashboardScreen.routeName);
              },
              icon: const Icon(FontAwesomeIcons.cogs),
              label: const Text('لوحة التحكم'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade600, // محاكاة لـ delivery-settings-btn
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------------
// 4. الـ Enum المساعد (مثل الـ message-box classes)
// ----------------------------------------------------------------------------------

enum MessageType { success, error, info }
