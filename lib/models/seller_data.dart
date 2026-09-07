// lib/models/seller_data.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Branch {
  final String? address;
  final double? lat;
  final double? long;
  final String? createdAt;

  Branch({
    this.address,
    this.lat,
    this.long,
    this.createdAt,
  });

  factory Branch.fromMap(Map<String, dynamic> data) {
    return Branch(
      address: data['address'] as String?,
      // التأكد من أن الإحداثيات هي double
      lat: (data['lat'] as num?)?.toDouble(),
      long: (data['long'] as num?)?.toDouble(),
      createdAt: data['createdAt'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'address': address,
      'lat': lat,
      'long': long,
      'createdAt': createdAt,
    };
  }
}

class SubUser {
  final String? phone;
  final String? role;
  final String? addedAt;

  SubUser({this.phone, this.role, this.addedAt});

  factory SubUser.fromMap(Map<String, dynamic> data) {
    return SubUser(
      phone: data['phone'] as String?,
      role: data['role'] as String?,
      addedAt: data['addedAt'] as String?,
    );
  }
}

