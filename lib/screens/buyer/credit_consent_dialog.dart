// lib/screens/buyer/credit_consent_dialog.dart
//
// نافذة الإقرار للتقديم على الأجل: بيانات التاجر للمراجعة فقط + إقرار إلزامي.
// زر الإرسال لا ينشط إلا بعد تحديد الموافقة. لا Firebase هنا — قابلة للاختبار.

import 'package:flutter/material.dart';
import 'package:my_test_app/services/credit_application_service.dart';

class CreditConsentDialog extends StatefulWidget {
  final String merchantName;
  final String merchantPhone;
  final String merchantAddress;
  final Future<void> Function() onSubmit;

  const CreditConsentDialog({
    super.key,
    required this.merchantName,
    required this.merchantPhone,
    required this.merchantAddress,
    required this.onSubmit,
  });

  @override
  State<CreditConsentDialog> createState() => _CreditConsentDialogState();
}

class _CreditConsentDialogState extends State<CreditConsentDialog> {
  bool _agreed = false;
  bool _sending = false;

  Future<void> _send() async {
    if (!_agreed || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.onSubmit();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.request_quote_outlined, color: Color(0xFF4CAF50)),
            SizedBox(width: 8),
            Text('التقديم على الأجل',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _readOnlyRow('الاسم المسجل', widget.merchantName),
              const SizedBox(height: 8),
              _readOnlyRow('رقم الهاتف المسجل', widget.merchantPhone),
              const SizedBox(height: 8),
              _readOnlyRow('العنوان المسجل', widget.merchantAddress),
              const Divider(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF4CAF50).withOpacity(0.3)),
                ),
                child: Text(
                  CreditApplicationService.consentText,
                  style: const TextStyle(fontSize: 13, height: 1.7),
                ),
              ),
              CheckboxListTile(
                value: _agreed,
                onChanged: _sending
                    ? null
                    : (v) => setState(() => _agreed = v ?? false),
                title: const Text('أوافق على الإقرار أعلاه.',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF4CAF50),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _sending ? null : () => Navigator.of(context).pop(false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: (_agreed && !_sending) ? _send : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: _sending
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('إرسال طلب التقديم',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _readOnlyRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          Text(value.isEmpty ? '—' : value,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
