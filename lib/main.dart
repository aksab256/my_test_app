import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:my_test_app/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // محاولة تشغيل الفايربيس
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    // إذا فشل الفايربيس، سيظل التطبيق يعمل ولن ينهار
  }
  
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Colors.green, // غيرنا اللون للأخضر لنعرف أن الفايربيس شغال
      body: Center(child: Text("Firebase Linked! ✅", 
        style: TextStyle(color: Colors.white, fontSize: 24))),
    ),
  ));
}
