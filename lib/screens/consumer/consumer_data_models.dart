import 'package:cloud_firestore/cloud_firestore.dart';

class ConsumerCategory {                                  
  final String id;                                        
  final String name;                                      
  final String imageUrl;
  final String? link;                                   
  
  const ConsumerCategory({                                        
    required this.id,                                       
    required this.name,                                     
    required this.imageUrl,                                 
    this.link,                                            
  });                                                   
}                                                                                                               

class ConsumerBanner {                                    
  final String id;                                        
  final String imageUrl;
  final String? link; // تركناه لضمان عدم كسر أي كود قديم يعتمد عليه
  
  // 🎯 الإضافات المطلوبة لحل مشكلة الـ Build
  final String? targetType; 
  final String? targetId;
  final String? name;

  const ConsumerBanner({                                          
    required this.id,                                       
    required this.imageUrl,
    this.link,
    this.targetType, // مضاف حديثاً
    this.targetId,   // مضاف حديثاً
    this.name,       // مضاف حديثاً
  });

  // إضافة factory لتحويل البيانات من Firestore بشكل آمن
  factory ConsumerBanner.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ConsumerBanner(
      id: doc.id,
      imageUrl: data['imageUrl'] ?? '',
      link: data['link'],
      targetType: data['targetType'], // سيقرأ القيمة لو موجودة في الداتا
      targetId: data['targetId'],     // سيقرأ القيمة لو موجودة في الداتا
      name: data['name'] ?? data['title'], // يدعم التسميتين
    );
  }
}
