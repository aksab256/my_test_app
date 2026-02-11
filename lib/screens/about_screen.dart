// المسار: lib/screens/about_screen.dart

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// 🟢 الألوان الثابتة للهوية البصرية
const Color _primaryColor = Color(0xFF2c3e50); 
const Color _accentColor = Color(0xFF4CAF50);  

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const routeName = '/about';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('عن أسواق أكسب', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0, // جعلناه 0 لإعطاء مظهر عصري مع الـ Header
        ),
        // ✅ إضافة SafeArea لحماية المحتوى من الحواف والـ Notch
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. قسم الهيدر بخلفية منحنية أو ملونة (اختياري)
                Container(
                  color: _primaryColor,
                  padding: const EdgeInsets.only(bottom: 30, top: 10),
                  child: _buildHeaderSection(context),
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 30),
                      // 2. الرسالة الرئيسية
                      _buildMainMessage(),
                      const SizedBox(height: 30),

                      // 3. قسم المميزات
                      _buildFeaturesSection(context),
                      const SizedBox(height: 30),

                      // 4. قسم التواصل
                      _buildContactSection(context),
                      const SizedBox(height: 30),

                      // 5. زر العودة
                      _buildBackButton(context),
                      const SizedBox(height: 30), // مسافة إضافية للتنفس في الأسفل
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 1. قسم الشعار والرسالة الترحيبية
  Widget _buildHeaderSection(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(15),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxType.circle,
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Icon(FontAwesomeIcons.store, size: 40, color: _accentColor),
        ),
        const SizedBox(height: 15),
        const Text(
          'أسواق أكسب',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const Text(
          'مستقبلك في التجارة الذكية',
          style: TextStyle(fontSize: 14, color: Colors.white70, letterSpacing: 1.2),
        ),
      ],
    );
  }

  // 2. الرسالة الرئيسية
  Widget _buildMainMessage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('من نحن', FontAwesomeIcons.circleInfo),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          color: _accentColor.withOpacity(0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: _accentColor.withOpacity(0.1))),
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              children: [
                const Text(
                  'منصة أسواق أكسب هي الركيزة الرقمية للتجارة الذكية. نحن لسنا مجرد تطبيق؛ نحن منظومة متكاملة صُممت لتمكين السوق المحلي من خلال ربط المصنعين والموردين مباشرةً بتجار التجزئة، وفي الوقت نفسه ربط تجار التجزئة بالمستهلكين النهائيين بكفاءة عالية.',
                  style: TextStyle(fontSize: 15, height: 1.8, color: _primaryColor),
                  textAlign: TextAlign.justify,
                ),
                const SizedBox(height: 12),
                RichText(
                  textAlign: TextAlign.justify,
                  text: TextSpan(
                    style: const TextStyle(fontSize: 15, height: 1.8, color: _primaryColor),
                    children: [
                      const TextSpan(text: 'مدعومة بأحدث أدوات '),
                      TextSpan(
                        text: 'الذكاء الاصطناعي',
                        style: TextStyle(fontWeight: FontWeight.bold, color: _accentColor),
                      ),
                      const TextSpan(
                        text: '، توفر "أسواق أكسب" تحليلات متقدمة وإدارة طلبات سلسة، مما يضمن أن تكون كل خطوة في سلسلة التوريد والتسوق محسّنة وذكية ومربحة لجميع الأطراف.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 3. قسم الرؤية والقيم (تحسين الـ Grid)
  Widget _buildFeaturesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('رؤيتنا وقيمنا', FontAwesomeIcons.handshake),
        const SizedBox(height: 15),
        GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 2 : 1,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.2, // تحسين النسبة لتبدو البطاقات متناسقة
          children: [
            _buildFeatureCard(FontAwesomeIcons.circleCheck, 'الجودة والموثوقية', 'نلتزم بتقديم أفضل المنتجات لضمان رضاك.'),
            _buildFeatureCard(FontAwesomeIcons.truckFast, 'السرعة والراحة', 'تجربة تسوق سلسة وتوصيل موثوق لباب منزلك.'),
            _buildFeatureCard(FontAwesomeIcons.usersGear, 'دعم المجتمع', 'تمكين التجار المحليين لنمو اقتصادنا المجتمعي.'),
            _buildFeatureCard(FontAwesomeIcons.mobileScreen, 'سهولة الاستخدام', 'واجهة بسيطة تجعل التسوق متعة للجميع.'),
          ],
        ),
      ],
    );
  }

  // 4. قسم التواصل (تحسين الأزرار)
  Widget _buildContactSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primaryColor.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          _buildSectionTitle('تواصل معنا', FontAwesomeIcons.solidComments),
          const Text(
            'فريق دعم "أسواق أكسب" مستعد دائماً للاستماع إليك.',
            style: TextStyle(fontSize: 14, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSocialButton(
                onTap: () => _launchExternalUrl('https://wa.me/201021070462'),
                icon: FontAwesomeIcons.whatsapp,
                color: const Color(0xFF25D366),
                label: 'واتساب',
              ),
              _buildSocialButton(
                onTap: () => _launchExternalUrl('https://www.facebook.com/share/199za9SBSE/'),
                icon: FontAwesomeIcons.facebook,
                color: const Color(0xFF1877F2),
                label: 'فيسبوك',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 5. زر العودة
  Widget _buildBackButton(BuildContext context) {
    return Column(
      children: [
        const Text(
          'ابدأ رحلة النجاح مع أكسب الآن',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _primaryColor),
        ),
        const SizedBox(height: 15),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/buyerHome', (route) => false),
            icon: const Icon(FontAwesomeIcons.bagShopping, size: 18, color: Colors.white),
            label: const Text('ابدأ التسوق الآن', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
          ),
        ),
      ],
    );
  }

  // --- دوال مساعدة للواجهة ---

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: _accentColor),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryColor)),
      ],
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String desc) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(icon, size: 28, color: _accentColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _primaryColor)),
                  const SizedBox(height: 2),
                  Text(desc, style: const TextStyle(fontSize: 11, color: Colors.black54), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialButton({required VoidCallback onTap, required IconData icon, required Color color, required String label}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(backgroundColor: color, radius: 25, child: Icon(icon, color: Colors.white, size: 25)),
          const SizedBox(height: 5),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _primaryColor)),
        ],
      ),
    );
  }

  void _launchExternalUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }
}
