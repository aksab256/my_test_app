// android/app/build.gradle.kts

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics") // 🚀 تم إضافة سطر الكراشليتكس هنا
}

android {
    namespace = "com.aksabeg500"
    compileSdk = 35 // ✅ تم التعديل لـ 35 ليتطابق مع targetSdk ويكون أكثر استقراراً

    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // --- 🟢 إضافة جزء التوقيع لقراءة السيكريتس ---
    signingConfigs {
        create("release") {
            // بيقرأ من الـ Environment Variables اللي في GitHub Actions
            keyAlias = System.getenv("KEY_ALIAS") ?: ""
            keyPassword = System.getenv("KEY_PASSWORD") ?: ""
            storePassword = System.getenv("STORE_PASSWORD") ?: ""
            
            // بيحدد مسار ملف الـ keystore اللي الـ Action بيولده مؤقتاً
            val keystorePath = System.getenv("KEYSTORE_PATH") ?: "release-keystore.jks"
            storeFile = file(keystorePath)
        }
    }

    defaultConfig {
        applicationId = "com.aksabeg500"
        minSdk = 24
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            
            // تفعيل التنظيف لتقليل حجم الـ AAB
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.multidex:multidex:2.0.1")
    implementation(platform("com.google.firebase:firebase-bom:33.1.0"))
    implementation("com.google.firebase:firebase-messaging")
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-crashlytics") // 🚀 تم إضافة التبعية هنا
    implementation("com.facebook.android:facebook-android-sdk:latest.release")
}

flutter {
    source = "../.."
}
