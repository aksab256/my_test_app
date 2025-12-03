// المسار: lib/controllers/checkout_controller.dart

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// 💡 نستخدم مكتبة http لمحاكاة fetch/API calls
import 'package:http/http.dart' as http;

// تعريف الألوان (لـ SnackBar)
const Color kPrimaryColor = Color(0xFF4CAF50);
const Color kErrorColor = Color(0xFFE74C3C);

// 🔥 نقطة نهاية API الجديدة للحجز الآمن (نفس الرابط في JS)
const String CASHBACK_API_ENDPOINT = 'https://l9inzh2wck.execute-api.us-east-1.amazonaws.com/div/cashback';

// ===================================================================
// دالة مساعدة لتنظيف الكائن (حذف الحقول ذات القيمة null/undefined)
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
    // 🎯 دالة تنفيذ تأكيد الطلب (مطابقة لمنطق JS حرفياً) 🎯
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

        // التصحيح 1: تحويل paymentMethod إلى نص آمن (لحماية من الخطأ الأول)
        final String paymentMethodString = selectedPaymentMethod.toString();

        // 🔥🔥 التصحيح ليتطابق مع JS: استخراج location كـ dynamic (Map أو String) 🔥🔥
        final dynamic buyerLocation = loggedUser['location'];
        
        // الحقول النصية الأخرى تبقى آمنة
        final String? rawAddress = loggedUser['address']?.toString();
        final String? rawRepCode = loggedUser['repCode']?.toString();
        final String? rawRepName = loggedUser['repName']?.toString();
        
        final String? address = (rawAddress == null || rawAddress.isEmpty || rawAddress == 'null') ? null : rawAddress;
        final String? repCode = (rawRepCode == null || rawRepCode.isEmpty || rawRepCode == 'null') ? null : rawRepCode;
        final String? repName = (rawRepName == null || rawRepName.isEmpty || rawRepName == 'null') ? null : rawRepName;
        // ------------------------------------------------------------------------------------------

        // 1. التحقق المبدئي والحصول على بيانات المستخدم
        if (address == null || address.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('الرجاء إكمال بيانات العنوان قبل تأكيد الطلب.'), backgroundColor: kErrorColor)
            );
            return false;
        }

        // 💡 نفس الحقول المستخدمة في JS
        final bool isConsumer = (loggedUser['role'] == 'consumer');
        final String ordersCollectionName = isConsumer ? "consumerorders" : "orders";
        final String usersCollectionName = isConsumer ? "consumers" : "users";
        final String cashbackFieldName = isConsumer ? "cashbackBalance" : "cashback";

        // 2. تجميع الطلبات حسب البائع
        final List<Map<String, dynamic>> groupedOrdersList = _groupOrdersForProcessing(checkoutOrders);
        final Map<String, Map<String, dynamic>> groupedItems = {
            for (var order in groupedOrdersList) order['sellerId'] as String: order
        };

        // 3. تحديد الكاش باك/الخصم المستخدم
        final double discountUsed = useCashback
            ? min(originalOrderTotal, currentCashback)
            : 0.0;

        // 4. تحديد ما إذا كان الطلب يحتوي على هدايا (نفس منطق isGiftEligible في JS)
        final bool isGiftEligible = checkoutOrders.any((item) => item['isGift'] == true);

        // 5. تحديد المسار الأمني (نفس منطق needsSecureProcessing في JS)
        final bool needsSecureProcessing = !isConsumer && (discountUsed > 0 || isGiftEligible);

        print('--- Order Processing Summary ---');
        print('Total Discount Requested: $discountUsed');
        print('Is Gift Eligible: $isGiftEligible');
        print('Needs Secure API Processing: $needsSecureProcessing');
        print('----------------------------------');

        try {
            List<String> successfulOrderIds = [];
            List<String> failedToProcessSellerIds = [];

            final Map<String, double> commissionRatesCache = {};
            for (var sellerId in groupedItems.keys) {
                commissionRatesCache[sellerId] = 0.05;
            }

            // ===================================================================================
            // 🔥🔥 المسار الآمن: Buyer ويحتاج كاش باك أو هدية (API Gateway)
            // ===================================================================================
            if (needsSecureProcessing) {
                print('>>> SCENARIO 1: Buyer Order. Processing via SECURE API <<<');

                final List<Map<String, dynamic>> allOrdersData = [];

                for (final sellerId in groupedItems.keys) {
                    final sellerOrder = groupedItems[sellerId]!;

                    double deliveryFee = 0.0;
                    final regularItems = sellerOrder['items'].where((item) => item['isDeliveryFee'] != true && item['isGift'] != true).toList();
                    final sellerDeliveryItem = sellerOrder['items'].firstWhere((item) => item['isDeliveryFee'] == true, orElse: () => {});

                    if (sellerDeliveryItem.isNotEmpty) { 
                        // تم حل مشكلة Null subtype of double (رسوم التوصيل)
                        deliveryFee = (sellerDeliveryItem['price'] as num?)?.toDouble() ?? 0.0;
                    }

                    final double subtotalPrice = regularItems.fold(
                        0.0,
                        (sum, item) {
                            // تم حل مشكلة Null subtype of double (السعر والكمية)
                            final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                            final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
                            return sum + (price * quantity);
                        },
                    );
                    final double orderSubtotalWithDelivery = subtotalPrice + deliveryFee;

                    double discountPortion = 0.0;
                    if (originalOrderTotal > 0 && discountUsed > 0) {
                        discountPortion = (orderSubtotalWithDelivery / originalOrderTotal) * discountUsed;
                    }

                    final List<Map<String, dynamic>> payloadItems = [...regularItems];
                    if (sellerDeliveryItem.isNotEmpty) {
                        payloadItems.add(sellerDeliveryItem);
                    }

                    final orderData = {
                        'sellerId': sellerId,
                        'items': payloadItems,
                        'total': orderSubtotalWithDelivery,
                        'paymentMethod': paymentMethodString,
                        'status': 'new-order',
                        'orderDate': DateTime.now().toIso8601String(),

                        'commissionRate': commissionRatesCache[sellerId] ?? 0.0,
                        'cashbackApplied': discountPortion,
                        'isCashbackUsed': discountUsed > 0,
                        'profitCalculationStatus': "PENDING",
                        'cashbackProcessedPerOrder': false,
                        'cashbackProcessedCumulative': false,

                        'buyer': {
                            'name': loggedUser['fullname'],
                            'phone': loggedUser['phone'],
                            'email': loggedUser['email'],
                            'address': address,
                            'location': buyerLocation, // 🔥🔥 هنا نستخدم القيمة الأصلية (Map) 🔥🔥
                            'repCode': repCode,
                            'repName': repName
                        },
                    };

                    allOrdersData.add(removeNullValues(orderData));
                }

                // 5. إرسال الطلب إلى الـ API
                final payload = {
                    'userId': loggedUser['id'],
                    'cashbackToReserve': discountUsed,
                    'ordersData': allOrdersData
                };

                try {
                    final response = await http.post(
                        Uri.parse(CASHBACK_API_ENDPOINT),
                        headers: { 'Content-Type': 'application/json' },
                        body: json.encode(removeNullValues(payload)),
                    );

                    final result = json.decode(response.body);

                    if (response.statusCode >= 200 && response.statusCode < 300) {
                        print('✅ API Success: $result');
                        if (discountUsed > 0) { /* محاكاة خصم الكاش باك */ }
                        successfulOrderIds = (result['orderIds'] is List)
                            ? List<String>.from(result['orderIds'])
                            : (result['orderId'] != null ? [result['orderId'].toString()] : []);

                    } else {
                        String errorMessage;
                        if (result is Map && result.containsKey('message')) {
                            errorMessage = result['message'].toString();
                        } else {
                             errorMessage = 'فشل تأكيد الطلب عبر المسار الآمن. حالة HTTP: ${response.statusCode}';
                        }
                        print('❌ API Error: $errorMessage');
                        failedToProcessSellerIds = groupedItems.keys.toList();
                        throw Exception(errorMessage);
                    }
                } catch (e) {
                    String errorDescription = 'خطأ غير معروف في الاتصال بالـ API.';
                    if (e is FormatException) {
                        errorDescription = 'فشل معالجة استجابة الخادم. يرجى التأكد من أن الخادم يرجع بيانات JSON صالحة.';
                    } else if (e is Exception) {
                        errorDescription = e.toString().contains("Exception: ") ? e.toString().substring("Exception: ".length) : e.toString();
                    } else {
                        errorDescription = 'خطأ في الشبكة أو في فك التشفير: ${e.runtimeType}';
                    }
                    print('❌ Network or Unhandled API Error (Final Catch): $e');
                    failedToProcessSellerIds = groupedItems.keys.toList();
                    throw Exception(errorDescription);
                }

            } else {

                // ===================================================================================
                // 💾 المسار المباشر: Direct Firestore Write (Consumer أو Buyer لا يحتاج API)
                // ===================================================================================
                final String scenario = isConsumer ? "Consumer" : "Buyer without secure need";
                print('>>> SCENARIO 2/3: $scenario. Processing via DIRECT Firestore Write <<<');

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
                        0.0,
                        (sum, item) {
                            final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                            final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
                            return sum + (price * quantity);
                        },
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
                        // منطق المستهلك (Consumer Logic) - نستخدم buyerLocation لـ deliveryLocation
                        orderData = {
                            'customerId': loggedUser['id'],
                            'customerName': loggedUser['fullname'],
                            'customerPhone': loggedUser['phone'],
                            'customerEmail': loggedUser['email'],
                            'customerAddress': address,
                            'deliveryLocation': buyerLocation, // 🔥🔥 هنا نستخدم القيمة الأصلية (Map) 🔥🔥

                            'supermarketId': sellerId,
                            'supermarketName': sellerName,
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
                        // منطق تاجر التجزئة (Buyer Logic)
                        orderData = {
                            'buyer': {
                                'id': loggedUser['id'],
                                'name': loggedUser['fullname'],
                                'phone': loggedUser['phone'],
                                'email': loggedUser['email'],
                                'address': address,
                                'location': buyerLocation, // 🔥🔥 هنا نستخدم القيمة الأصلية (Map) 🔥🔥
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

                    // 6. محاكاة الإرسال إلى Firestore (بدلاً من addDoc)
                    try {
                        final finalOrderData = removeNullValues(orderData);
                        print('  - Attempting mock Firestore addDoc for $ordersCollectionName...');
                        await Future.delayed(const Duration(milliseconds: 500));
                        final String mockOrderId = 'Mock-${DateTime.now().millisecondsSinceEpoch}';
                        successfulOrderIds.add(mockOrderId);
                        print('  ✅ Mock Order placed successfully! ID: $mockOrderId');

                    } catch (e) {
                        print('  ❌ General Error processing order for seller $sellerId: $e');
                        failedToProcessSellerIds.add(sellerId);
                    }
                }

                // 7. محاكاة خصم الكاش باك الفوري
                if (discountUsed > 0 && successfulOrderIds.isNotEmpty) {
                    print('💵 Mock Deducting cashback immediately from user balance...');
                    print('✅ Mock Cashback deducted immediately.');
                }
            }

            // 8. إنهاء العملية
            if (successfulOrderIds.isNotEmpty) {
                print('✅ All successful orders processed.');
                
                // رسالة النجاح
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('✅ تم الطلب بنجاح ونقله للاستور!'),
                        backgroundColor: kPrimaryColor
                    )
                );
                
                return true;
            } else {
                print('❌ FAILED to process any order.');
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

