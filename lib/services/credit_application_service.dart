// lib/services/credit_application_service.dart
//
// التقديم على الأجل: احتساب الفواتير النقدية المستلمة + طلب التقديم.
//
// قواعد الاحتساب (دائمة ومستندة إلى وثائق الطلبات في Firestore):
// - تُحتسب الفاتورة فقط عندما تكون حالة الطلب `delivered` (تأكيد الاستلام).
// - لا تُحتسب عند: الإنشاء new-order، أو التجهيز processing، أو الشحن shipped.
// - الملغي cancelled والمرتجع returned لا يُحتسبان أبدًا.
// - كل وثيقة طلب تُحتسب مرة واحدة (العد من معرفات الوثائق، لا من عداد تراكمي).
// - لا يوجد أي عداد محلي: العد يُشتق من قراءة جديدة في كل مرة، فيبقى صحيحًا
//   بعد إعادة التثبيت أو الدخول من جهاز آخر، وتكرار الإشعارات لا يضاعفه.
// - طلب التقديم يُحفظ بمعرف حتمي (uid التاجر) داخل معاملة (transaction)،
//   فلا يمكن إنشاء طلب مكرر أثناء وجود طلب «قيد المراجعة» حتى مع التزامن.

import 'package:cloud_firestore/cloud_firestore.dart';

/// استثناءات مسار التقديم على الأجل.
class CreditApplicationException implements Exception {
  /// 'not_eligible' | 'under_review' | 'not_signed_in'
  final String code;
  final String message;
  const CreditApplicationException(this.code, this.message);
  @override
  String toString() => 'CreditApplicationException($code): $message';
}

class CreditApplicationService {
  static const int requiredInvoices = 5;
  static const String applicationsCollection = 'creditApplications';
  static const String ordersCollection = 'orders';
  static const String buyerIdField = 'buyer.id';

  static const String statusDelivered = 'delivered';
  static const String statusCancelled = 'cancelled';
  static const String statusReturned = 'returned';

  static const String applicationUnderReview = 'قيد المراجعة';

  /// نص الإقرار المعتمد — نسخة واحدة مركزية للواجهة والسجل المحفوظ.
  static const String consentText =
      'أقر بأن تقديم هذا الطلب لا يعني الموافقة على منحي الأجل أو الحصول على تمويل، '
      'وإنما يعني إرسال بياناتي إلى القسم المختص لمراجعة الطلب ودراسته، '
      'وسيتم إبلاغي بالنتيجة لاحقًا.';

  final FirebaseFirestore _db;

  // Test seam: defaults preserve the production wiring exactly.
  CreditApplicationService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  /// منطق خالص قابل للاختبار: معرفات الفواتير المؤهلة من وثائق الطلبات الخام.
  /// كل معرف وثيقة يُحتسب مرة واحدة مهما تكررت قراءته.
  static Set<String> eligibleCreditInvoiceIds(
    Iterable<MapEntry<String, Map<String, dynamic>>> orders,
  ) {
    final ids = <String>{};
    for (final entry in orders) {
      final data = entry.value;
      final status = data['status']?.toString();
      if (status == null) continue;
      // الملغي أو المرتجع أو أي حالة قبل الاستلام لا تُحتسب.
      if (status == statusCancelled || status == statusReturned) continue;
      // الاحتساب فقط عند تأكيد الاستلام.
      if (status != statusDelivered) continue;
      if (!_isCashOrder(data)) continue;
      ids.add(entry.key);
    }
    return ids;
  }

  /// الفاتورة النقدية: الدفع عند الاستلام أو ما يماثله.
  /// غياب الحقل يُعامل كاش (توافق رجعي مع الطلبات القديمة قبل توثيق الطريقة).
  /// أي طريقة إلكترونية صريحة تُستبعد.
  static bool _isCashOrder(Map<String, dynamic> data) {
    final raw = data['paymentMethod']?.toString().trim().toLowerCase();
    if (raw == null || raw.isEmpty) return true;
    const cashLike = {'cash_on_delivery', 'cash', 'cod', 'cashondelivery'};
    if (cashLike.contains(raw)) return true;
    if (raw.contains('cash') || raw.contains('نقد')) return true;
    return false;
  }

  /// هل بلغ العدد النصاب المطلوب؟
  static bool isEligible(int count) => count >= requiredInvoices;

  /// عدد الفواتير المؤهلة الآن — قراءة جديدة دائمة من وثائق الطلبات.
  Future<int> fetchEligibleCount(String uid) async {
    final snap = await _db
        .collection(ordersCollection)
        .where(buyerIdField, isEqualTo: uid)
        .where('status', isEqualTo: statusDelivered)
        .get();
    return eligibleCreditInvoiceIds(
      snap.docs.map((d) => MapEntry(d.id, d.data() as Map<String, dynamic>)),
    ).length;
  }

  /// بث العدد الحي — يُعاد اشتقاقه من الوثائق مع كل تغيير، بلا حالة محلية.
  Stream<int> watchEligibleCount(String uid) {
    return _db
        .collection(ordersCollection)
        .where(buyerIdField, isEqualTo: uid)
        .where('status', isEqualTo: statusDelivered)
        .snapshots()
        .map((snap) => eligibleCreditInvoiceIds(
              snap.docs
                  .map((d) => MapEntry(d.id, d.data() as Map<String, dynamic>)),
            ).length);
  }

  /// قراءة حالة طلب التقديم الحالي للتاجر (null عند عدم وجود طلب).
  Future<Map<String, dynamic>?> fetchApplication(String uid) async {
    final doc =
        await _db.collection(applicationsCollection).doc(uid).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  /// بث حالة طلب التقديم (لإظهار «قيد المراجعة» بدل زر جديد).
  Stream<Map<String, dynamic>?> watchApplication(String uid) {
    return _db
        .collection(applicationsCollection)
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null);
  }

  /// إرسال طلب التقديم: تحقق جديد من الأهلية ثم كتابة ذرية.
  /// - يعيد التحقق من العدد لحظة الإرسال (لا يثق بعداد الواجهة).
  /// - المعرف الحتمي + المعاملة يمنعان التكرار حتى مع التزامن أو إعادة المحاولة.
  /// - الحالة الأولية دائمًا «قيد المراجعة» — لا منح تلقائي للأجل.
  Future<void> submitApplication({
    required String uid,
    required String merchantName,
    required String merchantPhone,
    required String merchantAddress,
  }) async {
    final count = await fetchEligibleCount(uid);
    if (!isEligible(count)) {
      throw const CreditApplicationException(
        'not_eligible',
        'لم تكتمل شروط الأجل بعد (5 فواتير مستلمة ومؤكدة).',
      );
    }
    final ref = _db.collection(applicationsCollection).doc(uid);
    await _db.runTransaction((tx) async {
      final existing = await tx.get(ref);
      if (existing.exists &&
          existing.data()?['status'] == applicationUnderReview) {
        throw const CreditApplicationException(
          'under_review',
          'لديك طلب قيد المراجعة بالفعل.',
        );
      }
      tx.set(ref, {
        'uid': uid,
        'merchantName': merchantName,
        'merchantPhone': merchantPhone,
        'merchantAddress': merchantAddress,
        'eligibleCount': count,
        'requiredCount': requiredInvoices,
        'status': applicationUnderReview,
        'consent': true,
        'consentText': consentText,
        'consentAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
