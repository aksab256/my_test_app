// lib/screens/my_details_screen.dart

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 🟢 الألوان المعتمدة للهوية البصرية
const Color _primaryColor = Color(0xFF2c3e50);
const Color _accentColor = Color(0xFF4CAF50);
const Color _deleteColor = Color(0xFFE74C3C);

class MyDetailsScreen extends StatefulWidget {
  const MyDetailsScreen({super.key});
  static const routeName = '/myDetails';

  @override
  State<MyDetailsScreen> createState() => _MyDetailsScreenState();
}

class _MyDetailsScreenState extends State<MyDetailsScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isUpdating = false;

  late TextEditingController _nameController;
  late TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _fetchProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      DocumentSnapshot docSnap = await FirebaseFirestore.instance.collection('consumers').doc(user.uid).get();
      String col = 'consumers';
      
      if (!docSnap.exists) {
        col = 'users';
        docSnap = await FirebaseFirestore.instance.collection(col).doc(user.uid).get();
      }

      if (docSnap.exists) {
        final data = docSnap.data() as Map<String, dynamic>;
        setState(() {
          _userData = data;
          _userData?['activeCollection'] = col;
          _nameController.text = data['fullname'] ?? data['name'] ?? '';
          _addressController.text = data['address'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.isEmpty) return;
    
    setState(() => _isUpdating = true);
    final user = FirebaseAuth.instance.currentUser;
    final col = _userData?['activeCollection'];

    try {
      Map<String, dynamic> updates = {
        'address': _addressController.text.trim(),
      };
      
      if (col == 'consumers') {
        updates['fullname'] = _nameController.text.trim();
      } else {
        updates['name'] = _nameController.text.trim();
      }

      await FirebaseFirestore.instance.collection(col!).doc(user!.uid).update(updates);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث البيانات بنجاح'), backgroundColor: _accentColor),
      );
      _fetchProfile();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل التحديث')));
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('الملف الشخصي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: _accentColor))
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(height: 25),
                      _buildEditableSection(),
                      const SizedBox(height: 25),
                      _buildReadOnlySection(),
                      const SizedBox(height: 30),
                      _buildActionButtons(),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    bool isConsumer = _userData?['activeCollection'] == 'consumers';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_primaryColor, _primaryColor.withOpacity(0.8)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            // ✅ تم التصحيح هنا: BoxShape بدلاً من BoxType وإزالة const
            decoration: BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
            child: const CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 35, color: _primaryColor),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_nameController.text, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                if (isConsumer)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Row(
                      children: [
                        const Icon(FontAwesomeIcons.coins, color: Colors.amber, size: 14),
                        const SizedBox(width: 6),
                        Text('رصيد النقاط: ${_userData?['loyaltyPoints'] ?? 0}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableSection() {
    return _buildSectionContainer(
      title: 'تعديل البيانات',
      icon: Icons.edit_note,
      children: [
        _buildTextField('الاسم الكامل', _nameController, Icons.person_outline),
        _buildTextField('عنوان التوصيل', _addressController, Icons.location_on_outlined),
        const SizedBox(height: 5),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isUpdating ? null : _updateProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: _isUpdating 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                : const Text('حفظ التعديلات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlySection() {
    return _buildSectionContainer(
      title: 'بيانات الحساب الأساسية',
      icon: Icons.security,
      children: [
        _buildReadOnlyField('رقم الهاتف', _userData?['phone'] ?? 'غير متوفر', Icons.phone_android),
        _buildReadOnlyField('البريد الإلكتروني', _userData?['email'] ?? 'غير متوفر', Icons.alternate_email),
        _buildReadOnlyField('عضو منذ', _userData?['createdAt'] != null ? (_userData!['createdAt'] as Timestamp).toDate().toString().split(' ')[0] : 'غير متوفر', Icons.event_available),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: () => _showDeleteDialog(),
          icon: const Icon(Icons.no_accounts, color: _deleteColor, size: 18),
          label: const Text('طلب إغلاق الحساب نهائياً', style: TextStyle(color: _deleteColor)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: _deleteColor),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 15),
        const Text('منصة أسواق أكسب - v2.0.2', style: TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }

  Widget _buildSectionContainer({required String title, required IconData icon, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: _accentColor),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: _primaryColor, fontSize: 15)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
          prefixIcon: Icon(icon, color: _accentColor, size: 20),
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18, color: _primaryColor),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _primaryColor)),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الطلب'),
        content: const Text('سيتم مراجعة طلب إغلاق حسابك من قبل الإدارة. هل تريد الاستمرار؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context), 
            style: ElevatedButton.styleFrom(backgroundColor: _deleteColor), 
            child: const Text('تأكيد', style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );
  }
}
