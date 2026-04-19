buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // ✅ لازم يكون 8.9.1 عشان يتوافق مع المكتبات الجديدة
        classpath("com.android.tools.build:gradle:8.9.1") 
        classpath("com.google.gms:google-services:4.4.1")
        classpath("com.google.firebase:firebase-crashlytics-gradle:3.0.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// إعدادات المسارات (باقي الملف اللي عندك سليم)
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

