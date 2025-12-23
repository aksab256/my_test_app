plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.aksabeg500"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // 🎯 تفعيل Desugaring لحل مشكلة مكتبة الإشعارات
        isCoreLibraryDesugaringEnabled = true
        
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.aksabeg500"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

dependencies {
    // 🎯 تم تحديث النسخة إلى 2.1.4 لحل مشكلة التوافق مع مكتبة الإشعارات
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // التبعيات الأساسية
    implementation("androidx.multidex:multidex:2.0.1")

    // إضافة تبعيات Firebase platform
    implementation(platform("com.google.firebase:firebase-bom:32.7.0"))
}

flutter {
    source = "../.."
}
