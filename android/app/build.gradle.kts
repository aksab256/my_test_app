plugins {
    id("com.android.application")
    id("kotlin-android")
<<<<<<< HEAD
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
=======
    id("com.google.gms.google-services")        // ⬅️ ضروري للفirebase
>>>>>>> e23fe72 (Upload clean full project for Codemagic build)
    id("dev.flutter.flutter-gradle-plugin")
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
<<<<<<< HEAD
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.my_test_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
=======
        applicationId = "com.example.my_test_app"
        minSdk = 23                                // ⬅️ firebase messaging يتطلب 23 أو أعلى
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        multiDexEnabled = true                    // ⬅️ ضروري جدًا
>>>>>>> e23fe72 (Upload clean full project for Codemagic build)
    }

    buildTypes {
        release {
<<<<<<< HEAD
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
=======
            signingConfig = signingConfigs.getByName("debug")

            // ⬅️ عطل الـ shrink عشان ما يكسر الفايربيز
            isMinifyEnabled = false
            isShrinkResources = false
>>>>>>> e23fe72 (Upload clean full project for Codemagic build)
        }
    }
}

<<<<<<< HEAD
=======
dependencies {
    implementation("androidx.multidex:multidex:2.0.1")   // ⬅️ مهم جدًا
}

>>>>>>> e23fe72 (Upload clean full project for Codemagic build)
flutter {
    source = "../.."
}
