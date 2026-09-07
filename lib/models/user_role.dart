// lib/models/user_role.dart

enum UserRole {
  consumer, // مستهلك عادي (مشتري)
  buyer,    // مشتري (تاجر أو موزع)
  seller,   // بائع (قد لا يستخدم في هذا الجزء من التطبيق)
  delivery, // مندوب توصيل
  admin,    // مدير النظام
}

