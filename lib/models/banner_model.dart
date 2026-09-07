// lib/models/banner_model.dart

class BannerModel {
  final String id;
  final String imageUrl;
  final String? url;
  final String? altText;
  final int order;
  final String status;

  const BannerModel({
    required this.id,
    required this.imageUrl,
    this.url,
    this.altText,
    required this.order,
    required this.status, // الحقل required هنا
  });

  // دالة مساعدة لتحويل Firestore Map إلى نموذج
  factory BannerModel.fromMap(Map<String, dynamic> data, String id) {
    return BannerModel(
      id: id,
      imageUrl: data['imageUrl'] ?? '',
      url: data['url'],
      altText: data['altText'],
      order: (data['order'] as num?)?.toInt() ?? 0,
      status: data['status'] ?? 'inactive',
    );
  }
}

