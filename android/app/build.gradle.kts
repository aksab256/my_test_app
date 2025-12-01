plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // ⬅️ ضروري للفirebase
}

android {
    namespace = "com.example.my_test_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.my_test_app"
        minSdk = 23                         // firebase messaging يتطلب 23 أو أعلى
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true              // مهم جدًا
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false         // عطل shrink عشان ما يكسرش Firebase
            isShrinkResources = false
        }
    }
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")  // مهم جدًا
}

flutter {
    source = "../.."
}
