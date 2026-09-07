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
  final String? link; 
  
  // 🎯 الإضافات المطلوبة لدعم التوجيه الجديد وحل مشكلة الـ Build
  final String? linkType;   // 👈 تمت الإضافة هنا
  final String? targetType; 
  final String? targetId;
  final String? name;

  const ConsumerBanner({                                          
    required this.id,                                       
    required this.imageUrl,
    this.link,
    this.linkType,     // 👈 تمت الإضافة هنا
    this.targetType, 
    this.targetId,   
    this.name,       
  });

  factory ConsumerBanner.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ConsumerBanner(
      id: doc.id,
      imageUrl: data['imageUrl'] ?? '',
      link: data['link'],
      linkType: data['linkType'],     // 👈 سحب القيمة من الفايربيز
      targetType: data['targetType'], 
      targetId: data['targetId'],     
      name: data['name'] ?? data['title'], 
    );
  }
}

