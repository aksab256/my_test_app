// lib/providers/cashback_provider.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/buyer_data_provider.dart';

class CashbackProvider with ChangeNotifier {
  final BuyerDataProvider _buyerData;
  final FirebaseFirestore _db;

  // إضافة متغيرات داخلية لتخزين البيانات
  double _availableBalance = 0.0;
  List<Map<String, dynamic>> _offersList = [];
  List<Map<String, dynamic>> _earnHistory = [];
  bool _isLoading = false;

  // Getters للوصول للبيانات من الشاشة
  double get availableBalance => _availableBalance;
  List<Map<String, dynamic>> get offersList => _offersList;
  // سجل المستحقات: قراءة عرضية من الدفتر (المنح قرار خادمي فقط)
  List<Map<String, dynamic>> get earnHistory => _earnHistory;
  bool get isLoading => _isLoading;

  // Test seam: defaults preserve the production wiring exactly.
  CashbackProvider(this._buyerData, {FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  Future<double> fetchCashbackBalance() async {
    final userId = _buyerData.currentUserId;
    if (userId == null) {
      _availableBalance = 0.0;
      return 0.0;
    }
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      if (userDoc.exists) {
        _availableBalance = max(0.0, double.tryParse((userDoc.data()?['cashback'] ?? '0').toString()) ?? 0.0);
      } else {
        _availableBalance = 0.0;
      }
      notifyListeners(); // إشعار الواجهة بتحديث الرصيد
      return _availableBalance;
    } catch (e) {
      return 0.0;
    }
  }

  /// سجل المستحقات: قيود المنح الخاصة بالمشتري من دفتر العمليات.
  /// عرض فقط — لا ينشئ أي استحقاق ولا يعدّل أي رصيد.
  Future<List<Map<String, dynamic>>> fetchEarnHistory() async {
    final userId = _buyerData.currentUserId;
    if (userId == null) {
      _earnHistory = [];
      return [];
    }
    try {
      // No orderBy: a where+orderBy composite needs a deployed Firestore
      // index. Newest-first is applied client-side instead (history is small).
      final snap = await _db
          .collection('transactionsLedger')
          .where('entityId', isEqualTo: 'USER#$userId')
          .limit(200)
          .get();
      final all = snap.docs.map((d) {
        final data = d.data();
        DateTime? at;
        final rawTs = data['timestamp'];
        if (rawTs is Timestamp) at = rawTs.toDate();
        return {
          'amount': double.tryParse((data['amount'] ?? '0').toString()) ?? 0.0,
          'type': data['type'] ?? '',
          'ruleId': data['ruleId'] ?? '',
          'orderId': data['orderId'] ?? '',
          'fundingSource': data['fundingSource'] ?? 'platform',
          'at': at,
        };
      }).toList();
      all.sort((a, b) {
        final da = a['at'] as DateTime?;
        final db = b['at'] as DateTime?;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });
      _earnHistory = all.take(50).toList();
      notifyListeners();
      return _earnHistory;
    } catch (e) {
      return [];
    }
  }

  /// Human scope label for a rule doc (display only).
  static String _scopeLabel(Map<String, dynamic> data) {
    switch (data['appliesTo']) {
      case 'seller':
        return data['sellerName'] ?? 'تاجر محدد';
      case 'sellers':
        return 'مجموعة تجار';
      case 'category':
        return data['mainCategoryName'] ?? 'قسم محدد';
      case 'subcategory':
        return data['subCategoryName'] ?? 'قسم فرعي محدد';
      case 'item':
        return data['scopeItemName'] ?? 'صنف محدد';
      default:
        return 'كل التجار';
    }
  }

  /// Tolerant rule-date parsing: accepts Timestamp or ISO-8601 String.
  /// Anything else is invalid (null) and the rule is skipped.
  static DateTime? _parseRuleDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchAvailableOffers() async {
    final userId = _buyerData.currentUserId;
    if (userId == null) {
      _offersList = [];
      return [];
    }
    
    _isLoading = true;
    // لا نضع notifyListeners هنا لتجنب التعارض أثناء بناء الواجهة (build phase)
    
    try {
      final now = DateTime.now();
      final querySnapshot = await _db.collection("cashbackRules")
          .where("status", isEqualTo: "active")
          .orderBy('priority', descending: true)
          .get();

      List<Map<String, dynamic>> tempOffers = [];
      
      for (var docSnap in querySnapshot.docs) {
        final data = docSnap.data();
        
        DateTime? startDate = _parseRuleDate(data['startDate']);
        DateTime? endDate = _parseRuleDate(data['endDate']);

        if (startDate == null || endDate == null || now.isBefore(startDate) || now.isAfter(endDate)) continue;

        String targetType = data['targetType'] ?? 'none'; 
        double minAmount = double.tryParse(data['minPurchaseAmount']?.toString() ?? '0') ?? 0.0;
        double progressAmount = 0;

        if (targetType == 'cumulative_period') {
          final ordersQuery = await _db.collection("orders")
              .where("buyer.id", isEqualTo: userId)
              .where("status", isEqualTo: "delivered")
              .where("orderDate", isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
              .where("orderDate", isLessThanOrEqualTo: Timestamp.fromDate(endDate))
              .get();

          for (var order in ordersQuery.docs) {
            progressAmount += double.tryParse((order.data()['total'] ?? '0').toString()) ?? 0.0;
          }
        }

        tempOffers.add({
          'id': docSnap.id,
          'description': data['description'] ?? 'عرض كاش باك',
          'minAmount': minAmount,
          'targetType': targetType,
          'value': data['value'],
          'type': data['type'],
          'daysRemaining': endDate.difference(now).inDays,
          'currentProgress': progressAmount,
          'sellerName': data['sellerName'] ?? 'كل التجار',
          'fundingSource': data['fundingSource'] ?? 'unknown',
          'fundLabel': data['fundingSource'] == 'seller'
              ? "تمويل التاجر (${data['sellerName'] ?? ''})"
              : (data['fundingSource'] == 'platform' ? 'تمويل المنصة' : 'الممول غير محدد'),
          'scope': data['appliesTo'] ?? 'all',
          'scopeLabel': _scopeLabel(data),
        });
      }
      
      _offersList = tempOffers;
      _isLoading = false;
      notifyListeners(); // أهم سطر: يخبر الشاشة أن البيانات وصلت "الآن" حتى لو كانت الصفحة مفتوحة
      return _offersList;
    } catch (e) {
      debugPrint('Error: $e');
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }
}

