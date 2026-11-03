plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.nthcase.sample"
    // Android 17 (API 37), the latest stable platform, as the native Mossgrove app
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // the same id in all five Mossgrove apps (SPEC.md §1)
        applicationId = "com.nthcase.sample"
        minSdk = 26
        targetSdk = 37
        // from pubspec.yaml's version: 1.0.0+1
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Mossgrove ships debug builds for testing; a local release build is signed with the debug key too.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
