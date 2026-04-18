android {
    namespace = "com.aksabeg500"
    
    // ✅ التعديل الجوهري: يجب أن يكون 36 ليتوافق مع مكتبات androidx الحديثة
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

    signingConfigs {
        create("release") {
            keyAlias = System.getenv("KEY_ALIAS") ?: ""
            keyPassword = System.getenv("KEY_PASSWORD") ?: ""
            storePassword = System.getenv("STORE_PASSWORD") ?: ""
            val keystorePath = System.getenv("KEYSTORE_PATH") ?: "release-keystore.jks"
            storeFile = file(keystorePath)
        }
    }

    defaultConfig {
        applicationId = "com.aksabeg500"
        minSdk = 24
        
        // ابقِ هذا على 35 لضمان التوافق مع متطلبات جوجل بلاي الحالية وعدم حدوث مشاكل في التصاريح
        targetSdk = 35 
        
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

