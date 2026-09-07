// lib/screens/consumer_store_screen.dart

import 'package:flutter/material.dart';

class ConsumerStoreScreen extends StatelessWidget {
  const ConsumerStoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ⭐️ تم إزالة 'const' من Scaffold
    return Scaffold(
      // ⭐️ تم إزالة 'const' من AppBar
      appBar: AppBar(title: const Text('شاشة المستهلك (Store)')),
      body: const Center(
        child: Text('جاري بناء واجهة المستهلك/المتجر...'),
      ),
    );
  }
}

