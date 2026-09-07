// المسار: lib/models/cashback_goal.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class CashbackGoal {
  final String id;
  final String title;
  final double minAmount;
  final String value; // قد تكون نسبة مئوية (مثلاً '10') أو قيمة ثابتة
  final String type; // 'percentage' أو 'fixed'
  final DateTime endDate;
  
  // 💡 حقول تتبع التقدم (يتم حسابها في الـ Provider)
  final double progressPercentage;
  final double currentProgress;
  final bool isAchieved;

  CashbackGoal({
    required this.id,
    required this.title,
    required this.minAmount,
    required this.value,
    required this.type,
    required this.endDate,
    required this.progressPercentage,
    required this.currentProgress,
    required this.isAchieved,
  });

  // 💡 دالة تحويل الخريطة (Map) القادمة من Firebase إلى موديل
  factory CashbackGoal.fromFirestore(DocumentSnapshot doc, 
    double calculatedProgress, 
    double calculatedPercentage, 
    bool achievedStatus) {
    
    final data = doc.data() as Map<String, dynamic>;
    
    // تحويل حقل التاريخ من Timestamp إلى DateTime
    final Timestamp endDateTimestamp = data['endDate'] ?? Timestamp.now();

    return CashbackGoal(
      id: doc.id,
      title: data['description'] ?? 'هدف كاش باك',
      minAmount: (data['minPurchaseAmount'] ?? 0.0).toDouble(),
      value: data['value']?.toString() ?? '0',
      type: data['type'] ?? 'fixed',
      endDate: endDateTimestamp.toDate(),
      
      // استخدام القيم المحسوبة التي يتم تمريرها من الـ Provider
      currentProgress: calculatedProgress,
      progressPercentage: calculatedPercentage,
      isAchieved: achievedStatus,
    );
  }
}

