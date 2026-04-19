plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"

    id("com.android.application") version "8.9.1" apply false

    // ✅ الحل هنا
    id("org.jetbrains.kotlin.android") version "2.3.10" apply false

    id("com.google.gms.google-services") version "4.4.1" apply false
    id("com.google.firebase.crashlytics") version "3.0.2" apply false
}
