import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

// تعريف الألوان
const Color kPrimaryColor = Color(0xFF4CAF50);
const Color kErrorColor = Color(0xFFE74C3C);
const Color kDebugColor = Color(0xFFF39C12); // لون جديد لرسائل التصحيح

const String CASHBACK_API_ENDPOINT = 'https://l9inzh2wck.execute-api.us-east-1.amazonaws.com/div/cashback';

// ===================================================================
// دالة مساعدة لتنظيف الكائن (إزالة الحقول التي تحمل null)
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

// ===================================================================

class CheckoutController {

    // دالة جلب الكاش باك (تبقى كما هي)
    static Future<double> fetchCashback(String userId, String userRole) async {
        if (userId.isEmpty) return 0.0;

        final bool isConsumer = (userRole == 'consumer');
        final String usersCollectionName = isConsumer ? "consumers" : "users";
        final String cashbackFieldName = isConsumer ? "cashbackBalance" : "cashback";

        try {
            final userDoc = await FirebaseFirestore.instance.collection(usersCollectionName).doc(userId).get();

            if (userDoc.exists) {
                final fetchedAmount = (userDoc.data()?[cashbackFieldName] as num?)?.toDouble() ?? 0.0;
                return fetchedAmount;
            }
        } catch (e) {
            print('❌ Error fetching cashback for user $userId from $usersCollectionName: $e');
        }
        return 0.0;
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
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('DIAGNOSTIC: Failed. Order list is empty or UserID is missing.'), backgroundColor: kErrorColor)
            );
            return false;
        }
        
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        
        final String paymentMethodString = selectedPaymentMethod.toString();
        
        // 🎯 الخطوة 1: تنظيف كائن المستخدم بشكل صارم لضمان Map<String, dynamic> 🎯
        final Map<String, dynamic> safeLoggedUser = Map<String, dynamic>.from(loggedUser);

        final String? rawAddress = safeLoggedUser['address']?.toString();
        final String? rawRepCode = safeLoggedUser['repCode']?.toString();
        final String? rawRepName = safeLoggedUser['repName']?.toString();
        final String? rawPhone = safeLoggedUser['phone']?.toString();
        final String? rawEmail = safeLoggedUser['email']?.toString();
        final String? rawFullname = safeLoggedUser['fullname']?.toString();
        
        final String? address = (rawAddress == null || rawAddress.isEmpty || rawAddress == 'null') ? null : rawAddress;
        final String? repCode = (rawRepCode == null || rawRepCode.isEmpty || rawRepCode == 'null') ? null : rawRepCode;
        final String? repName = (rawRepName == null || rawRepName.isEmpty || rawRepName == 'null') ? null : rawRepName;
        final String? customerPhone = (rawPhone == null || rawPhone.isEmpty || rawPhone == 'null') ? null : rawPhone;
        final String? customerEmail = (rawEmail == null || rawEmail.isEmpty || rawEmail == 'null') ? null : rawEmail;
        final String? customerFullname = (rawFullname == null || rawFullname.isEmpty || rawFullname == 'null') ? null : rawFullname;

        // --------------------------------------------------------------
        // تنظيف حقل الموقع (buyerLocation)
        final dynamic rawLocation = safeLoggedUser['location'];
        Map<String, dynamic>? buyerLocation;
        
        if (rawLocation is Map) {
            try {
                final Map<String, dynamic> locationMap = Map<String, dynamic>.from(rawLocation);
                
                final lat = (locationMap['lat'] as num?)?.toDouble();
                final lng = (locationMap['lng'] as num?)?.toDouble();
                
                if (lat != null && lng != null) {
                    buyerLocation = {
                        'lat': lat, 
                        'lng': lng, 
                    };
                }
            } catch (e) {
                 ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('DIAGNOSTIC: Location map conversion failed: $e'), backgroundColor: kErrorColor)
                );
            }
        }
        // --------------------------------------------------------------
        
        if (address == null || address.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('الرجاء إكمال بيانات العنوان قبل تأكيد الطلب.'), backgroundColor: kErrorColor)
            );
            return false;
        }
        
        // 🎯 الخطوة 2: تنظيف قائمة الطلبات بشكل صارم 🎯
        final List<Map<String, dynamic>> safeCheckoutOrders = 
            checkoutOrders.map((order) => Map<String, dynamic>.from(order)).toList();

        final bool isConsumer = (safeLoggedUser['role'] == 'consumer');
        final String ordersCollectionName = isConsumer ? "consumerorders" : "orders";
        final String usersCollectionName = isConsumer ? "consumers" : "users";
        final String cashbackFieldName = isConsumer ? "cashbackBalance" : "cashback";

        // 🌟🌟 [التعديل الحاسم: المعالجة المسبقة وتصفية رسوم التوصيل للـ Buyer] 🌟🌟
        final List<Map<String, dynamic>> processedCheckoutOrders = [];
        for (var order in safeCheckoutOrders) {
            Map<String, dynamic> processedOrder = Map.from(order);
            final List<Map<String, dynamic>> items = (processedOrder['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
            
            final List<Map<String, dynamic>> processedItems = [];
            for (var item in items) {
                Map<String, dynamic> processedItem = Map.from(item);
                final double price = (processedItem['price'] as num?)?.toDouble() ?? 0.0;
                
                final bool isDeliveryFee = (processedItem['productId'] == 'DELIVERY_FEE' || (processedItem['isDeliveryFee'] ?? false));

                // 1. منطق تعيين isGift للمنتج ذو السعر صفر (إذا لم يكن رسوم توصيل)
                if (price <= 0.0 && !isDeliveryFee) {
                    processedItem['isGift'] = true;
                }
                
                // 2. منطق إزالة رسوم التوصيل من حمولة Buyer نهائياً
                if (!isConsumer && isDeliveryFee) {
                    continue; // تجاهل رسوم التوصيل ولا تضفها للقائمة المعالجة
                }
                
                processedItems.add(processedItem);
            }
            processedOrder['items'] = processedItems;
            processedCheckoutOrders.add(processedOrder);
        }

        // استخدام القائمة النظيفة والمعدلة الآن لتحديد الإجمالي وتحديد المسار
        final List<Map<String, dynamic>> groupedOrdersList = processedCheckoutOrders; 
        final Map<String, Map<String, dynamic>> groupedItems = {
            for (var order in groupedOrdersList) order['sellerId'] as String: order
        };
        
        // حساب إجمالي الطلبات المدفوعة فقط
        double actualOrderTotal = 0.0;
        for(var order in groupedOrdersList) {
            final List<Map<String, dynamic>> items = (order['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
            for(var item in items) {
                final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
                // نجمع المنتجات غير الهدايا وغير رسوم التوصيل (لأن رسوم التوصيل أزيلت بالفعل للـ Buyer)
                if (!(item['isGift'] ?? false) && !(item['isDeliveryFee'] ?? false)) {
                     actualOrderTotal += price * quantity;
                }
            }
        }
        
        final double discountUsed = useCashback
            ? min(actualOrderTotal, currentCashback) // استخدام الإجمالي الفعلي لتحديد الخصم
            : 0.0;

        // 🟢 تحديد eligibility بناءً على القائمة المعالجة
        final bool isGiftEligible = processedCheckoutOrders.any((order) {
            final List<Map<String, dynamic>> items = (order['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
            return items.any((item) => (item['isGift'] ?? false) == true);
        });

        final bool needsSecureProcessing = !isConsumer && (discountUsed > 0 || isGiftEligible);

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('DIAGNOSTIC: Secure Processing Needed: $needsSecureProcessing. Cashback to use: $discountUsed. Actual Total: $actualOrderTotal'), backgroundColor: kDebugColor)
        );


        try {
            List<String> successfulOrderIds = [];
            final uniqueSellerIds = groupedItems.keys.toList();

            // ⭐️ جلب نسب العمولات الحقيقية من FireStore (مجموعة sellers)
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
                
                final List<Map<String, dynamic>> allOrdersData = [];

                for (final sellerId in groupedItems.keys) {
                    final sellerOrder = groupedItems[sellerId]!;
                    
                    // safeItems تحتوي الآن على المنتجات + الهدايا المعينة مسبقاً، ورسوم التوصيل قد أزيلت
                    final List<Map<String, dynamic>> safeItems = 
                        (sellerOrder['items'] as List?)?.cast<Map>()
                        .map((item) => Map<String, dynamic>.from(item))
                        .toList() ?? [];

                    // حساب subtotalPrice (الإجمالي قبل الخصم)
                    final double subtotalPrice = safeItems.fold(
                            0.0, (sum, item) {
                                final bool isGift = (item['isGift'] ?? false);
                                final double price = (item['price'] as num?)?.toDouble() ?? 0.0;
                                final double quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
                                
                                // نجمع فقط المنتجات غير الهدايا
                                if (!isGift) {
                                    return sum + (price * quantity);
                                }
                                return sum;
                            }
                    );
                    
                    final double orderSubtotalWithDelivery = subtotalPrice; // الإجمالي بدون رسوم توصيل
                    
                    double discountPortion = 0.0;
                    if (actualOrderTotal > 0 && discountUsed > 0) {
                        discountPortion = (orderSubtotalWithDelivery / actualOrderTotal) * discountUsed;
                    }

                    final orderData = {
                        'sellerId': sellerId,
                        'items': safeItems, // نستخدم القائمة المعالجة والمفلترة
                        'total': orderSubtotalWithDelivery,
                        'paymentMethod': paymentMethodString,
                        'status': 'new-order',
                        'orderDate': FieldValue.serverTimestamp(),


                        'commissionRateSnapshot': commissionRatesCache[sellerId] ?? 0.0, 
                        'cashbackApplied': discountPortion,
                        'isCashbackUsed': discountUsed > 0,
                        'profitCalculationStatus': "PENDING",
                        'cashbackProcessedPerOrder': false,
                        'cashbackProcessedCumulative': false,
                        'commissionRate': commissionRatesCache[sellerId] ?? 0.0,
                        
                        'buyer': { 
                            'id': safeLoggedUser['id'],
                            'name': customerFullname,
                            'phone': customerPhone, 
                            'email': customerEmail, 
                            'address': address,
                            'location': buyerLocation,
                            'repCode': repCode,
                            'repName': repName
                        },
                    };
                    
                    allOrdersData.add(removeNullValues(orderData)); 
                }

                // ... (منطق إرسال API)
                final payload = {
                    'userId': safeLoggedUser['id'],
                    'cashbackToReserve': discountUsed,
                    'ordersData': allOrdersData,
                    'checkoutId': 'CHECKOUT-${safeLoggedUser['id']}-${DateTime.now().millisecondsSinceEpoch}',
                };

                final finalPayload = removeNullValues(payload);
                
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('DIAGNOSTIC: Attempting API POST. Payload Size: ${json.encode(finalPayload).length} bytes.'),
                        backgroundColor: kDebugColor,
                        duration: const Duration(seconds: 5),
                    )
                );
                
                try {
                    final response = await http.post(
                        Uri.parse(CASHBACK_API_ENDPOINT),
                        headers: { 'Content-Type': 'application/json' },
                        body: json.encode(finalPayload),
                    );

                    final result = json.decode(response.body);
                    
                    if (response.statusCode >= 200 && response.statusCode < 300) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('DIAGNOSTIC: API Success (200 OK) received. Getting Order IDs...'), backgroundColor: kPrimaryColor)
                        );
                        
                        final List<String> fetchedIds = [];
                        if (result['orderIds'] is List) {
                            fetchedIds.addAll(List<String>.from(result['orderIds']));
                        } else if (result['orderId'] != null) {
                            fetchedIds.add(result['orderId'].toString());
                        }
                        
                        successfulOrderIds = fetchedIds;

                    } else {
                        String errorMessage = (result is Map && result.containsKey('message')) ? result['message'].toString() : 'فشل تأكيد الطلب عبر المسار الآمن.';
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('DIAGNOSTIC: API Failed (Status ${response.statusCode}): $errorMessage'), backgroundColor: kErrorColor)
                        );
                        
                        throw Exception(errorMessage);
                    }
                } catch (e) {
                    String errorDescription = (e is Exception) ? e.toString().replaceFirst("Exception: ", "") : e.toString();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('DIAGNOSTIC: Network/Unhandled Error: ${errorDescription.substring(0, min(errorDescription.length, 100))}'), 
                            backgroundColor: kErrorColor,
                            duration: const Duration(seconds: 8),
                        )
                    );
                    throw Exception(errorDescription);
                }
            } else {
                // ===================================================================================
                // 💾 المسار المباشر: Direct Firestore Write
                // ===================================================================================

                for (final sellerId in groupedItems.keys) {
                    final sellerOrder = groupedItems[sellerId]!;

                    // allPaidItems تحتوي الآن على المنتجات + الهدايا المعينة مسبقاً، ورسوم التوصيل قد أزيلت
                    final List<Map<String, dynamic>> allPaidItems = (sellerOrder['items'] as List?)?.cast<Map<String, dynamic>>() ?? []; 

                    double calculatedSubtotalPrice = 0.0;
                    
                    for (var item in allPaidItems) {
                        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                        final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
                        final itemTotal = price * quantity;

                        if (!(item['isGift'] ?? false)) {
                            calculatedSubtotalPrice += itemTotal;
                        }
                    }

                    final double subtotalPrice = calculatedSubtotalPrice;
                    final double orderSubtotalWithDelivery = subtotalPrice; // الإجمالي بدون رسوم توصيل       

                    double discountPortion = 0.0;
                    if (actualOrderTotal > 0 && discountUsed > 0) {
                        discountPortion = (orderSubtotalWithDelivery / actualOrderTotal) * discountUsed;
                    }
                    final double finalAmountForOrder = orderSubtotalWithDelivery - discountPortion;

                    final String sellerName = sellerOrder['sellerName'] ?? 'بائع غير معروف';
                    final String? sellerPhone = allPaidItems.isNotEmpty ? allPaidItems.firstWhere((item) => item['sellerPhone'] != null, orElse: () => {})['sellerPhone'] as String? : null;

                    Map<String, dynamic> orderData;
                    if (isConsumer) {
                        // مسار Consumer (بقي كما هو لكنه يستخدم items المفلترة)
                        orderData = {
                            'customerId': safeLoggedUser['id'],
                            'customerName': customerFullname,
                            'customerPhone': customerPhone,
                            'customerEmail': customerEmail,
                            'customerAddress': address,
                            'deliveryLocation': buyerLocation,

                            'supermarketId': sellerId,
                            'supermarketName': sellerName,
                            'supermarketPhone': sellerPhone,

                            'items': allPaidItems, // القائمة المفلترة (حتى لو كانت Consumer فلن تؤثر إزالة رسوم التوصيل التي تخص Buyer)
                            
                            'deliveryFee': 0.0, // لا يمكن أن تكون هنا قيمة لـ Consumer لأن الطلب يتم هنا فقط في حالة عدم وجود خصم/هدية
                            'subtotalPrice': subtotalPrice,
                            'finalAmount': finalAmountForOrder,

                            'pointsUsed': discountPortion,
                            'pointsEarned': 0,
                            'points_calculated': false,

                            'paymentMethod': paymentMethodString,
                            'status': 'new-order',
                            'orderDate': FieldValue.serverTimestamp(),

                        };
                    } else {
                        // مسار Buyer المباشر (Direct Write) - المعدل
                        orderData = {
                            'buyer': {
                                'id': safeLoggedUser['id'],
                                'name': customerFullname,
                                'phone': customerPhone,
                                'email': customerEmail,
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
                            'orderDate': FieldValue.serverTimestamp(),


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
                        final docRef = await FirebaseFirestore.instance.collection(ordersCollectionName).add(finalOrderData);
                        final String orderId = docRef.id;
                        successfulOrderIds.add(orderId);
                        await FirebaseFirestore.instance.collection(ordersCollectionName).doc(orderId).set({ 'orderId': orderId }, SetOptions(merge: true));

                    } catch (e) {
                        print('  ❌ General Error processing order for seller $sellerId: $e');
                    }
                }

                if (discountUsed > 0 && successfulOrderIds.isNotEmpty) {
                    try {
                        final newCashbackBalance = currentCashback - discountUsed;
                        await FirebaseFirestore.instance.collection(usersCollectionName).doc(safeLoggedUser['id']).set({
                            cashbackFieldName: newCashbackBalance
                        }, SetOptions(merge: true));
                    } catch (error) {
                        print("❌ Failed to deduct cashback in Firestore (Immediate deduction): $error");
                    }
                }
                
                 ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('DIAGNOSTIC: Processed via Direct Firestore Write.'), backgroundColor: kDebugColor)
                );
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
                 ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('DIAGNOSTIC: Failed. No Order IDs were created.'), backgroundColor: kErrorColor)
                );
                return false;
            }

        } catch (e) {
            String errorMsg = (e is Exception) ? e.toString().replaceFirst("Exception: ", "") : 'خطأ غير معروف';
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('❌ خطأ غير متوقع أثناء إتمام الطلب: ${errorMsg}'), backgroundColor: kErrorColor)
            );
            return false;
        }
    }
}
