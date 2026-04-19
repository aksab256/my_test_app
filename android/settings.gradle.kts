pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        val localPropertiesFile = file("local.properties")

        if (localPropertiesFile.exists()) {
            localPropertiesFile.inputStream().use { properties.load(it) }
        }

        // 👇 fallback مهم لـ GitHub Actions
        val flutterSdkPath = properties.getProperty("flutter.sdk")
            ?: System.getenv("FLUTTER_ROOT")

        require(flutterSdkPath != null) { "flutter.sdk not set" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
