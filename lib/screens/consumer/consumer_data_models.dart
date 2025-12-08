// lib/screens/consumer/consumer_data_models.dart                                                               
class ConsumerCategory {                                  
  final String id;                                        
  final String name;                                      
  final String imageUrl;
  final String? link;                                   
  
  // 🟢 الحل: تم إضافة 'const' إلى المُنشئ
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
  final String link;                                                                                              
  
  // 🟢 الحل: تم إضافة 'const' إلى المُنشئ
  const ConsumerBanner({                                          
    required this.id,                                       
    required this.imageUrl,
    required this.link,                                   
  });
}
