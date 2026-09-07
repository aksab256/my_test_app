// lib/screens/dummy_screen.dart

import 'package:flutter/material.dart';

/// شاشة افتراضية تُستخدم كوجهة مؤقتة لروابط الشريط الجانبي.
class SellerDummyScreen extends StatelessWidget {
  final String title;
  const SellerDummyScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title, textAlign: TextAlign.right,)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.build_circle_outlined, size: 60, color: Colors.grey),
              const SizedBox(height: 20),
              Text(
                'شاشة "$title" قيد الإنشاء',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              const Text(
                'هذه وجهة مؤقتة. سيتم تحويل كود الـ HTML الخاص بهذه الشاشة لاحقًا.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

