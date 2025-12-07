// المسار: lib/controllers/checkout_controller.dart

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
// 🔥🔥 الإضافة الضرورية للاتصال الحقيقي بـ FireStore
import 'package:cloud_firestore/cloud_firestore.dart';

// تعريف الألوان (لـ SnackBar)
const Color kPrimaryColor = Color(0xFF4CAF50);
const Color kErrorColor = Color(0xFFE74C3C);

// 🎯🎯 رابط المسار الآمن (مطابق تمامًا لكود JS) 🎯🎯
const String CASHBACK_API_ENDPOINT = 'https://l9inzh2wck.execute-api.us-east-1.amazonaws.com/div/cashback';

// ===================================================================
// دالة مساعدة لتنظيف الكائن (لحذف الحقول ذات القيمة null/undefined - مطابقة لـ removeUndefined في JS)
// ===================================================================
Map<String, dynamic> removeNullValues(Map<String, dynamic> obj) {
  final Map<String, dynamic> cleanObj = {};
  obj.forEach((key, value) {
    if (value != null) {
      if (value is Map<String, dynamic>) {
        final cleanedMap = removeNullValues(value);
        if (cleanedMap.isNotEmpty) {
          cleanObj[key] = cleanedMap;
        }
      } else if (value is List) {
        // إذا كانت قائمة، نحاول تنظيف العناصر داخلها إذا كانت خرائط
        final cleanedList = value.map((e) => e is Map<String, dynamic> ? removeNullValues(e) : e).toList();
        cleanObj[key] = cleanedList;
      } else {
        cleanObj[key] = value;
      }
    }
  });
  return cleanObj;
}

// ===================================================================

class CheckoutController {

    // ----------------------------------------------------
    // 🔥🔥 الدالة الجديدة: جلب رصيد الكاش باك من FireStore 🔥🔥
    // ----------------------------------------------------
    static Future<double> fetchCashback(String userId, String userRole) async {
        if (userId.isEmpty) return 0.0;

        final bool isConsumer = (userRole == 'consumer');
        final String usersCollectionName = isConsumer ? "consumers" : "users";
        final String cashbackFieldName = isConsumer ? "cashbackBalance" : "cashback"; // اسم الحقل في FireStore

        try {
            final userDoc = await FirebaseFirestore.instance.collection(usersCollectionName).doc(userId).get();

            if (userDoc.exists) {
                // جلب قيمة الحقل cashbackFieldName (سواء cashbackBalance أو cashback)
                final fetchedAmount = (userDoc.data()?[cashbackFieldName] as num?)?.toDouble() ?? 0.0;
                return fetchedAmount;
            }
        } catch (e) {
            print('❌ Error fetching cashback for user $userId from $usersCollectionName: $e');
        }
        return 0.0;
    }

    // دالة مساعدة لتجميع الطلبات (ضرورية لنموذج البيانات)
    static List<Map<String, dynamic>> _groupOrdersForProcessing(List<Map<String, dynamic>> checkoutOrders) {
          final Map<String, Map<String, dynamic>> groupedItems = {};

          for (var item in checkoutOrders) {
              final sellerId = item['sellerId'] ?? 'unknown';
              if (!groupedItems.containsKey(sellerId)) {
                  groupedItems[sellerId] = { 'items': [], 'subtotal': 0.0, 'sellerName': item['sellerName'] ?? 'بائع غير معروف' };
              }
              groupedItems[sellerId]!['items'].add(item);
      }

      return groupedItems.entries.map((entry) => entry.value..['sellerId'] = entry.key).toList();
    }

    // ----------------------------------------------------
    // 🎯 دالة تنفيذ تأكيد الطلب
    // ----------------------------------------------------
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

        if (checkoutOrders.isEmpty || loggedUser['id'] == null) {
            return false;
        }

        final String paymentMethodString = selectedPaymentMethod.toString();
        // 💡 جلب البيانات من loggedUser
        final dynamic buyerLocation = loggedUser['location'];
        final String? rawAddress = loggedUser['address']?.toString();
        final String? rawRepCode = loggedUser['repCode']?.toString();
        final String? rawRepName = loggedUser['repName']?.toString();

        final String? address = (rawAddress == null || rawAddress.isEmpty || rawAddress == 'null') ? null : rawAddress;
        final String? repCode = (rawRepCode == null || rawRepCode.isEmpty || rawRepCode == 'null') ? null : rawRepCode;
        final String? repName = (rawRepName == null || rawRepName.isEmpty || rawRepName == 'null') ? null : rawRepName;

        // ... (التحقق من العنوان)
        if (address == null || address.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('الرجاء إكمال بيانات العنوان قبل تأكيد الطلب.'), backgroundColor: kErrorColor)
            );
            return false;
        }

        final bool isConsumer = (loggedUser['role'] == 'consumer');
        final String ordersCollectionName = isConsumer ? "consumerorders" : "orders";
        final String usersCollectionName = isConsumer ? "consumers" : "users";
        final String cashbackFieldName = isConsumer ? "cashbackBalance" : "cashback";

        final List<Map<String, dynamic>> groupedOrdersList = _groupOrdersForProcessing(checkoutOrders);
        final Map<String, Map<String, dynamic>> groupedItems = {
            for (var order in groupedOrdersList) order['sellerId'] as String: order
        };

        final double discountUsed = useCashback
            ? min(originalOrderTotal, currentCashback)
            : 0.0;

        final bool isGiftEligible = checkoutOrders.any((item) => item['isGift'] == true);

        // 🔥 شرط المسار الآمن (مطابق لـ JS)
        final bool needsSecureProcessing = !isConsumer && (discountUsed > 0 || isGiftEligible);

        print('--- Order Processing Summary ---');
        print('Needs Secure API Processing: $needsSecureProcessing');
        print('----------------------------------');

        try {
            List<String> successfulOrderIds = [];
            final uniqueSellerIds = groupedItems.keys.toList();

            // جلب نسب العمولات الحقيقية من FireStore (مجموعة sellers)
            final Map<String, double> commissionRatesCache = {};
            if (!isConsumer) {
                for (final sellerId in uniqueSellerIds) {
                    double commissionRate = 0.0;
                    try {
                        final sellerSnap = await FirebaseFirestore.instance.collection("sellers").doc(sellerId).get();

                        if (sellerSnap.exists) {
                            final fetchedCommissionRate = sellerSnap.data()?['commissionRate'] as num?;
                            if (fetchedCommissionRate != null) {
                                commissionRate = fetchedCommissionRate.toDouble();
                            }
                        }
                    } catch (e) {
                        print('❌ Error fetching commission for seller $sellerId: $e');
                    }
                    commissionRatesCache[sellerId] = commissionRate;
                }
            }

            // ===================================================================================
            // 🔥🔥 المسار الآمن: Buyer ويحتاج كاش باك أو هدية (API Gateway)
            // ===================================================================================
            if (needsSecureProcessing) {
                print('>>> SCENARIO 1: Buyer Order. Processing via SECURE API <<<');

                final List<Map<String, dynamic>> allOrdersData = [];

                for (final sellerId in groupedItems.keys) {
                    final sellerOrder = groupedItems[sellerId]!;

                    // حساب الإجمالي والخصم الجزئي
                    double deliveryFee = 0.0;
                    final regularItems = sellerOrder['items'].where((item) => item['isDeliveryFee'] != true && item['isGift'] != true).toList();
                    final sellerDeliveryItem = sellerOrder['items'].firstWhere((item) => item['isDeliveryFee'] == true, orElse: () => {});

                    if (sellerDeliveryItem.isNotEmpty) {
                        deliveryFee = (sellerDeliveryItem['price'] as num?)?.toDouble() ?? 0.0;
                    }

                    final double subtotalPrice = regularItems.fold(
                            0.0, (sum, item) => sum + ((item['price'] as num?)?.toDouble() ?? 0.0) * ((item['quantity'] as num?)?.toDouble() ?? 0.0)
                    );
                    final double orderSubtotalWithDelivery = subtotalPrice + deliveryFee;

                    double discountPortion = 0.0;
                    if (originalOrderTotal > 0 && discountUsed > 0) {
                        discountPortion = (orderSubtotalWithDelivery / originalOrderTotal) * discountUsed;
                    }

                    // 💡 بناء الـ payloadItems (الأصناف المدفوعة فقط)
                    final List<Map<String, dynamic>> payloadItems = [...regularItems];
                    if (sellerDeliveryItem.isNotEmpty) {
                        payloadItems.add(sellerDeliveryItem);
                    }

                    // 🎯🎯 هيكل الطلب الفردي (مطابق لـ JS) 🎯🎯
                    final orderData = {
                        'sellerId': sellerId,
                        'items': payloadItems,
                        'total': orderSubtotalWithDelivery,
                        'paymentMethod': paymentMethodString,
                        'status': 'new-order',
                        'orderDate': DateTime.now().toUtc().toIso8601String(), // استخدام UTC كما هو شائع في Firebase

                        'commissionRate': commissionRatesCache[sellerId] ?? 0.0,
                        'cashbackApplied': discountPortion,
                        'isCashbackUsed': discountUsed > 0,
                        'profitCalculationStatus': "PENDING",
                        'cashbackProcessedPerOrder': false,
                        'cashbackProcessedCumulative': false,

                        'buyer': { // 🎯🎯 هيكل كائن الـ buyer الداخلي (مطابق لـ JS) 🎯🎯
                            'name': loggedUser['fullname'],
                            'phone': loggedUser['phone'],
                            'email': loggedUser['email'],
                            'address': address,
                            'location': buyerLocation,
                            'repCode': repCode,
                            'repName': repName
                        },
                    };
                    allOrdersData.add(removeNullValues(orderData));
                }

                // 🎯🎯 هيكل الحمولة الكلية (Payload) (مطابق لـ JS) 🎯🎯
                final payload = {
                    'userId': loggedUser['id'],
                    'cashbackToReserve': discountUsed,
                    'ordersData': allOrdersData,
                    // 🔥🔥 التعديل الضروري: إضافة مرجع فريد لعملية الدفع
                    'checkoutId': 'CHECKOUT-${loggedUser['id']}-${DateTime.now().millisecondsSinceEpoch}',
                };

                try {
                    print('  - Sending payload to API: $CASHBACK_API_ENDPOINT');

                    final response = await http.post(
                        Uri.parse(CASHBACK_API_ENDPOINT),
                        headers: { 'Content-Type': 'application/json' },
                        // 🎯🎯 استخدام removeNullValues لضمان نظافة الحمولة 🎯🎯
                        body: json.encode(removeNullValues(payload)),
                    );

                    final result = json.decode(response.body);

                    if (response.statusCode >= 200 && response.statusCode < 300) {
                        successfulOrderIds = (result['orderIds'] is List)
                            ? List<String>.from(result['orderIds'])
                            : (result['orderId'] != null ? [result['orderId'].toString()] : []);
                    } else {
                        String errorMessage = (result is Map && result.containsKey('message')) ? result['message'].toString() : 'فشل تأكيد الطلب عبر المسار الآمن.';
                        throw Exception(errorMessage);
                    }
                } catch (e) {
                    String errorDescription = (e is Exception) ? e.toString().replaceFirst("Exception: ", "") : 'خطأ في الشبكة أو الاتصال بالخادم.';
                    print('❌ API Error in secure path: $errorDescription');
                    throw Exception(errorDescription);
                }
            } else {
                // ===================================================================================
                // 💾 المسار المباشر: Direct Firestore Write
                // ===================================================================================
                print('>>> SCENARIO 2/3: Processing via DIRECT Firestore Write <<<');

                for (final sellerId in groupedItems.keys) {
                    final sellerOrder = groupedItems[sellerId]!;

                    double deliveryFee = 0.0;
                    final regularItems = sellerOrder['items'].where((item) => item['isDeliveryFee'] != true && item['isGift'] != true).toList();
                    final sellerDeliveryItem = sellerOrder['items'].firstWhere((item) => item['isDeliveryFee'] == true, orElse: () => {});

                    if (sellerDeliveryItem.isNotEmpty) {
                        deliveryFee = (sellerDeliveryItem['price'] as num?)?.toDouble() ?? 0.0;
                    }

                    final List<Map<String, dynamic>> allPaidItems = [...regularItems.cast<Map<String, dynamic>>()];
                    if (sellerDeliveryItem.isNotEmpty) {
                        allPaidItems.add(sellerDeliveryItem.cast<String, dynamic>());
                    }

                    final double subtotalPrice = regularItems.fold(
                            0.0, (sum, item) => sum + ((item['price'] as num?)?.toDouble() ?? 0.0) * ((item['quantity'] as num?)?.toDouble() ?? 0.0)
                    );
                    final double orderSubtotalWithDelivery = subtotalPrice + deliveryFee;

                    double discountPortion = 0.0;
                    if (originalOrderTotal > 0 && discountUsed > 0) {
                        discountPortion = (orderSubtotalWithDelivery / originalOrderTotal) * discountUsed;
                    }
                    final double finalAmountForOrder = orderSubtotalWithDelivery - discountPortion;

                    final String sellerName = sellerOrder['sellerName'] ?? 'بائع غير معروف';
                    final String? sellerPhone = regularItems.isNotEmpty ? regularItems.first['sellerPhone'] as String? : null;

                    Map<String, dynamic> orderData;
                    if (isConsumer) {
                        // تذكر أنك طلبت مني تذكر اسم المجموعة 'deliverySupermarkets'
                        orderData = {
                            'customerId': loggedUser['id'],
                            'customerName': loggedUser['fullname'],
                            'customerPhone': loggedUser['phone'],
                            'customerEmail': loggedUser['email'],
                            'customerAddress': address,
                            'deliveryLocation': buyerLocation,

                            // استخدام حقول الـ deliverySupermarkets
                            'supermarketId': sellerId, // ownerId
                            'supermarketName': sellerName, // supermarketName
                            'supermarketPhone': sellerPhone,

                            'items': allPaidItems,
                            'deliveryFee': deliveryFee,
                            'subtotalPrice': subtotalPrice,

                            'finalAmount': finalAmountForOrder,
                            'paymentMethod': paymentMethodString,
                            'status': 'new-order',
                            'orderDate': DateTime.now().toUtc().toIso8601String(),

                            'pointsUsed': discountPortion,
                            'pointsEarned': 0,
                            'points_calculated': false,
                        };
                    } else {
                        orderData = {
                            'buyer': {
                                'id': loggedUser['id'],
                                'name': loggedUser['fullname'],
                                'phone': loggedUser['phone'],
                                'email': loggedUser['email'],
                                'address': address,
                                'location': buyerLocation,
                                'repCode': repCode,
                                'repName': repName
                            },
                            'sellerId': sellerId,
                            'items': allPaidItems,
                            'total': orderSubtotalWithDelivery,
                            'paymentMethod': paymentMethodString,
                            'status': 'new-order',
                            'orderDate': DateTime.now().toUtc().toIso8601String(),

                            'commissionRate': commissionRatesCache[sellerId] ?? 0.0,
                            'isCommissionProcessed': false,
                            'unrealizedCommissionAmount': 0,
                            'isFinancialSettled': false,
                            'orderHandled': false,
                            'cashbackApplied': discountPortion,
                            'isCashbackUsed': discountUsed > 0,
                            'isCashbackReserved': false,

                            'cashbackProcessedPerOrder': false,
                            'cashbackProcessedCumulative': false,
                            'profitCalculationStatus': "PENDING",
                        };
                    }

                    try {
                        final finalOrderData = removeNullValues(orderData);
                        // 🔥 الكتابة الفعلية
                        final docRef = await FirebaseFirestore.instance.collection(ordersCollectionName).add(finalOrderData);
                        final String orderId = docRef.id;
                        successfulOrderIds.add(orderId);

                        // 💡 دمج orderId
                        await FirebaseFirestore.instance.collection(ordersCollectionName).doc(orderId).set({ 'orderId': orderId }, SetOptions(merge: true));

                    } catch (e) {
                        print('  ❌ General Error processing order for seller $sellerId: $e');
                    }
                }

                // 🔥 خصم الكاش باك الفوري
                if (discountUsed > 0 && successfulOrderIds.isNotEmpty) {
                    try {
                        final newCashbackBalance = currentCashback - discountUsed;
                        await FirebaseFirestore.instance.collection(usersCollectionName).doc(loggedUser['id']).set({
                            cashbackFieldName: newCashbackBalance
                        }, SetOptions(merge: true));
                    } catch (error) {
                        print("❌ Failed to deduct cashback in Firestore (Immediate deduction): $error");
                    }
                }
            }

            // 8. إنهاء العملية
            if (successfulOrderIds.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('✅ تم الطلب بنجاح ونقله للاستور!'),
                        backgroundColor: kPrimaryColor
                    )
                );
                return true;
            } else {
                return false;
            }

        } catch (e) {
            print("Order placement error: $e");
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('❌ خطأ غير متوقع أثناء إتمام الطلب: ${e.toString()}'), backgroundColor: kErrorColor)
            );
            return false;
        }
    }
}
