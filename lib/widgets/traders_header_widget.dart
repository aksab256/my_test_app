// المسار: lib/widgets/traders_header_widget.dart

import 'package:flutter/material.dart';

class TradersHeaderWidget extends StatelessWidget {
  final ValueChanged<String> onSearch; 
  final String currentQuery; 

  const TradersHeaderWidget({
    super.key,
    required this.onSearch,
    required this.currentQuery,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      color: Colors.white, 
      child: TextField(
        textAlign: TextAlign.right,
        controller: TextEditingController(text: currentQuery),
        onChanged: onSearch,
        decoration: InputDecoration(
          hintText: 'ابحث باسم السوبر ماركت أو التاجر...',
          hintStyle: const TextStyle(color: Colors.grey),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF2c3e50)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: const Color(0xFFf5f7fa),
          contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
        ),
      ),
    );
  }
}
