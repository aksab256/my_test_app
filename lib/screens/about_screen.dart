// lib/screens/about_screen.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  static const routeName = '/about';

  const AboutScreen({super.key});

  Future<void> _launchExternalUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('عن تطبيق أسواق أكسب',
              style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: const Color(0xFF4a6491),
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo or Image Placeholder
              Center(
                child: Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4a6491).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: FaIcon(
                      FontAwesomeIcons.shop,
                      size: 60,
                      color: Color(0xFF4a6491),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              
              const Text(
                'من نحن؟',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4a6491)),
              ),
              const SizedBox(height: 10),
              const Text(
                'تطبيق أسواق أكسب هو منصة تجارة إلكترونية مبتكرة تهدف إلى ربط الموردين، تجار التجزئة، والمستهلكين في منظومة واحدة سهلة وسريعة. نحن نسعى لتوفير تجربة تسوق فريدة تدعم الاقتصاد المحلي وتسهل عملية البيع والشراء.',
                style: TextStyle(fontSize: 16, height: 1.6),
              ),
              
              const SizedBox(height: 30),
              // 💡 [التصحيح]: تم تغيير دالة _buildSectionTitle لتقبل dynamic icon
              _buildSectionTitle('رؤيتنا وقيمنا', FontAwesomeIcons.handshake),
              const SizedBox(height: 15),
              
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 15,
                crossAxisSpacing: 15,
                childAspectRatio: 0.85,
                children: [
                  _buildFeatureCard(FontAwesomeIcons.circleCheck, 'الجودة والموثوقية', 'نلتزم بتقديم أفضل المنتجات لضمان رضاك.'),
                  _buildFeatureCard(FontAwesomeIcons.truckFast, 'السرعة والراحة', 'تجربة تسوق سلسة وتوصيل موثوق لباب منزلك.'),
                  _buildFeatureCard(FontAwesomeIcons.usersGear, 'دعم المجتمع', 'تمكين التجار المحليين لنمو اقتصادنا المجتمعي.'),
                  _buildFeatureCard(FontAwesomeIcons.circleCheck, 'سهولة الاستخدام', 'واجهة بسيطة تجعل التسوق متعة للجميع.'),
                ],
              ),
              
              const SizedBox(height: 40),
              _buildSectionTitle('تواصل معنا', FontAwesomeIcons.solidComments),
              const SizedBox(height: 20),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSocialButton(
                      onTap: () => _launchExternalUrl('https://wa.me/201021070462'),
                      icon: FontAwesomeIcons.whatsapp,
                      color: const Color(0xFF25D366),
                      label: 'واتساب'),
                  _buildSocialButton(
                      onTap: () => _launchExternalUrl('https://www.facebook.com/share/199za9SBSE/'),
                      icon: FontAwesomeIcons.facebook,
                      color: const Color(0xFF1877F2),
                      label: 'فيسبوك'),
                ],
              ),
              
              const SizedBox(height: 50),
              const Center(
                child: Text(
                  'إصدار التطبيق 1.0.0',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.of(context).pushNamed('/marketplaceHome'),
          backgroundColor: const Color(0xFF4CAF50),
          label: const Text('ابدأ التسوق الآن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          // 💡 [التصحيح التقني]: استخدام FaIcon بدلاً من Icon
          icon: const FaIcon(FontAwesomeIcons.bagShopping, size: 18, color: Colors.white),
        ),
      ),
    );
  }

  // 💡 [تعديل]: تغيير نوع icon إلى dynamic ليتناسب مع FaIconData
  Widget _buildSectionTitle(String title, dynamic icon) {
    return Row(
      children: [
        FaIcon(icon, color: const Color(0xFF4a6491), size: 24),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4a6491)),
        ),
      ],
    );
  }

  // 💡 [تعديل]: تغيير نوع icon إلى dynamic واستخدام FaIcon
  Widget _buildFeatureCard(dynamic icon, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FaIcon(icon, color: const Color(0xFF4CAF50), size: 30),
          const SizedBox(height: 10),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 5),
          Text(description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  // 💡 [تعديل]: تغيير نوع icon إلى dynamic واستخدام FaIcon
  Widget _buildSocialButton(
      {required VoidCallback onTap,
      required dynamic icon,
      required Color color,
      required String label}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: FaIcon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

