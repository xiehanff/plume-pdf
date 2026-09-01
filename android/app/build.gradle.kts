plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.xiehan.plume_pdf"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.xiehan.plume_pdf"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Android only supports ARMv8-A (64-bit ARM).
        ndk {
            abiFilters += listOf("arm64-v8a")
        }
    }

    // Some plugins bundle prebuilt JNI libraries for multiple ABIs. `abiFilters`
    // alone does not remove every prebuilt .so, so explicitly exclude all
    // non-arm64 native libraries from the final APK as well.
    packaging {
        jniLibs {
            excludes += setOf(
                "**/armeabi/*.so",
                "**/armeabi-v7a/*.so",
                "**/x86/*.so",
                "**/x86_64/*.so",
                "**/mips/*.so",
                "**/mips64/*.so",
            )
        }
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
