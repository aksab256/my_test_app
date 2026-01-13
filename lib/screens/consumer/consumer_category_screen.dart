import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/screens/consumer/consumer_widgets.dart'; 
import 'package:sizer/sizer.dart';

class ConsumerCategoryScreen extends StatefulWidget {
  final String mainCategoryId;
  final String categoryName;

  const ConsumerCategoryScreen({
    super.key,
    required this.mainCategoryId,
    required this.categoryName,
  });

  @override
  State<ConsumerCategoryScreen> createState() => _ConsumerCategoryScreenState();
}

class _ConsumerCategoryScreenState extends State<ConsumerCategoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFBFBFB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF43A047)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.categoryName,
            style: TextStyle(
              color: const Color(0xFF2E7D32), 
              fontWeight: FontWeight.w900, 
              fontSize: 16.sp
            ),
          ),
        ),
        body: Column(
          children: [
            const ConsumerSectionTitle(title: 'الأقسام الفرعية المتاحة'),
            
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                // 🎯 جلب الأقسام الفرعية التي تنتمي لهذا القسم فقط عبر حقل mainId
                stream: FirebaseFirestore.instance
                    .collection('subCategory')
                    .where('mainId', isEqualTo: widget.mainCategoryId) 
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF43A047)));
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("لا توجد أقسام فرعية متاحة حالياً"));
                  }
                  
                  final docs = snapshot.data!.docs;
                  
                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                      childAspectRatio: 0.85, 
                    ),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final String subId = docs[index].id;
                      final String name = data['name'] ?? '';
                      final String imageUrl = data['imageUrl'] ?? '';

                      return GestureDetector(
                        onTap: () {
                          // هنا سيتم التوجيه لاحقاً لصفحة المنتجات
                          print("الانتقال لمنتجات: $name");
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05), 
                                blurRadius: 10,
                                offset: const Offset(0, 4)
                              )
                            ],
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                                  child: imageUrl.isNotEmpty 
                                    ? Image.network(imageUrl, fit: BoxFit.cover, width: double.infinity)
                                    : Container(color: Colors.grey[100], child: const Icon(Icons.image)),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Text(
                                  name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: const ConsumerFooterNav(cartCount: 0, activeIndex: 1),
      ),
    );
  }
}
