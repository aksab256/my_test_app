// android/app/build.gradle.kts

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.aksabeg500"

    // 🎯 تم التعديل لـ 36 لإرضاء المكتبات الجديدة ومنع فشل البناء
    compileSdk = 36

    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.aksabeg500"

        // الحد الأدنى لتشغيل التطبيق
        minSdk = 24

        // 🎯 نتركه 34 لضمان عمل الإشعارات بشكل سليم ومنع الكراش عند المستخدم
        targetSdk = 34

        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // نستخدم توقيع الـ debug حالياً لتسهيل التجربة
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

dependencies {
    // مكتبة Desugaring ضرورية جداً للتوافق
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    implementation("androidx.multidex:multidex:2.0.1")

    // استخدام نسخة مستقرة من Firebase
    implementation(platform("com.google.firebase:firebase-bom:33.1.0"))
    implementation("com.google.firebase:firebase-messaging")
    implementation("com.google.firebase:firebase-analytics")

    // 🎯 إضافة مكتبة فيسبوك للتبع والـ Login
    implementation("com.facebook.android:facebook-android-sdk:latest.release")
}

flutter {
    source = "../.."
}

