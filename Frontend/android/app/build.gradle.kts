plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.dressify"
    compileSdk = 36  // AndroidX core/activity 1.18+ (pulled by ML Kit 0.14 / secure_storage 10) requires API 36
    // NDK 28+ produces 16 KB-aligned ELF segments (required for Google Play as of Aug 2025)
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.dressify"
        minSdk = 29          // Android 10 — matches stated minimum target
        targetSdk = 35       // Android 15 — required for Play Store & 16 KB enforcement
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
