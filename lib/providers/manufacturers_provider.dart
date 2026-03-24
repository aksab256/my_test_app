// المسار: lib/providers/manufacturers_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/models/manufacturer_model.dart'; 
import 'package:flutter/foundation.dart';

class ManufacturersProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // قائمة الشركات المصنعة التي سيتم عرضها في الواجهة
  List<ManufacturerModel> _manufacturers = [];
  List<ManufacturerModel> get manufacturers => _manufacturers;

  // حالة التحميل لإظهار مؤشر الانتظار (CircularProgressIndicator)
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // تخزين رسائل الخطأ إن وجدت
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// دالة جلب الشركات المصنعة من Firestore
  /// [subCategoryId]: إذا تم تمريره، سيتم جلب الشركات المرتبطة بهذا القسم فقط
  Future<void> fetchManufacturers({String? subCategoryId}) async {
    // منع تكرار الطلبات إذا كان هناك طلب قيد التنفيذ
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    // تم التعليق مؤقتاً لضمان عدم حدوث Loop إذا تم استدعاؤها بشكل خاطئ في الـ Build
    // notifyListeners(); 

    try {
      // 1. بناء الاستعلام الأساسي واستهداف الشركات النشطة فقط
      // المسار في Firestore: /manufacturers
      Query query = _db.collection('manufacturers')
          .where('isActive', isEqualTo: true);

      // 2. الفلترة الذكية: إذا تم تمرير معرف قسم فرعي، نبحث عنه داخل مصفوفة subCategoryIds
      if (subCategoryId != null && subCategoryId != 'ALL') {
        query = query.where('subCategoryIds', arrayContains: subCategoryId);
      }

      // 3. ترتيب النتائج حسب تاريخ الإضافة (اختياري لضمان ثبات الترتيب)
      query = query.orderBy('createdAt', descending: true).limit(100);

      final querySnapshot = await query.get();

      // 4. تحويل النتائج القادمة من Firestore إلى قائمة موديلات (ManufacturerModel)
      _manufacturers = ManufacturerModel.fromQuerySnapshot(querySnapshot);
      
      // 5. إضافة خيار "عرض الكل" كأول عنصر في القائمة دائماً
      // تم ملء جميع الحقول المطلوبة لضمان عدم حدوث خطأ مع الموديل الجديد
      _manufacturers.insert(0, ManufacturerModel(
          id: 'ALL',
          name: 'عرض الكل',
          description: 'عرض جميع منتجات القسم الحالي',
          imageUrl: '', // تترك فارغة لأن البانر سيعرض أيقونة الفلترة بدلاً منها
          imagePublicId: null,
          isActive: true,
          subCategoryIds: [],
          createdAt: DateTime.now(),
      ));

    } on FirebaseException catch (e) {
      _errorMessage = 'خطأ في قاعدة البيانات: ${e.message}';
    } catch (e) {
      _errorMessage = 'حدث خطأ غير متوقع: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// دالة اختيارية لإعادة ضبط القائمة (Reset)
  void clearManufacturers() {
    _manufacturers = [];
    _errorMessage = null;
    notifyListeners();
  }
}
