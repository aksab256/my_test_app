// المسار: lib/controllers/checkout_controller.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart'; // المكتبة الجديدة
import 'package:provider/provider.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';
import 'package:facebook_app_events/facebook_app_events.dart';

// تعريف الألوان
const Color kPrimaryColor = Color(0xFF4CAF50);
const Color kErrorColor = Color(0xFFE74C3C);
const Color kDebugColor = Color(0xFFF39C12);

// ===================================================================
// دالة مساعدة لتنظيف الكائن (إزالة الحقول التي تحمل null) لضمان سلامة البيانات
// ===================================================================
Map<String, dynamic> removeNullValues(Map<String, dynamic> obj) {
  final Map<String, dynamic> cleanObj = {};
  obj.forEach((key, value) {
    if (value != null) {
      if (value is Map) {
        final cleanedMap = removeNullValues(Map<String, dynamic>.from(value));
        if (cleanedMap.isNotEmpty) {
          cleanObj[key] = cleanedMap;
        }
      } else if (value is List) {
        final cleanedList = value.map((e) => e is Map ? removeNullValues(Map<String, dynamic>.from(e)) : e).toList();
        cleanObj[key] = cleanedList;
      } else {
        cleanObj[key] = value;
      }
    }
  });
  return cleanObj;
}

class CheckoutController {
    static final facebookAppEvents = FacebookAppEvents();

    static Future<String?> _getSellerPhone(String id, bool isConsumer) async {
        try {
            final collectionName = isConsumer ? "deliverySupermarkets" : "sellers";
            final doc = await FirebaseFirestore.instance.collection(collectionName).doc(id).get();
            if (doc.exists) {
                return doc.data()?['phone']?.toString() ?? doc.data()?['mobile']?.toString();
            }
        } catch (e) {
            debugPrint('❌ Error fetching seller phone: $e');
        }
        return null;
    }

    static Future<double> fetchCashback(String userId, String userRole) async {
        if (userId.isEmpty) return 0.0;
        final bool isConsumer = (userRole == 'consumer');
        final String usersCollectionName = isConsumer ? "consumers" : "users";
        final String cashbackFieldName = isConsumer ? "cashbackBalance" : "cashback";

        try {
            final userDoc = await FirebaseFirestore.instance.collection(usersCollectionName).doc(userId).get();
            if (userDoc.exists) {
                return (userDoc.data()?[cashbackFieldName] as num?)?.toDouble() ?? 0.0;
            }
        } catch (e) {
            debugPrint('❌ Error fetching cashback: $e');
        }
        return 0.0;
    }

    static Future<bool> placeOrder({
        required BuildContext context,
        required List<Map<String, dynamic>> checkoutOrders,
        required Map<String, dynamic> loggedUser,
        required double originalOrderTotal,
        required double currentCashback,
        required double finalTotalAmount,
        required bool useCashback,
        required dynamic selectedPaymentMethod,
        }) async {

        final buyerProvider = Provider.of<BuyerDataProvider>(context, listen: false);

        if (checkoutOrders.isEmpty || loggedUser['id'] == null) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('خطأ: قائمة الطلبات فارغة أو بيانات المستخدم ناقصة.'), backgroundColor: kErrorColor)
            );
            return false;
        }

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        final String paymentMethodString = selectedPaymentMethod.toString();
        final Map<String, dynamic> safeLoggedUser = Map<String, dynamic>.from(loggedUser);

        final String? address = buyerProvider.effectiveAddress;
        final String? repCode = (safeLoggedUser['repCode']?.toString() == 'null') ? null : safeLoggedUser['repCode']?.toString();
        final String? repName = (safeLoggedUser['repName']?.toString() == 'null') ? null : safeLoggedUser['repName']?.toString();
        final String? customerPhone = (safeLoggedUser['phone']?.toString() == 'null') ? null : safeLoggedUser['phone']?.toString();
        final String? customerEmail = (safeLoggedUser['email']?.toString() == 'null') ? null : safeLoggedUser['email']?.toString();
        final String? customerFullname = (safeLoggedUser['fullname']?.toString() == 'null') ? null : safeLoggedUser['fullname']?.toString();

        if (address == null) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إكمال بيانات العنوان.'), backgroundColor: kErrorColor));
            return false;
        }

        final bool isConsumer = (safeLoggedUser['role'] == 'consumer');
        final String ordersCollectionName = isConsumer ? "consumerorders" : "orders";
        final String usersCollectionName = isConsumer ? "consumers" : "users";
        final String cashbackFieldName = isConsumer ? "cashbackBalance" : "cashback";

        final List<Map<String, dynamic>> processedCheckoutOrders = [];
        for (var order in checkoutOrders) {
            Map<String, dynamic> processedOrder = Map<String, dynamic>.from(order);
            final List<dynamic> rawItems = processedOrder['items'] as List? ?? [];

            final List<Map<String, dynamic>> processedItems = [];
            for (var item in rawItems) {
                Map<String, dynamic> processedItem = Map<String, dynamic>.from(item);
                final double price = (processedItem['price'] as num?)?.toDouble() ?? 0.0;
                final bool isDeliveryFee = (processedItem['productId'] == 'DELIVERY_FEE' || (processedItem['isDeliveryFee'] ?? false));

                if (price <= 0.0 && !isDeliveryFee) processedItem['isGift'] = true;
                if (!isConsumer && isDeliveryFee) continue;

                processedItems.add({
                    ...processedItem,
                    'mainId': processedItem['mainId'],
                    'subId': processedItem['subId'], 
                    'mainCategoryId': processedItem['mainId'],
                    'subCategoryId': processedItem['subId'],
                });
            }
            processedOrder['items'] = processedItems;
            processedCheckoutOrders.add(processedOrder);
        }

        final Map<String, Map<String, dynamic>> groupedItems = {
            for (var order in processedCheckoutOrders) order['sellerId'] as String: order
        };

        double actualOrderTotal = 0.0;
        for(var order in processedCheckoutOrders) {
            for(var item in (order['items'] as List)) {
                if (!(item['isGift'] ?? false) && !(item['isDeliveryFee'] ?? false)) {
                     actualOrderTotal += ((item['price'] as num).toDouble() * (item['quantity'] as num).toDouble());
                }
            }
        }

        final double discountUsed = useCashback ? min(actualOrderTotal, currentCashback) : 0.0;
        final bool isGiftEligible = processedCheckoutOrders.any((order) => (order['items'] as List).any((item) => item['isGift'] == true));
        
        // 🚀 تحديد ما إذا كان الطلب يتطلب معالجة عهدة أمان (نقاط عهدة)
        final bool needsSecureProcessing = !isConsumer && (discountUsed > 0 || isGiftEligible);

        try {
            List<String> successfulOrderIds = [];
            final Map<String, double> commissionRatesCache = {};
            final Map<String, String?> sellerPhonesCache = {};

            for (final sellerId in groupedItems.keys) {
                if (!isConsumer) {
                    final sellerSnap = await FirebaseFirestore.instance.collection("sellers").doc(sellerId).get();
                    commissionRatesCache[sellerId] = (sellerSnap.data()?['commissionRate'] as num?)?.toDouble() ?? 0.0;
                }
                sellerPhonesCache[sellerId] = await _getSellerPhone(sellerId, isConsumer);
            }

            if (needsSecureProcessing) {
                // 🚀 تعديل الإقليم واسم الدالة فقط مع الحفاظ على الكود الأصلي بالملي
                final HttpsCallable callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
                    .httpsCallable('createOrdersWithPromos'); 

                final List<Map<String, dynamic>> allOrdersData = [];
                for (final sellerId in groupedItems.keys) {
                    final sellerOrder = groupedItems[sellerId]!;
                    final List<Map<String, dynamic>> safeItems = List<Map<String, dynamic>>.from(sellerOrder['items']);
                    final double subtotalPrice = safeItems.fold(0.0, (sum, item) => (item['isGift'] ?? false) ? sum : sum + ((item['price'] as num).toDouble() * (item['quantity'] as num).toDouble()));

                    double discountPortion = actualOrderTotal > 0 ? (subtotalPrice / actualOrderTotal) * discountUsed : 0.0;

                    allOrdersData.add(removeNullValues({
                        'sellerId': sellerId,
                        'sellerPhone': sellerPhonesCache[sellerId],
                        'items': safeItems,
                        'total': subtotalPrice,
                        'paymentMethod': paymentMethodString,
                        'status': 'new-order',
                        'orderDate': DateTime.now().toUtc().toIso8601String(),
                        'commissionRateSnapshot': commissionRatesCache[sellerId] ?? 0.0,
                        'insurance_points': discountPortion, // مسمى لوجستي: نقاط تأمين
                        'isCashbackUsed': discountUsed > 0,
                        'isFinancialSettled': false,
                        'isCommissionProcessed': false,
                        'deliveryHandled': false,
                        'buyer': {
                            'id': safeLoggedUser['id'], 
                            'name': customerFullname, 
                            'phone': customerPhone,
                            'email': customerEmail, 
                            'address': address,
                            'lat': buyerProvider.effectiveLat,
                            'lng': buyerProvider.effectiveLng,
                            'repCode': repCode, // الحفاظ على حقول المندوب للشفافية
                            'repName': repName
                        },
                    }));
                }

                // تنفيذ الطلب عبر Cloud Function
                final result = await callable.call(removeNullValues({
                    'userId': safeLoggedUser['id'],
                    'cashbackToReserve': discountUsed, // تأمين إجمالي العهدة
                    'ordersData': allOrdersData,
                    'action': 'lock_assets', // تأكيد حجز العهدة
                    'checkoutId': 'CH-${safeLoggedUser['id']}-${DateTime.now().millisecondsSinceEpoch}',
                }));

                if (result.data['orderIds'] is List) {
                    successfulOrderIds.addAll(List<String>.from(result.data['orderIds']));
                }
            } else {
                // الكود العادي لطلبات الكاش أو المستهلك (Firebase Direct)
                for (final sellerId in groupedItems.keys) {
                    final sellerOrder = groupedItems[sellerId]!;
                    final List<Map<String, dynamic>> allPaidItems = List<Map<String, dynamic>>.from(sellerOrder['items']);
                    double subtotalPrice = allPaidItems.fold(0.0, (sum, item) => (item['isGift'] ?? false) ? sum : sum + ((item['price'] as num).toDouble() * (item['quantity'] as num).toDouble()));
                    double discountPortion = actualOrderTotal > 0 ? (subtotalPrice / actualOrderTotal) * discountUsed : 0.0;

                    Map<String, dynamic> orderData = isConsumer ? {
                        'customerId': safeLoggedUser['id'], 'customerName': customerFullname,
                        'customerPhone': customerPhone, 'customerAddress': address,
                        'deliveryLocation': {
                          'lat': buyerProvider.effectiveLat,
                          'lng': buyerProvider.effectiveLng,
                          'isGpsLocation': buyerProvider.isUsingSessionLocation,
                        },
                        'supermarketId': sellerId, 
                        'supermarketName': sellerOrder['sellerName'],
                        'supermarketPhone': sellerPhonesCache[sellerId],
                        'items': allPaidItems,
                        'subtotalPrice': subtotalPrice,
                        'finalAmount': subtotalPrice - discountPortion,
                        'paymentMethod': paymentMethodString, 'status': 'new-order',
                        'orderDate': FieldValue.serverTimestamp(),
                    } : {
                        'buyer': {
                          'id': safeLoggedUser['id'], 'name': customerFullname, 'phone': customerPhone, 'address': address,
                          'lat': buyerProvider.effectiveLat, 'lng': buyerProvider.effectiveLng, 'repCode': repCode,
                          'repName': repName,
                        },
                        'sellerId': sellerId, 
                        'sellerPhone': sellerPhonesCache[sellerId],
                        'items': allPaidItems,
                        'total': subtotalPrice,
                        'paymentMethod': paymentMethodString,
                        'status': 'new-order', 'orderDate': FieldValue.serverTimestamp(),
                        'commissionRate': commissionRatesCache[sellerId] ?? 0.0,
                        'insurance_points': discountPortion, // استخدام نقاط التأمين
                        'isCashbackUsed': discountUsed > 0,
                        'isFinancialSettled': false,
                        'isCommissionProcessed': false,
                        'deliveryHandled': false,
                    };

                    final docRef = await FirebaseFirestore.instance.collection(ordersCollectionName).add(removeNullValues(orderData));
                    successfulOrderIds.add(docRef.id);
                    await docRef.update({'orderId': docRef.id});
                }

                if (discountUsed > 0 && successfulOrderIds.isNotEmpty) {
                    await FirebaseFirestore.instance.collection(usersCollectionName).doc(safeLoggedUser['id']).update({
                        cashbackFieldName: currentCashback - discountUsed
                    });
                }
            }

            if (successfulOrderIds.isNotEmpty) {
                // إرسال تنبيهات فيسبوك للتتبع
                try {
                    facebookAppEvents.logPurchase(
                        amount: finalTotalAmount,
                        currency: "EGP",
                        parameters: {
                            'order_ids': successfulOrderIds.join(','),
                            'is_consumer': isConsumer.toString(),
                        },
                    );
                } catch (fbError) {
                    debugPrint('Facebook Event Error: $fbError');
                }

                buyerProvider.clearSessionLocation();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم تأكيد العهدة وإرسال الطلب!'), backgroundColor: kPrimaryColor));
                return true;
            }
            return false;

        } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ فشل في تأمين العهدة: $e'), backgroundColor: kErrorColor));
            return false;
        }
    }
}